#include "egl_texture.h"
#include "Log.hpp"

#include <chrono>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <vector>
#include <unistd.h>

#ifndef GL_TEXTURE_EXTERNAL_OES
#define GL_TEXTURE_EXTERNAL_OES 0x8D65
#endif

// Flutter's render context, captured during the first deferred populate().
EGLContext thermion_flutter_render_context = EGL_NO_CONTEXT;
EGLDisplay thermion_flutter_render_display = EGL_NO_DISPLAY;
EGLenum thermion_flutter_render_api = EGL_NONE;
EGLint thermion_flutter_render_gl_major = 0;
EGLint thermion_flutter_render_gl_minor = 0;

// EGL function pointers (resolved at runtime)
static PFNEGLCREATEIMAGEKHRPROC s_eglCreateImageKHR = nullptr;
static PFNEGLDESTROYIMAGEKHRPROC s_eglDestroyImageKHR = nullptr;
static PFNGLEGLIMAGETARGETTEXTURE2DOESPROC s_glEGLImageTargetTexture2DOES = nullptr;

struct DeferredReadyResponse {
    FlMethodCall* method_call;
    int64_t texture_id;
    ThermionTextureGL* texture;
};

static gboolean respond_texture_ready(gpointer user_data) {
    auto* response = static_cast<DeferredReadyResponse*>(user_data);
    if (response->texture->destroyed) {
        fl_method_call_respond(
            response->method_call,
            FL_METHOD_RESPONSE(fl_method_error_response_new(
                "DESTROYED",
                "Texture destroyed before readiness response", nullptr)),
            nullptr);
    } else {
        g_autoptr(FlValue) result = fl_value_new_int(response->texture_id);
        fl_method_call_respond(
            response->method_call,
            FL_METHOD_RESPONSE(fl_method_success_response_new(result)),
            nullptr);
    }
    return G_SOURCE_REMOVE;
}

static void destroy_deferred_ready_response(gpointer user_data) {
    auto* response = static_cast<DeferredReadyResponse*>(user_data);
    g_object_unref(response->method_call);
    g_object_unref(response->texture);
    delete response;
}

