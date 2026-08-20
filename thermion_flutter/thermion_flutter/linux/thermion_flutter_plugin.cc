#include "include/thermion_flutter/thermion_flutter_plugin.h"
#include "Log.hpp"

#include <flutter_linux/flutter_linux.h>
#include <flutter_linux/fl_texture_registrar.h>
#include <flutter_linux/fl_texture_gl.h>

#include <cstring>
#include <vector>
#include <memory>
#include <unordered_map>
#include <iostream>
#include <chrono>

#include <epoxy/egl.h>
#include <epoxy/gl.h>

#include "egl_texture.h"

// EGL_KHR_gl_texture_2D_image constants (in case epoxy doesn't define them)
#ifndef EGL_GL_TEXTURE_2D_KHR
#define EGL_GL_TEXTURE_2D_KHR 0x30B1
#endif
#ifndef EGL_GL_TEXTURE_LEVEL_KHR
#define EGL_GL_TEXTURE_LEVEL_KHR 0x30BC
#endif

#include "vulkan/linux/LinuxVulkanContext.h"
#include "LinuxOpenGLContext.h"
#include "ThermionPlatformEGLHeadlessAPI.h"
#include "vulkan/ExternalVulkanImage.h"

// Backend type constants (match Dart Backend enum indices)
static const int BACKEND_OPENGL = 1;
static const int BACKEND_VULKAN = 2;

// RAII guard: saves the current EGL context/surfaces and restores on destruction.
struct EglContextGuard {
  EGLContext prevCtx;
  EGLSurface prevDraw;
  EGLSurface prevRead;
  EGLDisplay display;

  EglContextGuard(EGLDisplay dpy)
      : prevCtx(eglGetCurrentContext()),
        prevDraw(eglGetCurrentSurface(EGL_DRAW)),
        prevRead(eglGetCurrentSurface(EGL_READ)),
        display(dpy) {}

  ~EglContextGuard() {
    eglMakeCurrent(display, prevDraw, prevRead, prevCtx);
  }

  EglContextGuard(const EglContextGuard&) = delete;
  EglContextGuard& operator=(const EglContextGuard&) = delete;
};

#define FLUTTER_FILAMENT_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), thermion_flutter_plugin_get_type(), \
                              ThermionFlutterPlugin))

struct _ThermionFlutterPlugin
{
  GObject parent_instance;
  FlTextureRegistrar *texture_registrar;
  FlView *view;
  int backend_type; // 0 = unset, BACKEND_VULKAN = Vulkan, BACKEND_OPENGL = OpenGL

  // Vulkan path
  thermion::vulkan::linux_platform::LinuxVulkanContext *vulkan_context;
  std::unordered_map<int64_t, thermion::vulkan::ExternalVulkanImage *> *external_images;

  // OpenGL path — direct sharing with Flutter's EGL context (preferred)
  EGLContext flutter_egl_context;   // Flutter's own context (captured, not owned)
  EGLContext utility_egl_context;   // our context in Flutter's share group (for GL ops)
  EGLDisplay egl_display;           // shared EGL display
  EGLConfig  egl_config;            // config matching Flutter's context
  gboolean use_direct_opengl;       // TRUE if direct sharing path succeeded
  void* thermion_platform;          // standalone OpenGLPlatform (EGLHeadless)

  // OpenGL path — fallback (LinuxOpenGLContext with GBM/DMA-BUF)
  thermion::opengl::linux_platform::LinuxOpenGLContext *opengl_context;

  // Shared
  std::vector<ThermionTextureGL *> *textures;
};

G_DEFINE_TYPE(ThermionFlutterPlugin, thermion_flutter_plugin, g_object_get_type())

static void destroy_all_contexts(ThermionFlutterPlugin *self)
{
  if (self->vulkan_context)
  {
    delete self->vulkan_context;
    self->vulkan_context = nullptr;
  }
  if (self->utility_egl_context != EGL_NO_CONTEXT &&
      self->egl_display != EGL_NO_DISPLAY)
  {
    eglDestroyContext(self->egl_display, self->utility_egl_context);
    self->utility_egl_context = EGL_NO_CONTEXT;
  }
  if (self->use_direct_opengl)
  {
    self->flutter_egl_context = EGL_NO_CONTEXT;
    self->egl_display = EGL_NO_DISPLAY;
    self->egl_config = nullptr;
    self->use_direct_opengl = FALSE;
    if (self->thermion_platform)
    {
      ThermionPlatformEGLHeadless_Destroy(self->thermion_platform);
      self->thermion_platform = nullptr;
    }
  }
  if (self->opengl_context)
  {
    delete self->opengl_context;
    self->opengl_context = nullptr;
  }
  self->backend_type = 0;
}

