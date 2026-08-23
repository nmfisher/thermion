#include "include/thermion_flutter/thermion_flutter_plugin.h"
#include "Log.hpp"

#include <flutter_linux/flutter_linux.h>
#include <flutter_linux/fl_texture_registrar.h>
#include <flutter_linux/fl_texture_gl.h>

#include <cstring>
#include <vector>
#include <memory>
#include <string>
#include <unordered_map>
#include <iostream>
#include <chrono>

#include <epoxy/egl.h>
#include <epoxy/gl.h>

#include "egl_texture.h"

// Calling Epoxy's eglDestroyImageKHR wrapper without a current EGL context
// makes provider selection depend on thread-local state. Teardown deliberately
// runs after Flutter releases its texture, so resolve the EGL entry point
// directly and let EGL dispatch from the explicit display argument.
static bool destroy_egl_image(EGLDisplay display, EGLImage image)
{
  if (display == EGL_NO_DISPLAY || image == EGL_NO_IMAGE_KHR)
  {
    return true;
  }

  static PFNEGLDESTROYIMAGEKHRPROC destroyImage =
      reinterpret_cast<PFNEGLDESTROYIMAGEKHRPROC>(
          eglGetProcAddress("eglDestroyImageKHR"));
  if (!destroyImage)
  {
    std::cerr << "[ThermionGL] eglDestroyImageKHR is unavailable" << std::endl;
    return false;
  }
  if (!destroyImage(display, image))
  {
    std::cerr << "[ThermionGL] eglDestroyImageKHR failed: 0x"
              << std::hex << eglGetError() << std::dec << std::endl;
    return false;
  }
  return true;
}

#include "vulkan/linux/LinuxVulkanContext.h"
#include "LinuxOpenGLContext.h"
#include "vulkan/ExternalVulkanImage.h"

// Backend type constants (match Dart Backend enum indices)
static const int BACKEND_OPENGL = 1;
static const int BACKEND_VULKAN = 2;

// RAII guard: saves the current EGL context/surfaces and restores on destruction.
struct EglContextGuard {
  EGLContext prevCtx;
  EGLSurface prevDraw;
  EGLSurface prevRead;
  EGLenum prevApi;
  EGLDisplay prevDisplay;
  EGLDisplay targetDisplay;