static void ensure_egl_procs() {
    if (!s_eglCreateImageKHR) {
        s_eglCreateImageKHR = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
        s_eglDestroyImageKHR = (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
        s_glEGLImageTargetTexture2DOES = (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");
    }
}

// Serializes populate() (Flutter's raster thread) against the plugin's
// release_texture() (platform thread). Every populate() return path unlocks.
struct TextureLockGuard {
    explicit TextureLockGuard(GMutex& mutex) : mutex(mutex) {
        g_mutex_lock(&mutex);
    }
    ~TextureLockGuard() {
        g_mutex_unlock(&mutex);
    }
    TextureLockGuard(const TextureLockGuard&) = delete;
    TextureLockGuard& operator=(const TextureLockGuard&) = delete;

    GMutex& mutex;
};

G_DEFINE_TYPE(ThermionTextureGL,
              thermion_texture_gl,
              fl_texture_gl_get_type())

static gboolean
thermion_texture_populate(FlTextureGL *texture,
                          uint32_t *target,
                          uint32_t *name,
                          uint32_t *width,
                          uint32_t *height,
                          GError **error) {
    static auto lastPopulate = std::chrono::high_resolution_clock::now();
    static int popCount = 0;
    static int popJank = 0;
    static double popMaxMs = 0;
    static double popSumMs = 0;
    auto now = std::chrono::high_resolution_clock::now();
    double intervalMs = std::chrono::duration_cast<std::chrono::microseconds>(now - lastPopulate).count() / 1000.0;
    lastPopulate = now;
    popCount++;
    popSumMs += intervalMs;
    if (intervalMs > popMaxMs) popMaxMs = intervalMs;
    if (intervalMs > 20.0) popJank++;
    if (intervalMs > 20.0) {
        TRACE( "[POPULATE] #%d JANK interval=%.1fms\n", popCount, intervalMs);
    }
    if (popCount % 120 == 0) {
        double avgMs = popSumMs / 120.0;
        TRACE( "[POPULATE] 120-frame avg=%.1fms max=%.1fms jank=%d\n",
                avgMs, popMaxMs, popJank);
        popJank = 0;
        popMaxMs = 0;
        popSumMs = 0;
    }

    ThermionTextureGL *self = THERMION_TEXTURE_GL(texture);

    // Serialize against release_texture() on the platform thread. Either it
    // completes first (and the destroyed check below makes populate a no-op)
    // or this populate finishes first and the release observes the consumer
    // resources it must clean up. Without this lock, a destroy issued while
    // populate is importing the DMA-BUF can close the producer's fd mid-import.
    TextureLockGuard lockGuard(self->lock);

    if (self->destroyed) {
        g_set_error(error, g_quark_from_static_string("thermion"), 4,
                    "Texture destroyed before populate");
        return FALSE;
    }

    // This callback is the only place Flutter guarantees its raster context
    // is current. Capture it for owner-aware cleanup for every transport,
    // including Vulkan-produced DMA-BUF textures.
    EGLContext flutterContext = eglGetCurrentContext();
    EGLDisplay flutterDisplay = eglGetCurrentDisplay();
    if (flutterContext != EGL_NO_CONTEXT &&
        flutterDisplay != EGL_NO_DISPLAY &&
        (thermion_flutter_render_context != flutterContext ||
         thermion_flutter_render_display != flutterDisplay)) {
        thermion_flutter_render_context = flutterContext;
        thermion_flutter_render_display = flutterDisplay;
        thermion_flutter_render_api = eglQueryAPI();

        const char* version = reinterpret_cast<const char*>(
            glGetString(GL_VERSION));
        if (version) {
            if (std::sscanf(version, "OpenGL ES %d.%d",
                            &thermion_flutter_render_gl_major,
                            &thermion_flutter_render_gl_minor) != 2) {
                std::sscanf(version, "%d.%d",
                            &thermion_flutter_render_gl_major,
                            &thermion_flutter_render_gl_minor);
            }
        }
    }

    // The bootstrap texture is allocated while Flutter's render context is
    // current, solely to capture that context before Filament initializes.
    if (self->kind == THERMION_TEXTURE_KIND_CONTEXT_BOOTSTRAP) {
        if (self->gl_texture_id == 0) {
            if (flutterContext == EGL_NO_CONTEXT ||
                flutterDisplay == EGL_NO_DISPLAY) {
                g_set_error(error, g_quark_from_static_string("thermion"), 1,
                            "Flutter did not make an EGL context current");
                return FALSE;
            }

            // First populate — create a transparent GL texture on Flutter's
            // raster context. Its purpose is to import the actual context, not
            // to display application content.
            std::vector<uint8_t> pixels(self->width * self->height * 4, 0);
            while (glGetError() != GL_NO_ERROR) {}
            glGenTextures(1, &self->gl_texture_id);
            glBindTexture(GL_TEXTURE_2D, self->gl_texture_id);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, self->width, self->height, 0,
                         GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glBindTexture(GL_TEXTURE_2D, 0);
            GLenum glError = glGetError();
            if (self->gl_texture_id == 0 || glError != GL_NO_ERROR) {
                if (self->gl_texture_id != 0) {
                    glDeleteTextures(1, &self->gl_texture_id);
                    self->gl_texture_id = 0;
                }
                g_set_error(
                    error, g_quark_from_static_string("thermion"), 2,
                    "Failed to create Flutter context bootstrap texture "
                    "(GL error 0x%x)",
                    glError);
                return FALSE;
            }
            self->surface_id = static_cast<int64_t>(self->gl_texture_id);

            TRACE( "[DirectPop] Created bootstrap GL texture %u (%ux%u) on ctx=%p\n",
                    self->gl_texture_id, self->width, self->height,
                    (void*)flutterContext);

            // Capture Flutter's render context for Filament initialization.
            // This is the ONLY place where Flutter's render context is current.
            TRACE( "[DirectPop] Captured Flutter render context=%p display=%p API=0x%x version=%d.%d\n",
                    (void*)thermion_flutter_render_context,
                    (void*)thermion_flutter_render_display,
                    thermion_flutter_render_api,
                    thermion_flutter_render_gl_major,
                    thermion_flutter_render_gl_minor);

            // Do not resolve awaitTextureReady from inside populate(). Dart
            // may immediately initialize another EGL client API when the
            // Future completes. Queue the response on Flutter's platform loop
            // so this raster callback has fully returned first.
            for (guint i = 0; i < self->pending_ready_calls->len; i++) {
                auto* methodCall = static_cast<FlMethodCall*>(
                    g_ptr_array_index(self->pending_ready_calls, i));
                auto* response = new DeferredReadyResponse{
                    methodCall,
                    static_cast<int64_t>(self->gl_texture_id),
                    THERMION_TEXTURE_GL(g_object_ref(self)),
                };
                g_idle_add_full(
                    G_PRIORITY_DEFAULT_IDLE, respond_texture_ready, response,
                    destroy_deferred_ready_response);
            }
            // Ownership of every FlMethodCall reference moved to its idle
            // response.
            g_ptr_array_set_size(self->pending_ready_calls, 0);
        }

        *target = GL_TEXTURE_2D;
        *name   = self->gl_texture_id;
        *width  = self->width;
        *height = self->height;
        return TRUE;
    }

    // DMA-BUF path: lazy-init EGLImage import on first populate
    if (!self->initialized) {
        ensure_egl_procs();

        if (!s_eglCreateImageKHR || !s_eglDestroyImageKHR || !s_glEGLImageTargetTexture2DOES) {
            std::cerr << "[ThermionEGL] Failed to resolve EGL extension functions" << std::endl;
            g_set_error(error, g_quark_from_string("thermion"), 1,
                        "Failed to resolve EGL extension functions");
            return FALSE;
        }

        EGLDisplay display = eglGetCurrentDisplay();
        if (display == EGL_NO_DISPLAY) {
            g_set_error(error, g_quark_from_string("thermion"), 2,
                        "No EGL display available");
            return FALSE;
        }

        // Split the 64-bit DRM modifier into lo/hi 32-bit parts for EGL
        EGLint modLo = (EGLint)(self->drm_modifier & 0xFFFFFFFF);
        EGLint modHi = (EGLint)(self->drm_modifier >> 32);

        // Create EGLImage from dmabuf fd with the actual DRM modifier
        EGLint attribs[] = {
            EGL_WIDTH, (EGLint)self->width,
            EGL_HEIGHT, (EGLint)self->height,
            EGL_LINUX_DRM_FOURCC_EXT, (EGLint)self->drm_format,
            EGL_DMA_BUF_PLANE0_FD_EXT, self->dmabuf_fd,
            EGL_DMA_BUF_PLANE0_OFFSET_EXT, (EGLint)self->offset,
            EGL_DMA_BUF_PLANE0_PITCH_EXT, (EGLint)self->stride,
            EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, modLo,
            EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, modHi,
            EGL_NONE
        };

        self->egl_image = s_eglCreateImageKHR(display, EGL_NO_CONTEXT,
                                               EGL_LINUX_DMA_BUF_EXT,
                                               nullptr, attribs);
        if (self->egl_image == EGL_NO_IMAGE_KHR) {
            EGLint eglError = eglGetError();
            std::cerr << "[ThermionEGL] Failed to create EGLImage from dmabuf, EGL error: 0x"
                      << std::hex << eglError << std::dec
                      << " (modifier=0x" << std::hex << self->drm_modifier << std::dec << ")"
                      << std::endl;
            g_set_error(error, g_quark_from_string("thermion"), 3,
                        "Failed to create EGLImage from dmabuf");
            return FALSE;
        }

        // Create GL texture and bind EGLImage to it.
        // DMA-BUF EGLImages require GL_TEXTURE_EXTERNAL_OES on NVIDIA.
        glGenTextures(1, &self->gl_texture_id);
        glBindTexture(GL_TEXTURE_EXTERNAL_OES, self->gl_texture_id);
        glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        // Clear any stale GL errors before the EGLImage call
        while (glGetError() != GL_NO_ERROR) {}

        s_glEGLImageTargetTexture2DOES(GL_TEXTURE_EXTERNAL_OES, self->egl_image);

        GLenum glError = glGetError();
        if (glError != GL_NO_ERROR) {
            std::cerr << "[ThermionEGL] GL error after EGLImage target: 0x"
                      << std::hex << glError << std::dec << std::endl;
        }

        self->initialized = TRUE;
    }

    *target = GL_TEXTURE_EXTERNAL_OES;
    *name = self->gl_texture_id;
    *width = self->width;
    *height = self->height;
    return TRUE;
}

static void thermion_texture_gl_dispose(GObject* object) {
    ThermionTextureGL *self = THERMION_TEXTURE_GL(object);

    // Native GL/EGL resources are released explicitly by the plugin while
    // their owning contexts are available. GObject disposal only resolves
    // outstanding method calls and releases their references. Disposal runs
    // on the platform thread for textures that failed to register (never
    // visible to the raster thread), so the mutex is not needed here; the
    // plugin retains successfully-registered shells instead of unref'ing
    // them (see release_texture) precisely so a late populate cannot touch
    // a finalized object.
    if (self->pending_ready_calls) {
        for (guint i = 0; i < self->pending_ready_calls->len; i++) {
            auto* methodCall = static_cast<FlMethodCall*>(
                g_ptr_array_index(self->pending_ready_calls, i));
            fl_method_call_respond(
                methodCall,
                FL_METHOD_RESPONSE(fl_method_error_response_new(
                    "DESTROYED", "Texture destroyed before populate",
                    nullptr)),
                nullptr);
            g_object_unref(methodCall);
        }
        g_ptr_array_set_size(self->pending_ready_calls, 0);
        g_ptr_array_unref(self->pending_ready_calls);
        self->pending_ready_calls = nullptr;
    }

    if (self->owns_dmabuf_fd && self->dmabuf_fd >= 0) {
        close(self->dmabuf_fd);
    }
    self->dmabuf_fd = -1;
    self->owns_dmabuf_fd = FALSE;

    if (self->gl_texture_id != 0 ||
        self->egl_image != EGL_NO_IMAGE_KHR) {
        std::cerr
            << "[ThermionEGL] Texture disposed before explicit native cleanup"
            << std::endl;
    }

    G_OBJECT_CLASS(thermion_texture_gl_parent_class)->dispose(object);
}

static void thermion_texture_gl_finalize(GObject* object) {
    ThermionTextureGL *self = THERMION_TEXTURE_GL(object);
    g_mutex_clear(&self->lock);
    G_OBJECT_CLASS(thermion_texture_gl_parent_class)->finalize(object);
}

void thermion_texture_gl_class_init(ThermionTextureGLClass* klass) {
    G_OBJECT_CLASS(klass)->dispose = thermion_texture_gl_dispose;
    G_OBJECT_CLASS(klass)->finalize = thermion_texture_gl_finalize;
    FL_TEXTURE_GL_CLASS(klass)->populate = thermion_texture_populate;
}

void thermion_texture_gl_init(ThermionTextureGL* self) {
    self->gl_texture_id = 0;
    self->width = 0;
    self->height = 0;
    self->registrar = nullptr;
    self->dmabuf_fd = -1;
    self->owns_dmabuf_fd = FALSE;
    self->stride = 0;
    self->offset = 0;
    self->drm_format = 0;
    self->drm_modifier = 0;
    self->egl_image = EGL_NO_IMAGE_KHR;
    self->initialized = FALSE;
    self->surface_id = -1;
    self->kind = THERMION_TEXTURE_KIND_DMA_BUF;
    self->pending_ready_calls = g_ptr_array_new();
    self->destroyed = FALSE;
    g_mutex_init(&self->lock);
}

ThermionTextureGL* thermion_texture_gl_create(
    const SurfaceExportInfo& info,
    int64_t surface_id,
    FlTextureRegistrar* registrar)
{
    auto textureGL = THERMION_TEXTURE_GL(g_object_new(thermion_texture_gl_get_type(), nullptr));
    textureGL->width = info.width;
    textureGL->height = info.height;
    textureGL->registrar = registrar;
    // Own a separate descriptor for the consumer-side EGLImage import so the
    // producer closing its fd at teardown can never invalidate a concurrent
    // or subsequent import. The DMA-BUF memory itself stays alive until every
    // descriptor referencing it is closed.
    const int consumerFd = dup(info.dmabuf_fd);
    if (consumerFd >= 0) {
        textureGL->dmabuf_fd = consumerFd;
        textureGL->owns_dmabuf_fd = TRUE;
    } else {
        // Extremely unlikely (fd exhaustion); borrow the producer's
        // descriptor instead. It is never closed on the consumer side — the
        // producer's surface teardown owns it — and the populate/destroy
        // mutex already prevents an import from racing that teardown.
        std::cerr << "[ThermionEGL] dup() of dmabuf fd failed; borrowing producer fd"
                  << std::endl;
        textureGL->dmabuf_fd = info.dmabuf_fd;
        textureGL->owns_dmabuf_fd = FALSE;
    }
    textureGL->stride = info.stride;
    textureGL->offset = info.offset;
    textureGL->drm_format = info.drm_format;
    textureGL->drm_modifier = info.drm_modifier;
    textureGL->surface_id = surface_id;

    return textureGL;
}

ThermionTextureGL* thermion_texture_gl_create_context_bootstrap(
    uint32_t width, uint32_t height,
    FlTextureRegistrar* registrar)
{
    auto textureGL = THERMION_TEXTURE_GL(
        g_object_new(thermion_texture_gl_get_type(), nullptr));
    textureGL->width = width;
    textureGL->height = height;
    textureGL->registrar = registrar;
    textureGL->kind = THERMION_TEXTURE_KIND_CONTEXT_BOOTSTRAP;
    // populate() creates gl_texture_id while Flutter's raster context is
    // current and resolves the pending awaitTextureReady call.
    textureGL->gl_texture_id = 0;

    return textureGL;
}

void thermion_texture_gl_destroy(ThermionTextureGL* texture) {
    if (texture && texture->registrar) {
        fl_texture_registrar_unregister_texture(texture->registrar, FL_TEXTURE(texture));
    }
}