static void ensure_vulkan_context(ThermionFlutterPlugin *self)
{
  if (!self->vulkan_context)
  {
    self->vulkan_context = new thermion::vulkan::linux_platform::LinuxVulkanContext();
    self->backend_type = BACKEND_VULKAN;
  }
}

static void ensure_opengl_context(ThermionFlutterPlugin *self)
{
  if (self->use_direct_opengl || self->opengl_context)
  {
    return; // already initialized
  }

  // === Use Flutter's render context ===
  // The deferred texture path captures Flutter's render context during the
  // first populate() call. Fall back to the current context (GDK) if no
  // deferred texture has been populated yet.
  {
    EGLContext flutterCtx = thermion_flutter_render_context;
    EGLDisplay flutterDpy = thermion_flutter_render_display;

    if (flutterCtx != EGL_NO_CONTEXT) {
      std::cerr << "[ThermionGL] Using Flutter render context="
                << (void*)flutterCtx << std::endl;
    }

    if (flutterCtx != EGL_NO_CONTEXT && flutterDpy != EGL_NO_DISPLAY)
    {
      EGLint clientType = 0, glMajor = 0, glMinor = 0, configId = 0;
      eglQueryContext(flutterDpy, flutterCtx, EGL_CONTEXT_CLIENT_TYPE, &clientType);
      eglQueryContext(flutterDpy, flutterCtx, EGL_CONTEXT_MAJOR_VERSION_KHR, &glMajor);
      eglQueryContext(flutterDpy, flutterCtx, EGL_CONTEXT_MINOR_VERSION_KHR, &glMinor);
      eglQueryContext(flutterDpy, flutterCtx, EGL_CONFIG_ID, &configId);

      std::cerr << "[ThermionGL] Captured Flutter context=" << (void *)flutterCtx
                << " display=" << (void *)flutterDpy
                << " type=0x" << std::hex << clientType << std::dec
                << " (" << (clientType == EGL_OPENGL_ES_API ? "GLES" : "GL") << ")"
                << " version=" << glMajor << "." << glMinor
                << " config_id=" << configId << std::endl;

      // Get the matching EGL config
      EGLConfig config = nullptr;
      EGLint numConfigs = 0;
      EGLint configAttribs[] = { EGL_CONFIG_ID, configId, EGL_NONE };
      eglChooseConfig(flutterDpy, configAttribs, &config, 1, &numConfigs);

      if (clientType == EGL_OPENGL_API &&
          (glMajor > 4 || (glMajor == 4 && glMinor >= 1)) &&
          numConfigs > 0 && config != nullptr)
      {
        // Bind the appropriate API (GL or GLES) to match Flutter
        eglBindAPI(clientType == EGL_OPENGL_ES_API ? EGL_OPENGL_ES_API : EGL_OPENGL_API);

        // Create utility context sharing with Flutter
        EGLint ctxAttribs[] = {
            EGL_CONTEXT_MAJOR_VERSION, glMajor > 0 ? glMajor : 3,
            EGL_CONTEXT_MINOR_VERSION, glMinor > 0 ? glMinor : 0,
            EGL_NONE
        };
        EGLContext utilityCtx = eglCreateContext(flutterDpy, config, flutterCtx, ctxAttribs);

        if (utilityCtx != EGL_NO_CONTEXT)
        {
          self->flutter_egl_context = flutterCtx;
          self->utility_egl_context = utilityCtx;
          self->egl_display = flutterDpy;
          self->egl_config = config;
          self->use_direct_opengl = TRUE;
          self->backend_type = BACKEND_OPENGL;
          self->thermion_platform =
              ThermionPlatformEGLHeadless_Create(flutterDpy);

          std::cerr << "[ThermionGL] Created utility context=" << (void *)utilityCtx
                    << " (shared with Flutter)" << std::endl;
          return;
        }
        else
        {
          std::cerr << "[ThermionGL] eglCreateContext(shared) failed: 0x"
                    << std::hex << eglGetError() << std::dec
                    << ", falling back" << std::endl;
        }
      }
      else
      {
        std::cerr << "[ThermionGL] Could not find EGL config for config_id="
                  << configId << ", falling back" << std::endl;
      }
    }
    else
    {
      std::cerr << "[ThermionGL] No EGL context current on this thread,"
                << " falling back to LinuxOpenGLContext" << std::endl;
    }
  }

  // Flutter normally uses GLES on Linux, while Filament requires desktop GL.
  // Keep the existing DMA-BUF transport, but create Filament's desktop context
  // on Flutter's already-initialized display instead of racing a second one.
  if (thermion_flutter_render_display != EGL_NO_DISPLAY)
  {
    std::cerr << "[ThermionGL] Using Flutter EGLDisplay with DMA-BUF transport"
              << std::endl;
    self->opengl_context =
        new thermion::opengl::linux_platform::LinuxOpenGLContext(
            reinterpret_cast<void*>(thermion_flutter_render_display));
    self->backend_type = BACKEND_OPENGL;
  }
}

