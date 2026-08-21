#ifndef THERMION_EGL_TEXTURE_H
#define THERMION_EGL_TEXTURE_H

#include <epoxy/gl.h>
#include <epoxy/egl.h>

#include <gtk/gtk.h>
#include <glib-object.h>
#include <flutter_linux/flutter_linux.h>
#include <flutter_linux/fl_texture_gl.h>
#include <flutter_linux/fl_texture.h>
#include <flutter_linux/fl_texture_registrar.h>

#include "SurfaceExportInfo.h"

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

G_BEGIN_DECLS

typedef enum {
    THERMION_TEXTURE_KIND_DMA_BUF,
    THERMION_TEXTURE_KIND_CONTEXT_BOOTSTRAP,
} ThermionTextureKind;

#define THERMION_TEXTURE_GL(obj) \
   (G_TYPE_CHECK_INSTANCE_CAST((obj), thermion_texture_gl_get_type(), \
                               ThermionTextureGL))

struct _ThermionTextureGL {
    FlTextureGL parent_instance;
    GLuint gl_texture_id;
    uint32_t width;
    uint32_t height;
    FlTextureRegistrar* registrar;
    // dmabuf info for lazy EGL import (DMA-BUF path only)
    int dmabuf_fd;
    uint32_t stride;
    uint32_t offset;
    uint32_t drm_format;
    uint64_t drm_modifier;
    EGLImage egl_image;
    gboolean initialized;
    int64_t surface_id;  // for Blit() and destruction
    ThermionTextureKind kind;
    // Deferred "awaitTextureReady" response (stored until populate creates the GL texture)
    FlMethodCall* pending_ready_call;
};

typedef struct _ThermionTextureGL ThermionTextureGL;
typedef struct {
  FlTextureGLClass parent_instance;
  gboolean (*populate)(FlTextureGL* texture,
                       uint32_t* target,
                       uint32_t* name,
                       uint32_t* width,
                       uint32_t* height,
                       GError** error);
} ThermionTextureGLClass;

G_END_DECLS

FLUTTER_PLUGIN_EXPORT ThermionTextureGL* thermion_texture_gl_create(
    const SurfaceExportInfo& info,
    int64_t surface_id,
    FlTextureRegistrar* registrar);

// Pre-engine initialization path. The GL texture is created lazily from
// populate(), while Flutter's raster EGL context is current.
FLUTTER_PLUGIN_EXPORT ThermionTextureGL*
thermion_texture_gl_create_context_bootstrap(
    uint32_t width, uint32_t height,
    FlTextureRegistrar* registrar);

FLUTTER_PLUGIN_EXPORT void thermion_texture_gl_destroy(ThermionTextureGL* texture);

// Flutter's render context, captured during the first deferred populate().
// Used by ensure_opengl_context() to create the DMA-BUF producer and consumer
// contexts on Flutter's actual EGLDisplay.
extern EGLContext thermion_flutter_render_context;
extern EGLDisplay thermion_flutter_render_display;
extern EGLenum thermion_flutter_render_api;
extern EGLint thermion_flutter_render_gl_major;
extern EGLint thermion_flutter_render_gl_minor;

#endif