  EglContextGuard(EGLDisplay dpy)
      : prevCtx(eglGetCurrentContext()),
        prevDraw(eglGetCurrentSurface(EGL_DRAW)),
        prevRead(eglGetCurrentSurface(EGL_READ)),
        prevApi(eglQueryAPI()),
        prevDisplay(eglGetCurrentDisplay()),
        targetDisplay(dpy) {
    // EGL does not allow switching client APIs while any context is current on
    // the thread. Flutter's platform thread can have a GLES context current,
    // so release it before binding desktop GL for plugin operations.
    if (prevCtx != EGL_NO_CONTEXT && prevDisplay != EGL_NO_DISPLAY) {
      eglMakeCurrent(
          prevDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    }
  }

  ~EglContextGuard() {
    eglMakeCurrent(
        targetDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglBindAPI(prevApi);
    if (prevCtx != EGL_NO_CONTEXT && prevDisplay != EGL_NO_DISPLAY) {
      eglMakeCurrent(prevDisplay, prevDraw, prevRead, prevCtx);
    }
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

  // OpenGL path — imports Flutter's EGL context before Filament starts.
  EGLenum flutter_egl_api;
  // Used to release Flutter-owned texture names imported from DMA-BUF.
  EGLContext flutter_utility_egl_context;
  EGLDisplay egl_display;           // Flutter's EGL display
  // OpenGL producer context with GBM/DMA-BUF transport.
  thermion::opengl::linux_platform::LinuxOpenGLContext *opengl_context;
  std::string opengl_initialization_error;

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
  if (self->flutter_utility_egl_context != EGL_NO_CONTEXT &&
      self->egl_display != EGL_NO_DISPLAY)
  {
    eglDestroyContext(
        self->egl_display, self->flutter_utility_egl_context);
    self->flutter_utility_egl_context = EGL_NO_CONTEXT;
  }
  if (self->opengl_context)
  {
    delete self->opengl_context;
    self->opengl_context = nullptr;
  }
  self->flutter_egl_api = EGL_NONE;
  self->egl_display = EGL_NO_DISPLAY;
  thermion_flutter_render_context = EGL_NO_CONTEXT;
  thermion_flutter_render_display = EGL_NO_DISPLAY;
  thermion_flutter_render_api = EGL_NONE;
  thermion_flutter_render_gl_major = 0;
  thermion_flutter_render_gl_minor = 0;
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

static EGLContext create_flutter_utility_context(
    ThermionFlutterPlugin *self,
    EGLDisplay display,
    EGLConfig config,
    EGLContext sharedContext,
    EGLenum api,
    EGLint major,
    EGLint minor)
{
  EglContextGuard guard(display);
  if (!eglBindAPI(api))
  {
    self->opengl_initialization_error =
        "Could not bind Flutter's EGL client API";
    return EGL_NO_CONTEXT;
  }

  EGLint attributes[] = {
      EGL_CONTEXT_MAJOR_VERSION, major,
      EGL_CONTEXT_MINOR_VERSION, minor,
      EGL_NONE};
  EGLContext context =
      eglCreateContext(display, config, sharedContext, attributes);
  if (context == EGL_NO_CONTEXT)
  {
    std::cerr << "[ThermionGL] Could not create a context shared with "
                 "Flutter: 0x"
              << std::hex << eglGetError() << std::dec << std::endl;
    self->opengl_initialization_error =
        "Could not create a utility context shared with Flutter";
  }
  return context;
}

// Creates only the context needed to delete a populated bootstrap texture.
// This avoids initializing Filament's platform and GBM producer when a widget
// is disposed between the raster handshake and engine initialization.
static bool initialize_bootstrap_cleanup_context(
    ThermionFlutterPlugin *self)
{
  EGLDisplay display = thermion_flutter_render_display;
  EGLContext flutterContext = thermion_flutter_render_context;
  EGLenum api = thermion_flutter_render_api;
  EGLint major = thermion_flutter_render_gl_major;
  EGLint minor = thermion_flutter_render_gl_minor;
  EGLint configId = 0;
  if (display == EGL_NO_DISPLAY || flutterContext == EGL_NO_CONTEXT ||
      (api != EGL_OPENGL_API && api != EGL_OPENGL_ES_API) ||
      !eglQueryContext(display, flutterContext, EGL_CONFIG_ID, &configId))
  {
    return false;
  }

  EGLConfig config = nullptr;
  EGLint configCount = 0;
  EGLint configAttributes[] = {EGL_CONFIG_ID, configId, EGL_NONE};
  if (!eglChooseConfig(
          display, configAttributes, &config, 1, &configCount) ||
      configCount == 0 || config == nullptr)
  {
    return false;
  }

  EGLContext utilityContext = create_flutter_utility_context(
      self, display, config, flutterContext, api, major, minor);
  if (utilityContext == EGL_NO_CONTEXT)
  {
    return false;
  }

  self->flutter_egl_api = api;
  self->flutter_utility_egl_context = utilityContext;
  self->egl_display = display;
  self->backend_type = BACKEND_OPENGL;
  return true;
}

static bool initialize_opengl_dmabuf(
    ThermionFlutterPlugin *self,
    EGLDisplay display,
    EGLConfig config,
    EGLContext flutterContext,
    EGLenum api,
    EGLint major,
    EGLint minor)
{
  auto context = new thermion::opengl::linux_platform::LinuxOpenGLContext(
      reinterpret_cast<void *>(display));
  if (!context->IsValid())
  {
    self->opengl_initialization_error = context->GetLastError();
    delete context;
    return false;
  }

  EGLContext utilityContext = create_flutter_utility_context(
      self, display, config, flutterContext, api, major, minor);
  if (utilityContext == EGL_NO_CONTEXT)
  {
    delete context;
    return false;
  }

  self->opengl_context = context;
  self->flutter_egl_api = api;
  self->flutter_utility_egl_context = utilityContext;
  self->egl_display = display;
  self->backend_type = BACKEND_OPENGL;
  return true;
}

static bool ensure_opengl_context(ThermionFlutterPlugin *self)
{
  if (self->opengl_context)
  {
    return true; // already initialized
  }
  self->opengl_initialization_error.clear();

  // Flutter's raster context is only guaranteed to be current inside an
  // FlTextureGL populate callback. Dart must display and await the deferred
  // context-bootstrap texture before requesting Filament's driver platform.
  EGLContext flutterCtx = thermion_flutter_render_context;
  EGLDisplay flutterDpy = thermion_flutter_render_display;
  if (flutterCtx == EGL_NO_CONTEXT || flutterDpy == EGL_NO_DISPLAY)
  {
    std::cerr
        << "[ThermionGL] Flutter raster context is not ready; "
           "create and await the context bootstrap texture before "
           "initializing Filament"
        << std::endl;
    self->opengl_initialization_error =
        "Flutter's raster EGL context has not been imported";
    return false;
  }

  EGLenum clientType = thermion_flutter_render_api;
  EGLint glMajor = thermion_flutter_render_gl_major;
  EGLint glMinor = thermion_flutter_render_gl_minor;
  EGLint configId = 0;
  if ((clientType != EGL_OPENGL_API &&
       clientType != EGL_OPENGL_ES_API) ||
      glMajor <= 0 ||
      !eglQueryContext(flutterDpy, flutterCtx, EGL_CONFIG_ID, &configId))
  {
    std::cerr << "[ThermionGL] Could not query Flutter's EGL context: 0x"
              << std::hex << eglGetError() << std::dec << std::endl;
    self->opengl_initialization_error =
        "Could not query Flutter's raster EGL context";
    return false;
  }

  std::cerr << "[ThermionGL] Imported Flutter raster context="
            << (void *)flutterCtx
            << " display=" << (void *)flutterDpy
            << " type=0x" << std::hex << clientType << std::dec
            << " (" << (clientType == EGL_OPENGL_ES_API ? "GLES" : "GL") << ")"
            << " version=" << glMajor << "." << glMinor
            << " config_id=" << configId << std::endl;

  EGLConfig flutterConfig = nullptr;
  EGLint numConfigs = 0;
  EGLint configAttribs[] = { EGL_CONFIG_ID, configId, EGL_NONE };
  if (!eglChooseConfig(
          flutterDpy, configAttribs, &flutterConfig, 1, &numConfigs) ||
      numConfigs == 0 || flutterConfig == nullptr)
  {
    std::cerr << "[ThermionGL] Could not find Flutter's EGL config "
              << configId << ": 0x" << std::hex << eglGetError()
              << std::dec << std::endl;
    self->opengl_initialization_error =
        "Could not resolve Flutter's EGLConfig";
    return false;
  }

  // Filament uses desktop OpenGL while Flutter may expose either desktop GL
  // or GLES. Keep one transport for both cases: render into a GBM buffer on
  // Flutter's EGLDisplay and import it into Flutter through DMA-BUF.
  return initialize_opengl_dmabuf(
      self, flutterDpy, flutterConfig, flutterCtx,
      static_cast<EGLenum>(clientType), glMajor, glMinor);
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
    gboolean rasterContextReady =
        thermion_flutter_render_context != EGL_NO_CONTEXT &&
        thermion_flutter_render_display != EGL_NO_DISPLAY;
    if (!ensure_opengl_context(self))
    {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          rasterContextReady ? "OPENGL_INITIALIZATION_FAILED"
                             : "CONTEXT_NOT_READY",
          rasterContextReady
              ? self->opengl_initialization_error.c_str()
              : "Flutter's raster EGL context must be imported before "
                "Filament OpenGL initialization",
          nullptr));
    }
    platform = reinterpret_cast<int64_t>(self->opengl_context->GetPlatform());
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
    gboolean rasterContextReady =
        thermion_flutter_render_context != EGL_NO_CONTEXT &&
        thermion_flutter_render_display != EGL_NO_DISPLAY;
    if (!ensure_opengl_context(self))
    {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          rasterContextReady ? "OPENGL_INITIALIZATION_FAILED"
                             : "CONTEXT_NOT_READY",
          rasterContextReady
              ? self->opengl_initialization_error.c_str()
              : "Flutter's raster EGL context must be imported before "
                "Filament OpenGL initialization",
          nullptr));
    }
    sharedCtx = reinterpret_cast<int64_t>(self->opengl_context->GetSharedContext());
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
  gboolean rasterContextReady =
      thermion_flutter_render_context != EGL_NO_CONTEXT &&
      thermion_flutter_render_display != EGL_NO_DISPLAY;
  if (!ensure_opengl_context(self))
  {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        rasterContextReady ? "OPENGL_INITIALIZATION_FAILED"
                           : "CONTEXT_NOT_READY",
        rasterContextReady
            ? self->opengl_initialization_error.c_str()
            : "Cannot create an OpenGL texture before Flutter's raster "
              "context is ready",
        nullptr));
  }

  return handle_create_texture_opengl_dmabuf(self, width, height);
}