static FlMethodResponse *handle_get_driver_platform(ThermionFlutterPlugin *self, FlMethodCall *method_call)
{
  FlValue *args = fl_method_call_get_args(method_call);
  int backend = (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_INT)
                    ? fl_value_get_int(args)
                    : BACKEND_VULKAN;

  int64_t platform = 0;
  if (backend == BACKEND_OPENGL)
  {
    ensure_opengl_context(self);
    if (!self->use_direct_opengl && !self->opengl_context)
    {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "CONTEXT_NOT_READY",
          "Display the Linux OpenGL bootstrap texture before initialization",
          nullptr));
    }
    if (self->use_direct_opengl)
    {
      platform = reinterpret_cast<int64_t>(self->thermion_platform);
    }
    else
    {
      platform = reinterpret_cast<int64_t>(self->opengl_context->GetPlatform());
    }
  }
  else
  {
    ensure_vulkan_context(self);
    platform = reinterpret_cast<int64_t>(self->vulkan_context->GetPlatform());
  }

  g_autoptr(FlValue) result = fl_value_new_int(platform);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *handle_get_shared_context(ThermionFlutterPlugin *self, FlMethodCall *method_call)
{
  FlValue *args = fl_method_call_get_args(method_call);
  int backend = (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_INT)
                    ? fl_value_get_int(args)
                    : BACKEND_VULKAN;

  int64_t sharedCtx = 0;
  if (backend == BACKEND_OPENGL)
  {
    ensure_opengl_context(self);
    if (!self->use_direct_opengl && !self->opengl_context)
    {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "CONTEXT_NOT_READY",
          "Display the Linux OpenGL bootstrap texture before initialization",
          nullptr));
    }
    if (self->use_direct_opengl)
    {
      // Direct sharing: return Flutter's context (Filament contexts share with it)
      sharedCtx = reinterpret_cast<int64_t>(self->flutter_egl_context);
    }
    else
    {
      sharedCtx = reinterpret_cast<int64_t>(self->opengl_context->GetSharedContext());
    }
  }
  else
  {
    ensure_vulkan_context(self);
    sharedCtx = reinterpret_cast<int64_t>(self->vulkan_context->GetSharedContext());
  }

  g_autoptr(FlValue) result = fl_value_new_int(sharedCtx);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *handle_create_texture_vulkan(ThermionFlutterPlugin *self, int width, int height)
{
  ensure_vulkan_context(self);

  int64_t surfaceId = self->vulkan_context->CreateRenderingSurface(
      static_cast<uint32_t>(width), static_cast<uint32_t>(height));
  if (surfaceId < 0)
  {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "CREATE_FAILED", "Failed to create Vulkan rendering surface", nullptr));
  }

  auto *extImg = static_cast<thermion::vulkan::ExternalVulkanImage *>(
      self->vulkan_context->CreateExternalImageForSurface(surfaceId));
  if (!extImg)
  {
    self->vulkan_context->DestroyRenderingSurface(surfaceId);
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "CREATE_FAILED", "Failed to create external image", nullptr));
  }

  (*self->external_images)[surfaceId] = extImg;

  auto info = self->vulkan_context->GetSurfaceExportInfo(surfaceId);

  ThermionTextureGL *textureGL = thermion_texture_gl_create(
      info, surfaceId, self->texture_registrar);

  FlTexture *flTexture = FL_TEXTURE(textureGL);
  if (!fl_texture_registrar_register_texture(self->texture_registrar, flTexture))
  {
    // Nothing has referenced extImg yet (Texture_setExternalImage never ran), so its
    // refcount is still zero. Let it expire and Filament performs the delete.
    filament::backend::Platform::ExternalImageHandle reclaim(extImg);
    self->external_images->erase(surfaceId);
    self->vulkan_context->DestroyRenderingSurface(surfaceId);
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "REGISTER_FAILED", "Failed to register texture with Flutter", nullptr));
  }

  self->textures->push_back(textureGL);

  int64_t flutterTextureId = fl_texture_get_id(flTexture);
  int64_t externalImagePtr = reinterpret_cast<int64_t>(extImg);

  g_autoptr(FlValue) result = fl_value_new_list();
  fl_value_append_take(result, fl_value_new_int(flutterTextureId));
  fl_value_append_take(result, fl_value_new_int(externalImagePtr));
  fl_value_append_take(result, fl_value_new_int(0));

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *handle_create_texture_opengl_direct(ThermionFlutterPlugin *self, int width, int height)
{
  // EGLImage bridge: create GL texture on utility context (Group B, same as
  // Filament), then bridge to Flutter's render context (Group A) via EGLImage.
  // - Filament imports the GL texture directly (same share group)
  // - Flutter imports the EGLImage in populate() (cross share group)

  EGLDisplay display = self->egl_display;
  GLuint glTexId = 0;
  EGLImage eglImage = EGL_NO_IMAGE_KHR;

  {
    EglContextGuard guard(display);

    // Make utility context current (Group B)
    if (!eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, self->utility_egl_context))
    {
      std::cerr << "[ThermionGL] Failed to make utility context current: 0x"
                << std::hex << eglGetError() << std::dec << std::endl;
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "EGL_ERROR", "Failed to make utility context current", nullptr));
    }

    // Create GL texture on utility context
    glGenTextures(1, &glTexId);
    glBindTexture(GL_TEXTURE_2D, glTexId);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);

    // Create EGLImage from the GL texture (bridges Group B → Group A)
    // Must be called while the owning context is current
    EGLint imageAttribs[] = { EGL_GL_TEXTURE_LEVEL_KHR, 0, EGL_NONE };
    eglImage = eglCreateImageKHR(
        display, self->utility_egl_context,
        EGL_GL_TEXTURE_2D_KHR,
        (EGLClientBuffer)(uintptr_t)glTexId,
        imageAttribs);
  } // guard restores previous context

  if (eglImage == EGL_NO_IMAGE_KHR)
  {
    EGLint err = eglGetError();
    std::cerr << "[ThermionGL] eglCreateImageKHR failed: 0x"
              << std::hex << err << std::dec << std::endl;
    {
      EglContextGuard guard(display);
      eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, self->utility_egl_context);
      glDeleteTextures(1, &glTexId);
    }
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "EGL_ERROR", "Failed to create EGLImage from GL texture", nullptr));
  }

  // Register with Flutter using the EGLImage bridge path — populate() will
  // import the EGLImage into a new texture on Flutter's render context
  ThermionTextureGL *textureGL = thermion_texture_gl_create_shared(
      static_cast<uint32_t>(width), static_cast<uint32_t>(height),
      glTexId, eglImage,
      static_cast<int64_t>(glTexId),  // surface_id = GL texture ID (for Filament import)
      self->texture_registrar);

  FlTexture *flTexture = FL_TEXTURE(textureGL);
  if (!fl_texture_registrar_register_texture(self->texture_registrar, flTexture))
  {
    eglDestroyImageKHR(display, eglImage);
    {
      EglContextGuard guard(display);
      eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, self->utility_egl_context);
      glDeleteTextures(1, &glTexId);
    }
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "REGISTER_FAILED", "Failed to register texture with Flutter", nullptr));
  }

  self->textures->push_back(textureGL);
  int64_t flutterTextureId = fl_texture_get_id(flTexture);

  std::cerr << "[ThermionGL] EGLImage bridge: GL=" << glTexId
            << " EGLImage=" << (void*)eglImage
            << " flutterId=" << flutterTextureId
            << " (" << width << "x" << height << ")" << std::endl;

  g_autoptr(FlValue) result = fl_value_new_list();
  fl_value_append_take(result, fl_value_new_int(flutterTextureId));
  fl_value_append_take(result, fl_value_new_int(static_cast<int64_t>(glTexId)));  // hardwareId = GL texture (visible to Filament)
  fl_value_append_take(result, fl_value_new_int(0));

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// DMA-BUF fallback path for OpenGL
static FlMethodResponse *handle_create_texture_opengl_dmabuf(ThermionFlutterPlugin *self, int width, int height)
{
  int64_t surfaceId = self->opengl_context->CreateRenderingSurface(
      static_cast<uint32_t>(width), static_cast<uint32_t>(height));
  if (surfaceId < 0)
  {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "CREATE_FAILED", "Failed to create OpenGL rendering surface", nullptr));
  }

  auto info = self->opengl_context->GetSurfaceExportInfo(surfaceId);

  ThermionTextureGL *textureGL = thermion_texture_gl_create(
      info, surfaceId, self->texture_registrar);

  FlTexture *flTexture = FL_TEXTURE(textureGL);
  if (!fl_texture_registrar_register_texture(self->texture_registrar, flTexture))
  {
    self->opengl_context->DestroyRenderingSurface(surfaceId);
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "REGISTER_FAILED", "Failed to register texture with Flutter", nullptr));
  }

  self->textures->push_back(textureGL);

  int64_t flutterTextureId = fl_texture_get_id(flTexture);
  // For OpenGL, hardwareId is the GL texture ID (used by Dart for Texture::Builder().import())
  uint32_t glTextureId = self->opengl_context->GetGLTextureId(surfaceId);

  g_autoptr(FlValue) result = fl_value_new_list();
  fl_value_append_take(result, fl_value_new_int(flutterTextureId));
  fl_value_append_take(result, fl_value_new_int(static_cast<int64_t>(glTextureId)));
  fl_value_append_take(result, fl_value_new_int(0));

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *handle_create_texture_opengl(ThermionFlutterPlugin *self, int width, int height)
{
  ensure_opengl_context(self);

  if (!self->use_direct_opengl && !self->opengl_context)
  {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "CONTEXT_NOT_READY",
        "Display the Linux OpenGL bootstrap texture before initialization",
        nullptr));
  }

  if (self->use_direct_opengl)
  {
    return handle_create_texture_opengl_direct(self, width, height);
  }
  return handle_create_texture_opengl_dmabuf(self, width, height);
}

