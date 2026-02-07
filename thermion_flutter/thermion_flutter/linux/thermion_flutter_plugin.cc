#include "include/thermion_flutter/thermion_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <flutter_linux/fl_texture_registrar.h>
#include <flutter_linux/fl_texture_gl.h>
#include <gtk/gtk.h>

#include <cstring>
#include <vector>
#include <memory>

#include "egl_texture.h"
#include "linux_vulkan_context_api.h"

#define FLUTTER_FILAMENT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), thermion_flutter_plugin_get_type(), \
                              ThermionFlutterPlugin))

struct _ThermionFlutterPlugin {
  GObject parent_instance;
  FlTextureRegistrar* texture_registrar;
  ThermionLinuxVulkanContextHandle context;
  std::vector<ThermionTextureGL*>* textures;
};

G_DEFINE_TYPE(ThermionFlutterPlugin, thermion_flutter_plugin, g_object_get_type())

static void ensure_context(ThermionFlutterPlugin* self) {
  if (!self->context) {
    self->context = ThermionLinuxVulkanContext_Create();
  }
}

static FlMethodResponse* handle_get_driver_platform(ThermionFlutterPlugin* self) {
  ensure_context(self);
  g_autoptr(FlValue) result = fl_value_new_int(
      ThermionLinuxVulkanContext_GetPlatform(self->context));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_get_shared_context(ThermionFlutterPlugin* self) {
  ensure_context(self);
  g_autoptr(FlValue) result = fl_value_new_int(
      ThermionLinuxVulkanContext_GetSharedContext(self->context));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_create_texture(ThermionFlutterPlugin* self, FlMethodCall* method_call) {
  ensure_context(self);

  FlValue* args = fl_method_call_get_args(method_call);
  int width = fl_value_get_int(fl_value_get_list_value(args, 0));
  int height = fl_value_get_int(fl_value_get_list_value(args, 1));

  // Create rendering surface (pure VkImage + exportable dmabuf VkImage)
  int64_t surfaceId = ThermionLinuxVulkanContext_CreateRenderingSurface(
      self->context, static_cast<uint32_t>(width), static_cast<uint32_t>(height));
  if (surfaceId < 0) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "CREATE_FAILED", "Failed to create rendering surface", nullptr));
  }

  // Get dmabuf info for the exportable texture
  int dmaBufFd = ThermionLinuxVulkanContext_GetDmaBufFd(self->context, surfaceId);
  uint32_t stride = ThermionLinuxVulkanContext_GetStride(self->context, surfaceId);
  uint32_t offset = ThermionLinuxVulkanContext_GetOffset(self->context, surfaceId);
  uint32_t drmFormat = ThermionLinuxVulkanContext_GetDrmFormat(self->context, surfaceId);

  // Create EGL texture wrapper (lazy initialization in populate())
  ThermionTextureGL* textureGL = thermion_texture_gl_create(
      static_cast<uint32_t>(width), static_cast<uint32_t>(height),
      dmaBufFd, stride, offset, drmFormat,
      surfaceId, self->texture_registrar);

  // Register with Flutter
  FlTexture* flTexture = FL_TEXTURE(textureGL);
  if (!fl_texture_registrar_register_texture(self->texture_registrar, flTexture)) {
    ThermionLinuxVulkanContext_DestroyRenderingSurface(self->context, surfaceId);
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "REGISTER_FAILED", "Failed to register texture with Flutter", nullptr));
  }

  self->textures->push_back(textureGL);

  int64_t flutterTextureId = fl_texture_get_id(flTexture);

  // Return [flutterTextureId, 0, 0]
  // vkImage=0 signals to Dart that Vulkan import is not supported,
  // so it should use a headless swapchain instead of a RenderTarget.
  g_autoptr(FlValue) result = fl_value_new_list();
  fl_value_append_take(result, fl_value_new_int(flutterTextureId));
  fl_value_append_take(result, fl_value_new_int(0));
  fl_value_append_take(result, fl_value_new_int(0));

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_destroy_texture(ThermionFlutterPlugin* self, FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  int64_t flutterTextureId = fl_value_get_int(args);

  // Find the texture with this flutter ID
  for (auto it = self->textures->begin(); it != self->textures->end(); ++it) {
    ThermionTextureGL* tex = *it;
    if (fl_texture_get_id(FL_TEXTURE(tex)) == flutterTextureId) {
      int64_t surfaceId = tex->surface_id;

      // Unregister from Flutter
      fl_texture_registrar_unregister_texture(self->texture_registrar, FL_TEXTURE(tex));

      // Destroy the Vulkan rendering surface
      if (self->context) {
        ThermionLinuxVulkanContext_DestroyRenderingSurface(self->context, surfaceId);
      }

      self->textures->erase(it);
      break;
    }
  }

  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_mark_texture_frame_available(ThermionFlutterPlugin* self, FlMethodCall* method_call) {
  if (!self->context) {
    g_autoptr(FlValue) result = fl_value_new_null();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  FlValue* args = fl_method_call_get_args(method_call);
  int64_t flutterTextureId = fl_value_get_int(args);

  // Find the texture and blit
  for (auto* tex : *self->textures) {
    if (fl_texture_get_id(FL_TEXTURE(tex)) == flutterTextureId) {
      ThermionLinuxVulkanContext_Blit(self->context, tex->surface_id);
      fl_texture_registrar_mark_texture_frame_available(
          self->texture_registrar, FL_TEXTURE(tex));
      break;
    }
  }

  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_destroy_context(ThermionFlutterPlugin* self) {
  if (self->context) {
    ThermionLinuxVulkanContext_Destroy(self->context);
    self->context = nullptr;
  }
  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Called when a method call is received from Flutter.
static void thermion_flutter_plugin_handle_method_call(
    ThermionFlutterPlugin* self,
    FlMethodCall* method_call) {

  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getDriverPlatform") == 0) {
    response = handle_get_driver_platform(self);
  } else if (strcmp(method, "getSharedContext") == 0) {
    response = handle_get_shared_context(self);
  } else if (strcmp(method, "createTexture") == 0) {
    response = handle_create_texture(self, method_call);
  } else if (strcmp(method, "destroyTexture") == 0) {
    response = handle_destroy_texture(self, method_call);
  } else if (strcmp(method, "markTextureFrameAvailable") == 0) {
    response = handle_mark_texture_frame_available(self, method_call);
  } else if (strcmp(method, "destroyContext") == 0) {
    response = handle_destroy_context(self);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void thermion_flutter_plugin_dispose(GObject* object) {
  ThermionFlutterPlugin* self = FLUTTER_FILAMENT_PLUGIN(object);
  if (self->context) {
    ThermionLinuxVulkanContext_Destroy(self->context);
    self->context = nullptr;
  }
  if (self->textures) {
    delete self->textures;
    self->textures = nullptr;
  }
  G_OBJECT_CLASS(thermion_flutter_plugin_parent_class)->dispose(object);
}

static void thermion_flutter_plugin_class_init(ThermionFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = thermion_flutter_plugin_dispose;
}

static void thermion_flutter_plugin_init(ThermionFlutterPlugin* self) {
  self->context = nullptr;
  self->textures = new std::vector<ThermionTextureGL*>();
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  ThermionFlutterPlugin* plugin = FLUTTER_FILAMENT_PLUGIN(user_data);
  thermion_flutter_plugin_handle_method_call(plugin, method_call);
}

void thermion_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  ThermionFlutterPlugin* plugin = FLUTTER_FILAMENT_PLUGIN(
      g_object_new(thermion_flutter_plugin_get_type(), nullptr));

  plugin->texture_registrar =
      fl_plugin_registrar_get_texture_registrar(registrar);

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