static FlMethodResponse *handle_create_context_bootstrap(
    ThermionFlutterPlugin *self, FlMethodCall *method_call)
{
  FlValue *args = fl_method_call_get_args(method_call);
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_LIST ||
      fl_value_get_length(args) < 2)
  {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENTS", "Expected bootstrap texture width and height",
        nullptr));
  }

  int width = fl_value_get_int(fl_value_get_list_value(args, 0));
  int height = fl_value_get_int(fl_value_get_list_value(args, 1));
  if (width <= 0 || height <= 0)
  {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENTS", "Bootstrap texture dimensions must be positive",
        nullptr));
  }

  ThermionTextureGL *textureGL =
      thermion_texture_gl_create_context_bootstrap(
          static_cast<uint32_t>(width), static_cast<uint32_t>(height),
          self->texture_registrar);
  FlTexture *flTexture = FL_TEXTURE(textureGL);
  if (!fl_texture_registrar_register_texture(
          self->texture_registrar, flTexture))
  {
    g_object_unref(textureGL);
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "REGISTER_FAILED",
        "Failed to register Flutter context bootstrap texture", nullptr));
  }

  self->textures->push_back(textureGL);
  self->backend_type = BACKEND_OPENGL;
  fl_texture_registrar_mark_texture_frame_available(
      self->texture_registrar, flTexture);

  int64_t flutterTextureId = fl_texture_get_id(flTexture);
  std::cerr << "[ThermionGL] Registered context bootstrap texture, flutterId="
            << flutterTextureId << std::endl;
  g_autoptr(FlValue) result = fl_value_new_int(flutterTextureId);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
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
      ThermionTextureKind textureKind = tex->kind;
      GLuint glTextureId = tex->gl_texture_id;
      EGLImage eglImage = tex->egl_image;
      FlMethodCall *pendingReadyCall = tex->pending_ready_call;
      tex->pending_ready_call = nullptr;

      if (pendingReadyCall)
      {
        fl_method_call_respond(
            pendingReadyCall,
            FL_METHOD_RESPONSE(fl_method_error_response_new(
                "DESTROYED",
                "Texture destroyed before Flutter populated it", nullptr)),
            nullptr);
        g_object_unref(pendingReadyCall);
      }

      fl_texture_registrar_unregister_texture(self->texture_registrar, FL_TEXTURE(tex));

      gboolean initializedOnlyForBootstrapCleanup = FALSE;
      if (self->backend_type == BACKEND_OPENGL)
      {
        if (textureKind == THERMION_TEXTURE_KIND_CONTEXT_BOOTSTRAP)
        {
          if (glTextureId != 0 &&
              self->flutter_utility_egl_context == EGL_NO_CONTEXT)
          {
            // A bootstrap may be cancelled after populate() but before Dart
            // requests the driver platform. Create only a cleanup context in
            // Flutter's share group; do not initialize Filament or GBM.
            initializedOnlyForBootstrapCleanup =
                initialize_bootstrap_cleanup_context(self);
          }
          if (glTextureId != 0 &&
              self->flutter_utility_egl_context != EGL_NO_CONTEXT)
          {
            EglContextGuard guard(self->egl_display);
            eglBindAPI(self->flutter_egl_api);
            eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                           self->flutter_utility_egl_context);
            glDeleteTextures(1, &glTextureId);
          }
        }
        else if (self->opengl_context)
        {
          // DMA-BUF path: populate() created the consumer texture and
          // EGLImage in Flutter's GLES share group. Release those before the
          // producer destroys the backing GBM buffer.
          if (glTextureId != 0 &&
              self->flutter_utility_egl_context != EGL_NO_CONTEXT)
          {
            EglContextGuard guard(self->egl_display);
            eglBindAPI(self->flutter_egl_api);
            if (eglMakeCurrent(
                    self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                    self->flutter_utility_egl_context))
            {
              glDeleteTextures(1, &glTextureId);
            }
          }
          if (eglImage != EGL_NO_IMAGE_KHR &&
              self->egl_display != EGL_NO_DISPLAY)
          {
            destroy_egl_image(self->egl_display, eglImage);
          }
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
      if (self->backend_type == BACKEND_OPENGL)
      {
        // The plugin retains each factory's construction reference in
        // addition to the registrar's reference. All OpenGL/EGL objects have
        // now been deleted from their owning contexts.
        tex->gl_texture_id = 0;
        tex->egl_image = EGL_NO_IMAGE_KHR;
        g_object_unref(tex);
      }
      if (initializedOnlyForBootstrapCleanup)
      {
        destroy_all_contexts(self);
      }
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
  self->flutter_egl_api = EGL_NONE;
  self->flutter_utility_egl_context = EGL_NO_CONTEXT;
  self->egl_display = EGL_NO_DISPLAY;
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

// Global plugin instance used by Dart's direct post-render texture notifier.
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

// === Exported symbols for Dart post-render texture notification ===

extern "C" __attribute__((visibility("default")))
void* thermion_flutter_get_plugin_handle() {
  return g_plugin_instance;
}

// Called from Dart after the common render future completes. Marks all
// textures as frame-available so Flutter picks up the new content on its next
// raster pass.
extern "C" __attribute__((visibility("default")))
void thermion_flutter_mark_textures(void* pluginPtr) {
  auto* self = FLUTTER_FILAMENT_PLUGIN(pluginPtr);
  if (!self || !self->textures || !self->texture_registrar) return;
  for (auto* tex : *self->textures) {
    fl_texture_registrar_mark_texture_frame_available(
        self->texture_registrar, FL_TEXTURE(tex));
  }
}