static FlMethodResponse *handle_create_context_bootstrap(
    ThermionFlutterPlugin *self, FlMethodCall *method_call)
{
  FlValue *args = fl_method_call_get_args(method_call);
  int width = fl_value_get_int(fl_value_get_list_value(args, 0));
  int height = fl_value_get_int(fl_value_get_list_value(args, 1));
  ThermionTextureGL *textureGL =
      thermion_texture_gl_create_context_bootstrap(
          static_cast<uint32_t>(width), static_cast<uint32_t>(height),
          self->texture_registrar);
  FlTexture *flTexture = FL_TEXTURE(textureGL);
  if (!fl_texture_registrar_register_texture(self->texture_registrar, flTexture))
  {
    g_object_unref(textureGL);
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "REGISTER_FAILED", "Failed to register context bootstrap", nullptr));
  }
  self->textures->push_back(textureGL);
  self->backend_type = BACKEND_OPENGL;
  fl_texture_registrar_mark_texture_frame_available(
      self->texture_registrar, flTexture);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(
      fl_value_new_int(fl_texture_get_id(flTexture))));
}


static FlMethodResponse *handle_create_texture(ThermionFlutterPlugin *self, FlMethodCall *method_call)
{
  FlValue *args = fl_method_call_get_args(method_call);
  int width = fl_value_get_int(fl_value_get_list_value(args, 0));
  int height = fl_value_get_int(fl_value_get_list_value(args, 1));

  if (self->backend_type == BACKEND_OPENGL)
  {
    return handle_create_texture_opengl(self, width, height);
  }
  else
  {
    return handle_create_texture_vulkan(self, width, height);
  }
}

