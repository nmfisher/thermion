#include "include/polyvox_filament/polyvox_filament_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <flutter_linux/fl_texture_registrar.h>
#include <flutter_linux/fl_texture_gl.h>
#include <gtk/gtk.h>

#include <sys/utsname.h>

#include <math.h>
#include <iostream>
#include <cstring>
#include <vector>
#include <string> 
#include <map>
#include <unistd.h>

#include "include/polyvox_filament/filament_texture.h"
#include "include/polyvox_filament/filament_pb_texture.h"
#include "include/polyvox_filament/resource_loader.hpp"

#include "FilamentViewer.hpp"
extern "C" {
#include "PolyvoxFilamentApi.h"
}


#include <epoxy/gl.h>
#include <epoxy/glx.h>

#define POLYVOX_FILAMENT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), polyvox_filament_plugin_get_type(), \
                              PolyvoxFilamentPlugin))


struct _PolyvoxFilamentPlugin {
  GObject parent_instance;
  FlTextureRegistrar* texture_registrar;
  FlView* fl_view;

  FlTexture* texture;
  void* _viewer;
};

G_DEFINE_TYPE(PolyvoxFilamentPlugin, polyvox_filament_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void polyvox_filament_plugin_handle_method_call(
    PolyvoxFilamentPlugin* self,
    FlMethodCall* method_call) {

  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if(strcmp(method, "initialize") == 0) {

    if(self->_viewer) {
      std::cout << "Deleting existing viewer";
      filament_viewer_delete(self->_viewer);
    } 

    auto context = glXGetCurrentContext();

    FlValue* args = fl_method_call_get_args(method_call);

    const double width = fl_value_get_float(fl_value_get_list_value(args, 0));
    const double height = fl_value_get_float(fl_value_get_list_value(args, 1));
   
    auto texture = create_filament_texture(uint32_t(width), uint32_t(height), self->texture_registrar);
    //auto texture = create_filament_pb_texture(uint32_t(width), uint32_t(height), self->texture_registrar);
    self->texture = texture;
    
    g_autoptr(FlValue) result =   
         fl_value_new_int(reinterpret_cast<int64_t>(texture));   

    self->_viewer = filament_viewer_new(
      (void*)context,
      loadResource,
      freeResource
    );

    // don't pass a surface to the SwapChain as we are effectively creating a headless SwapChain that will render into a RenderTarget associated with a texture
    create_swap_chain(self->_viewer, nullptr, width, height);
    create_render_target(self->_viewer, ((FilamentTextureGL*)texture)->texture_id,width,height);
    
    update_viewport_and_camera_projection(self->_viewer, width, height, 1.0f);
    
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if(strcmp(method, "loadSkybox") == 0) {

    FlValue* args = fl_method_call_get_args(method_call);

    const gchar* path = fl_value_get_string(args);

    load_skybox(self->_viewer, path);
                                       
    g_autoptr(FlValue) result = fl_value_new_string("OK");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if(strcmp(method, "removeSkybox") == 0) {
    std::cout << "Removing skybox" << std::endl;
    remove_skybox(self->_viewer);
    g_autoptr(FlValue) result = fl_value_new_string("OK");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  } else if(strcmp(method, "resize") == 0) { 
      // val args = call.arguments as ArrayList<Int>
      // val width = args[0]
      // val height = args[1]
      // val scale = if(args.size > 2) (args[2] as Double).toFloat() else 1.0f
      // surfaceTexture!!.setDefaultBufferSize(width, height)
      // _lib.update_viewport_and_camera_projection(_viewer!!, width, height, scale);
      // result.success(null)
  } else if(strcmp(method, "render") == 0) {

    render(self->_viewer, 0);
    g_autoptr(FlValue) result = fl_value_new_string("OK");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  } else if(strcmp(method, "setBackgroundImage") == 0) {

    FlValue* args = fl_method_call_get_args(method_call);

    const gchar* path = fl_value_get_string(args);

    set_background_image(self->_viewer, path);
    
    g_autoptr(FlValue) result = fl_value_new_string("OK");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void polyvox_filament_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(polyvox_filament_plugin_parent_class)->dispose(object);
}

static void polyvox_filament_plugin_class_init(PolyvoxFilamentPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = polyvox_filament_plugin_dispose;
}

static void polyvox_filament_plugin_init(PolyvoxFilamentPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  PolyvoxFilamentPlugin* plugin = POLYVOX_FILAMENT_PLUGIN(user_data);
  polyvox_filament_plugin_handle_method_call(plugin, method_call);
}

void polyvox_filament_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  PolyvoxFilamentPlugin* plugin = POLYVOX_FILAMENT_PLUGIN(
      g_object_new(polyvox_filament_plugin_get_type(), nullptr));

  FlView* fl_view = fl_plugin_registrar_get_view(registrar);
  plugin->fl_view = fl_view;

  plugin->texture_registrar =
      fl_plugin_registrar_get_texture_registrar(registrar);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "app.polyvox.filament/event",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
