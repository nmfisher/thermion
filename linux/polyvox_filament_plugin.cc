#include "include/polyvox_filament/polyvox_filament_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <flutter_linux/fl_texture_registrar.h>
#include <flutter_linux/fl_texture_gl.h>
#include <gtk/gtk.h>
#include <gdk/gdk.h>
#include <thread>
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
#include "Log.hpp"

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
  double width;
  double height;
  bool rendering = false;
  bool resizing = false;
  void* viewer = nullptr;
};

G_DEFINE_TYPE(PolyvoxFilamentPlugin, polyvox_filament_plugin, g_object_get_type())

static gboolean on_frame_tick(GtkWidget* widget, GdkFrameClock* frame_clock, gpointer self) {
  PolyvoxFilamentPlugin* plugin = (PolyvoxFilamentPlugin*)self;
  
  if(plugin->rendering) {
    render(plugin->viewer, 0);
    fl_texture_registrar_mark_texture_frame_available(plugin->texture_registrar,
                                                        plugin->texture);
  }
  return TRUE; 
}

static FlMethodResponse* _create_texture(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
   if(self->texture) {
      Log("Error - create_texture called when texture exists.");
    } 

    FlValue* args = fl_method_call_get_args(method_call);

    const double width = fl_value_get_float(fl_value_get_list_value(args, 0));
    const double height = fl_value_get_float(fl_value_get_list_value(args, 1));

    self->width = width;
    self->height = height;

    auto texture = create_filament_texture(uint32_t(width), uint32_t(height), self->texture_registrar);
    //auto texture = create_filament_pb_texture(uint32_t(width), uint32_t(height), self->texture_registrar);
    self->texture = texture;

    g_autoptr(FlValue) result =   
         fl_value_new_int(reinterpret_cast<int64_t>(texture));   
    
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* _resize(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  
  const double width = fl_value_get_float(fl_value_get_list_value(args, 0));
  const double height = fl_value_get_float(fl_value_get_list_value(args, 1));

  destroy_filament_texture(self->texture, self->texture_registrar);

  self->texture = create_filament_texture(uint32_t(width), uint32_t(height), self->texture_registrar);
  
  g_autoptr(FlValue) result =   
         fl_value_new_int(reinterpret_cast<int64_t>(self->texture));   
      
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}


// Called when a method call is received from Flutter.
static void polyvox_filament_plugin_handle_method_call(
    PolyvoxFilamentPlugin* self,
    FlMethodCall* method_call) {

  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if(strcmp(method, "createTexture") == 0) {
    response = _create_texture(self, method_call);    
  } else if(strcmp(method, "resize") == 0) {
    response = _resize(self, method_call);
  } else if(strcmp(method, "getContext") == 0) {
    g_autoptr(FlValue) result =   
         fl_value_new_int(reinterpret_cast<int64_t>(glXGetCurrentContext()));   
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if(strcmp(method, "getGlTextureId") == 0) {
    g_autoptr(FlValue) result =   
         fl_value_new_int(reinterpret_cast<unsigned int>(((FilamentTextureGL*)self->texture)->texture_id));   
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if(strcmp(method, "getLoadResourceFn") == 0) {
    g_autoptr(FlValue) result =   
         fl_value_new_int(reinterpret_cast<int64_t>(loadResource));   
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if(strcmp(method, "getFreeResourceFn") == 0) {
    g_autoptr(FlValue) result =   
         fl_value_new_int(reinterpret_cast<int64_t>(&freeResource));   
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if(strcmp(method, "setRendering") == 0) {
    self->rendering =  fl_value_get_bool(fl_method_call_get_args(method_call));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string("OK")));
  } else if(strcmp(method, "tick") == 0) {        
    fl_texture_registrar_mark_texture_frame_available(self->texture_registrar,
                                                        self->texture);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string("OK")));
  } else if(strcmp(method, "setRenderTicker") == 0) {        
    if(self->viewer) {
      Log("Ticker has already been set, ignoring");
    } else {
      self->viewer = (void*)fl_value_get_int(fl_method_call_get_args(method_call));
      GtkWidget *w = gtk_widget_get_toplevel (GTK_WIDGET(self->fl_view));
      gtk_widget_add_tick_callback(w, on_frame_tick, self, NULL);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string("OK")));
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






// static FlMethodResponse* _loadSkybox(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);

//   const gchar* path = fl_value_get_string(args);

//   load_skybox(self->viewer, path);
                                       
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
// }

// static FlMethodResponse* _remove_ibl(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   remove_ibl(self->viewer);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
// }

// static FlMethodResponse* _loadIbl(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);

//   auto path = fl_value_get_string(fl_value_get_list_value(args, 0));
//   auto intensity = fl_value_get_float(fl_value_get_list_value(args, 1));

//   load_ibl(self->viewer, path, intensity);
                                       
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
// }

// static FlMethodResponse* _removeSkybox(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   std::cout << "Removing skybox" << std::endl;
//   remove_skybox(self->viewer);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_background_image(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 

//   FlValue* args = fl_method_call_get_args(method_call);

//   const gchar* path = fl_value_get_string(args);

//   set_background_image(self->viewer, path);
  
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_background_color(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 

//   const float* color = fl_value_get_float32_list(fl_method_call_get_args(method_call));
//   set_background_color(self->viewer, color[0], color[1], color[2], color[2]);
  
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _add_light(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 

//   FlValue* args = fl_method_call_get_args(method_call);
  
//   auto type = (uint8_t)fl_value_get_int(fl_value_get_list_value(args, 0));
//   auto color = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
//   auto intensity = float(fl_value_get_float(fl_value_get_list_value(args, 2)));
//   auto posX = (float)fl_value_get_float(fl_value_get_list_value(args, 3));
//   auto posY = (float)fl_value_get_float(fl_value_get_list_value(args, 4));
//   auto posZ = (float)fl_value_get_float(fl_value_get_list_value(args, 5));
//   auto dirX = (float)fl_value_get_float(fl_value_get_list_value(args, 6));
//   auto dirY = (float)fl_value_get_float(fl_value_get_list_value(args, 7));
//   auto dirZ = (float)fl_value_get_float(fl_value_get_list_value(args, 8));
//   auto shadows = fl_value_get_bool(fl_value_get_list_value(args, 9));

//   auto entityId = add_light(self->viewer, type, color, intensity, posX, posY, posZ, dirX, dirY, dirZ, shadows);
//   g_autoptr(FlValue) result = fl_value_new_int(entityId);
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    

// }

// static FlMethodResponse* _load_glb(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//     FlValue* args = fl_method_call_get_args(method_call);
//     auto path = fl_value_get_string(fl_value_get_list_value(args, 0));
//     auto unlit = fl_value_get_bool(fl_value_get_list_value(args, 1));
//     auto entityId = load_glb(self->viewer, path, unlit);
//     g_autoptr(FlValue) result = fl_value_new_int((int64_t)entityId);
//     return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _get_animation_names(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
  
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(args);
//   g_autoptr(FlValue) result = fl_value_new_list();

//   auto numNames = get_animation_count(assetPtr);

//   for(int i = 0; i < numNames; i++) {
//     gchar out[255];
//     get_animation_name(assetPtr, out, i);
//     fl_value_append_take (result, fl_value_new_string (out));
//   }
      
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _remove_asset(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(args);
//   remove_asset(self->viewer, assetPtr);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _transform_to_unit_cube(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(args);
//   transform_to_unit_cube(assetPtr);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _rotate_start(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
  
//   auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
//   auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));

//   grab_begin(self->viewer, x,y, false);

//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _rotate_end(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   grab_end(self->viewer);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _rotate_update(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
//   auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));

//   grab_update(self->viewer, x,y);

//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _pan_start(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 

//   FlValue* args = fl_method_call_get_args(method_call);

//   auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
//   auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));

//   grab_begin(self->viewer, x,y, true);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _pan_update(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
//   auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));

//   grab_update(self->viewer, x,y);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _pan_end(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   grab_end(self->viewer);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_position(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));

//   set_position(
//     assetPtr, 
//     (float)fl_value_get_float(fl_value_get_list_value(args, 1)), // x
//     (float)fl_value_get_float(fl_value_get_list_value(args, 2)), // y
//     (float)fl_value_get_float(fl_value_get_list_value(args, 3)) // z
//   );
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_rotation(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));

//   set_rotation(
//     assetPtr, 
//     (float)fl_value_get_float(fl_value_get_list_value(args, 1)), // rads
//     (float)fl_value_get_float(fl_value_get_list_value(args, 2)), // x
//     (float)fl_value_get_float(fl_value_get_list_value(args, 3)), // y
//     (float)fl_value_get_float(fl_value_get_list_value(args, 4)) // z
//   );
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }



// static FlMethodResponse* _set_bone_transform(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
//   auto boneName = fl_value_get_string(fl_value_get_list_value(args, 1));
//   auto meshName = fl_value_get_string(fl_value_get_list_value(args, 2));

//   set_bone_transform(
//     assetPtr, 
//     boneName,
//     meshName,
//     (float)fl_value_get_float(fl_value_get_list_value(args, 3)), // transX
//     (float)fl_value_get_float(fl_value_get_list_value(args, 4)), // transY
//     (float)fl_value_get_float(fl_value_get_list_value(args, 5)), // transZ
//     (float)fl_value_get_float(fl_value_get_list_value(args, 6)), // quatX
//     (float)fl_value_get_float(fl_value_get_list_value(args, 7)), // quatY
//     (float)fl_value_get_float(fl_value_get_list_value(args, 8)), // quatZ
//     (float)fl_value_get_float(fl_value_get_list_value(args, 9)) // quatW
//   );
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_camera(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
//   auto cameraName = fl_value_get_string(fl_value_get_list_value(args, 1)) ;
  
//   set_camera(self->viewer, (void*)assetPtr, cameraName);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_camera_model_matrix(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   set_camera_model_matrix(self->viewer, fl_value_get_float32_list(args));
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_camera_exposure(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto aperture = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
//   auto shutter_speed = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
//   auto sensitivity = (float)fl_value_get_float(fl_value_get_list_value(args, 2));
//   set_camera_exposure(self->viewer, aperture, shutter_speed, sensitivity);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_camera_position(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
//   auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
//   auto z = (float)fl_value_get_float(fl_value_get_list_value(args, 2));
//   set_camera_position(self->viewer, x,y, z);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_camera_rotation(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto rads = (float)fl_value_get_float(fl_value_get_list_value(args,0 ));
//   auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
//   auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 2));
//   auto z = (float)fl_value_get_float(fl_value_get_list_value(args, 3));
  
//   set_camera_rotation(self->viewer, rads, x,y, z);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_rendering(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   self->rendering = (bool)fl_value_get_bool(args);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_frame_interval(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto val = (float) fl_value_get_float(args);
//   set_frame_interval(self->viewer, val);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _zoom_begin(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   scroll_begin(self->viewer);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _zoom_end(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   scroll_end(self->viewer);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _zoom_update(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
//   auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
//   auto z = (float)fl_value_get_float(fl_value_get_list_value(args, 2));
  
//   scroll_update(self->viewer, x,y, z);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _play_animation(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
//   auto animationId = (int)fl_value_get_int(fl_value_get_list_value(args, 1));  
//   auto loop = (bool)fl_value_get_bool(fl_value_get_list_value(args, 2));  
//   auto reverse = (bool)fl_value_get_bool(fl_value_get_list_value(args, 3));  
//   play_animation(assetPtr, animationId, loop, reverse);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }


// static FlMethodResponse* _stop_animation(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
//   auto animationId = (int)fl_value_get_int(fl_value_get_list_value(args, 1));  
//   stop_animation(assetPtr, animationId);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _apply_weights(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
//   auto entityName = fl_value_get_string(fl_value_get_list_value(args, 1));
//   auto weightsValue = fl_value_get_list_value(args, 2);
//   float* const weights = (float* const) fl_value_get_float32_list(weightsValue);  
//   size_t len = fl_value_get_length(weightsValue);
//   apply_weights(assetPtr, entityName, weights, (int)len);
//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _set_animation(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));

//   const char* entityName = fl_value_get_string(fl_value_get_list_value(args, 1));  
  
//   float* const morphData = (float* const) fl_value_get_float32_list(fl_value_get_list_value(args, 2));  
  
//   int64_t numMorphWeights = fl_value_get_int(fl_value_get_list_value(args, 3));

//   FlValue* flBoneAnimations = fl_value_get_list_value(args, 4);

//   size_t numBoneAnimations = fl_value_get_length(flBoneAnimations);

//   vector<BoneAnimation> boneAnimations;

//   for(int i = 0; i < numBoneAnimations; i++) {  
    
//     FlValue* flBoneAnimation = fl_value_get_list_value(flBoneAnimations, i);

//     FlValue* flBoneNames = fl_value_get_list_value(flBoneAnimation, 0);  
//     FlValue* flMeshNames = fl_value_get_list_value(flBoneAnimation, 1);  
//     float* const frameData = (float* const) fl_value_get_float32_list(fl_value_get_list_value(flBoneAnimation, 2));  

//     Log("Framedata %f", frameData);

//     vector<const char*> boneNames;
//     boneNames.resize(fl_value_get_length(flBoneNames));

//     for(int i=0; i < boneNames.size(); i++) {
//       boneNames[i] = fl_value_get_string(fl_value_get_list_value(flBoneNames, i)) ;
//     }

//     vector<const char*> meshNames;
//     meshNames.resize(fl_value_get_length(flMeshNames));
//     for(int i=0; i < meshNames.size(); i++) {
//       meshNames[i] = fl_value_get_string(fl_value_get_list_value(flMeshNames, i));
//     }
  
//     const char** boneNamesPtr = (const char**)malloc(boneNames.size() * sizeof(char*));
//     memcpy((void*)boneNamesPtr, (void*)boneNames.data(), boneNames.size() * sizeof(char*));
//     auto meshNamesPtr = (const char**)malloc(meshNames.size() * sizeof(char*));
//     memcpy((void*)meshNamesPtr, (void*)meshNames.data(), meshNames.size() * sizeof(char*));

//     BoneAnimation animation {
//       .boneNames = boneNamesPtr,
//       .meshNames = meshNamesPtr,
//       .data = frameData,
//       .numBones = boneNames.size(),
//       .numMeshTargets = meshNames.size()
//     };

//     boneAnimations.push_back(animation);

//   }

//   int64_t numFrames = fl_value_get_int(fl_value_get_list_value(args, 5));
  
//   float frameLengthInMs = fl_value_get_float(fl_value_get_list_value(args, 6));

//   auto boneAnimationsPointer = boneAnimations.data();
//   auto boneAnimationsSize = boneAnimations.size();
  
//   set_animation(
//     assetPtr, 
//     entityName,
//     morphData, 
//     numMorphWeights, 
//     boneAnimationsPointer,
//     boneAnimationsSize,
//     numFrames, 
//     frameLengthInMs);

//   g_autoptr(FlValue) result = fl_value_new_string("OK");
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

// static FlMethodResponse* _get_morph_target_names(PolyvoxFilamentPlugin* self, FlMethodCall* method_call) { 
//   FlValue* args = fl_method_call_get_args(method_call);
//   auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
//   auto meshName = fl_value_get_string(fl_value_get_list_value(args, 1));
//   g_autoptr(FlValue) result = fl_value_new_list();

//   auto numNames = get_morph_target_name_count(assetPtr, meshName);

//   std::cout << numNames << " morph targets found in mesh " << meshName << std::endl;

//   for(int i = 0; i < numNames; i++) {
//     gchar out[255];
//     get_morph_target_name(assetPtr, meshName, out, i);
//     fl_value_append_take (result, fl_value_new_string (out));
//   }
      
//   return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
// }

  // } else if(strcmp(method, "loadSkybox") == 0) {
  //   response = _loadSkybox(self, method_call);
  // } else if(strcmp(method, "loadIbl") == 0) {
  //   response = _loadIbl(self, method_call);
  // } else if(strcmp(method, "removeIbl") ==0) { 
  //   response = _remove_ibl(self, method_call);
  // } else if(strcmp(method, "removeSkybox") == 0) {
  //   response = _removeSkybox(self, method_call);    
  
  // } else if(strcmp(method, "render") == 0) {
  //   render(self->viewer, 0);
  //   g_autoptr(FlValue) result = fl_value_new_string("OK");
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  // } else if(strcmp(method, "setBackgroundColor") == 0) {
  //   response = _set_background_color(self, method_call);
  // } else if(strcmp(method, "setBackgroundImage") == 0) {
  //   response = _set_background_image(self, method_call);
  // } else if(strcmp(method, "addLight") == 0) {
  //   response = _add_light(self, method_call);  
  // } else if(strcmp(method, "loadGlb") == 0) {
  //   response = _load_glb(self, method_call);
  // } else if(strcmp(method, "getAnimationNames") == 0) {
  //   response = _get_animation_names(self, method_call);
  // } else if(strcmp(method, "clearAssets") == 0) {
  //   clear_assets(self->viewer);
  //   g_autoptr(FlValue) result = fl_value_new_string("OK");
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  // } else if(strcmp(method, "removeAsset") == 0) {
  //   response = _remove_asset(self, method_call);
  // } else if(strcmp(method, "transformToUnitCube") == 0) {
  //   response = _transform_to_unit_cube(self, method_call);
  // } else if(strcmp(method, "clearLights") == 0) {
  //   clear_lights(self->viewer);
  //   g_autoptr(FlValue) result = fl_value_new_string("OK");
  //   response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  // } else if(strcmp(method, "panStart") == 0) {
  //   response = _pan_start(self, method_call);
  // } else if(strcmp(method, "panEnd") == 0) {
  //   response = _pan_end(self, method_call);
  // } else if(strcmp(method, "panUpdate") == 0) {
  //   response = _pan_update(self, method_call);
  // } else if(strcmp(method, "rotateStart") == 0) {
  //   response = _rotate_start(self, method_call);
  // } else if(strcmp(method, "rotateEnd") == 0) {
  //   response = _rotate_end(self, method_call);
  // } else if(strcmp(method, "rotateUpdate") == 0) {
  //   response = _rotate_update(self, method_call);
  // } else if(strcmp(method, "setRotation") == 0) {
  //   response = _set_rotation(self, method_call);
  // } else if(strcmp(method, "setCamera") == 0) {
  //   response = _set_camera(self, method_call);
  // } else if(strcmp(method, "setCameraModelMatrix") == 0) {
  //   response = _set_camera_model_matrix(self, method_call);
  // } else if(strcmp(method, "setCameraExposure") == 0) {
  //   response = _set_camera_exposure(self, method_call);
  // } else if(strcmp(method, "setCameraPosition") == 0) {
  //   response = _set_camera_position(self, method_call);
  // } else if(strcmp(method, "setCameraRotation") == 0) {
  //   response = _set_camera_rotation(self, method_call);
  
  // } else if(strcmp(method, "setFrameInterval") == 0) {
  //   response = _set_frame_interval(self, method_call);
  // } else if(strcmp(method, "zoomBegin") == 0) {
  //   response = _zoom_begin(self, method_call);
  // } else if(strcmp(method, "zoomEnd") == 0) {
  //   response = _zoom_end(self, method_call);
  // } else if(strcmp(method, "zoomUpdate") == 0) {
  //   response = _zoom_update(self, method_call);
  // } else if(strcmp(method, "playAnimation") == 0) {
  //   response = _play_animation(self, method_call);
  // } else if(strcmp(method, "stopAnimation") == 0) {
  //   response = _stop_animation(self, method_call);
  // } else if(strcmp(method, "setMorphTargetWeights") == 0) {
  //   response = _apply_weights(self, method_call);
  // } else if(strcmp(method, "setAnimation") == 0) {
  //   response = _set_animation(self, method_call);
  // } else if(strcmp(method, "getMorphTargetNames") == 0) {
  //   response = _get_morph_target_names(self, method_call);
  // } else if(strcmp(method, "setPosition") == 0) {
  //   response = _set_position(self, method_call);
  // } else if(strcmp(method, "setBoneTransform") == 0) {
  //   // response = _set_bone_transform(self, method_call);