static FlMethodResponse *handle_destroy_texture(ThermionFlutterPlugin *self, FlMethodCall *method_call)
{
  FlValue *args = fl_method_call_get_args(method_call);
  int64_t flutterTextureId = fl_value_get_int(args);

  for (auto it = self->textures->begin(); it != self->textures->end(); ++it)
  {
    ThermionTextureGL *tex = *it;
    if (fl_texture_get_id(FL_TEXTURE(tex)) == flutterTextureId)
    {
      int64_t surfaceId = tex->surface_id;

      fl_texture_registrar_unregister_texture(self->texture_registrar, FL_TEXTURE(tex));

      if (self->backend_type == BACKEND_OPENGL)
      {
        if (tex->use_direct_sharing || tex->use_egl_image)
        {
          // Direct sharing / EGLImage bridge: delete the source GL texture on utility context
          GLuint texId = tex->gl_texture_id;
          if (texId != 0 && self->utility_egl_context != EGL_NO_CONTEXT)
          {
            EglContextGuard guard(self->egl_display);
            eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                           self->utility_egl_context);
            glDeleteTextures(1, &texId);
          }
        }
        else if (self->opengl_context)
        {
          self->opengl_context->DestroyRenderingSurface(surfaceId);
        }
      }
      else
      {
        // Vulkan path: clean up external image
        auto extIt = self->external_images->find(surfaceId);
        if (extIt != self->external_images->end())
        {
          // Filament holds a reference to this ExternalImage and releases it when the
          // texture is destroyed; ExternalImage's destructor is protected to forbid manual deletion.
          // Only drop the raw pointer.
          self->external_images->erase(extIt);
        }
        if (self->vulkan_context)
        {
          self->vulkan_context->DestroyRenderingSurface(surfaceId);
        }
      }

      self->textures->erase(it);
      break;
    }
  }

  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *handle_mark_texture_frame_available(ThermionFlutterPlugin *self, FlMethodCall *method_call)
{
  static auto lastMark = std::chrono::high_resolution_clock::now();
  auto now = std::chrono::high_resolution_clock::now();
  auto intervalUs = std::chrono::duration_cast<std::chrono::microseconds>(now - lastMark).count();
  lastMark = now;

  FlValue *args = fl_method_call_get_args(method_call);
  int64_t flutterTextureId = fl_value_get_int(args);

  for (auto *tex : *self->textures)
  {
    if (fl_texture_get_id(FL_TEXTURE(tex)) == flutterTextureId)
    {
      // Direct OpenGL path: ensure Filament's rendering is flushed
      // before Flutter reads the texture
      if (self->backend_type == BACKEND_OPENGL && self->use_direct_opengl)
      {
        static int markCount = 0;
        markCount++;
        if (markCount <= 5 || markCount % 60 == 0) {
          TRACE( "[MarkFrame] #%d tex_id=%lld\n", markCount, (long long)tex->surface_id);
        }
      }

      // Vulkan path may need blit; OpenGL path never needs blit
      if (self->backend_type == BACKEND_VULKAN && self->vulkan_context)
      {
        if (self->vulkan_context->NeedsBlit(tex->surface_id))
        {
          self->vulkan_context->BlitToExport(tex->surface_id);
        }
      }

      fl_texture_registrar_mark_texture_frame_available(
          self->texture_registrar, FL_TEXTURE(tex));
      break;
    }
  }

  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *handle_destroy_context(ThermionFlutterPlugin *self)
{
  destroy_all_contexts(self);
  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Deferred response: returns the GL texture ID once populate() has created it.
// If the texture is already ready, responds immediately.
// Otherwise, stores the method_call and responds later from populate().
static void handle_await_texture_ready(ThermionFlutterPlugin *self, FlMethodCall *method_call)
{
  FlValue *args = fl_method_call_get_args(method_call);
  int64_t flutterTextureId = fl_value_get_int(args);

  for (auto *tex : *self->textures)
  {
    if (fl_texture_get_id(FL_TEXTURE(tex)) == flutterTextureId)
    {
      if (tex->gl_texture_id != 0)
      {
        // Already ready (populate already ran)
        g_autoptr(FlValue) result = fl_value_new_int(
            static_cast<int64_t>(tex->gl_texture_id));
        fl_method_call_respond(method_call,
                               FL_METHOD_RESPONSE(fl_method_success_response_new(result)), nullptr);
      }
      else
      {
        // Defer — store method_call, respond later from populate()
        g_object_ref(method_call);
        tex->pending_ready_call = method_call;
        std::cerr << "[ThermionGL] awaitTextureReady: deferred for flutterId=" << flutterTextureId << std::endl;
      }
      return;
    }
  }

  // Not found
  fl_method_call_respond(method_call,
                         FL_METHOD_RESPONSE(fl_method_error_response_new(
                             "NOT_FOUND", "Texture not registered", nullptr)),
                         nullptr);
}

// Called when a method call is received from Flutter.
static void thermion_flutter_plugin_handle_method_call(
    ThermionFlutterPlugin *self,
    FlMethodCall *method_call)
{

  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar *method = fl_method_call_get_name(method_call);

  // awaitTextureReady manages its own response (deferred pattern)
  if (strcmp(method, "awaitTextureReady") == 0)
  {
    handle_await_texture_ready(self, method_call);
    return;
  }

  if (strcmp(method, "getDriverPlatform") == 0)
  {
    response = handle_get_driver_platform(self, method_call);
  }
  else if (strcmp(method, "createContextBootstrap") == 0)
  {
    response = handle_create_context_bootstrap(self, method_call);
  }
  else if (strcmp(method, "getSharedContext") == 0)
  {
    response = handle_get_shared_context(self, method_call);
  }
  else if (strcmp(method, "createTexture") == 0)
  {
    response = handle_create_texture(self, method_call);
  }
  else if (strcmp(method, "destroyTexture") == 0)
  {
    response = handle_destroy_texture(self, method_call);
  }
  else if (strcmp(method, "markTextureFrameAvailable") == 0)
  {
    response = handle_mark_texture_frame_available(self, method_call);
  }
  else if (strcmp(method, "destroyContext") == 0)
  {
    response = handle_destroy_context(self);
  }
  else
  {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void thermion_flutter_plugin_dispose(GObject *object)
{
  ThermionFlutterPlugin *self = FLUTTER_FILAMENT_PLUGIN(object);

  destroy_all_contexts(self);

  if (self->textures)
  {
    delete self->textures;
    self->textures = nullptr;
  }
  if (self->external_images)
  {
    delete self->external_images;
    self->external_images = nullptr;
  }
  G_OBJECT_CLASS(thermion_flutter_plugin_parent_class)->dispose(object);
}

static void thermion_flutter_plugin_class_init(ThermionFlutterPluginClass *klass)
{
  G_OBJECT_CLASS(klass)->dispose = thermion_flutter_plugin_dispose;
}

static void thermion_flutter_plugin_init(ThermionFlutterPlugin *self)
{
  self->backend_type = 0;
  self->view = nullptr;
  self->vulkan_context = nullptr;
  self->flutter_egl_context = EGL_NO_CONTEXT;
  self->utility_egl_context = EGL_NO_CONTEXT;
  self->egl_display = EGL_NO_DISPLAY;
  self->egl_config = nullptr;
  self->use_direct_opengl = FALSE;
  self->thermion_platform = nullptr;
  self->opengl_context = nullptr;
  self->textures = new std::vector<ThermionTextureGL *>();
  self->external_images = new std::unordered_map<int64_t, thermion::vulkan::ExternalVulkanImage *>();
}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data)
{
  ThermionFlutterPlugin *plugin = FLUTTER_FILAMENT_PLUGIN(user_data);
  thermion_flutter_plugin_handle_method_call(plugin, method_call);
}

// Global plugin instance for cross-library access (native render loop)
static ThermionFlutterPlugin* g_plugin_instance = nullptr;

void thermion_flutter_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
  ThermionFlutterPlugin *plugin = FLUTTER_FILAMENT_PLUGIN(
      g_object_new(thermion_flutter_plugin_get_type(), nullptr));

  plugin->texture_registrar =
      fl_plugin_registrar_get_texture_registrar(registrar);
  plugin->view = fl_plugin_registrar_get_view(registrar);

  g_plugin_instance = plugin;

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "dev.thermion.flutter/event",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}

// === Exported symbols for cross-library native render loop ===

extern "C" __attribute__((visibility("default")))
void* thermion_flutter_get_plugin_handle() {
  return g_plugin_instance;
}

// Called from thermion_dart's native render loop (post-render callback)
// after each frame. Marks all textures as frame-available so Flutter
// picks up the new content on its next raster pass.
extern "C" __attribute__((visibility("default")))
void thermion_flutter_mark_textures(void* pluginPtr) {
  auto* self = FLUTTER_FILAMENT_PLUGIN(pluginPtr);
  if (!self || !self->textures || !self->texture_registrar) return;
  for (auto* tex : *self->textures) {
    fl_texture_registrar_mark_texture_frame_available(
        self->texture_registrar, FL_TEXTURE(tex));
  }
}
