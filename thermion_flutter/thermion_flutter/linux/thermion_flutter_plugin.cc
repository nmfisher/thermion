#include "include/thermion_flutter/thermion_flutter_plugin.h"

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

#include "include/thermion_flutter/filament_texture.h"
#include "include/thermion_flutter/filament_pb_texture.h"
#include "include/thermion_flutter/resource_loader.hpp"

#include "ThermionDartApi.h"
#include "Log.hpp"

extern "C" {
#include "ThermionFlutterApi.h"
}

#include <epoxy/gl.h>
#include <epoxy/glx.h>

#define FLUTTER_FILAMENT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), thermion_flutter_plugin_get_type(), \
                              ThermionFlutterPlugin))


struct _ThermionFlutterPlugin {
  GObject parent_instance;
  FlTextureRegistrar* texture_registrar;
  FlView* fl_view;
  FlTexture* texture;
  double width = 0;
  double height = 0;
  bool rendering = false;
  thermion_flutter::ThermionViewerFFI* viewer;
};

G_DEFINE_TYPE(ThermionFlutterPlugin, thermion_flutter_plugin, g_object_get_type())

static gboolean on_frame_tick(GtkWidget* widget, GdkFrameClock* frame_clock, gpointer self) {
  ThermionFlutterPlugin* plugin = (ThermionFlutterPlugin*)self;
  
 if(plugin->rendering) {
    render(plugin->viewer, 0);
    fl_texture_registrar_mark_texture_frame_available(plugin->texture_registrar,
                                                        plugin->texture);
  }
  return TRUE; 
}

static FlMethodResponse* _create_filament_viewer(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  auto callback = new ResourceLoaderWrapper(loadResource, freeResource);

  FlValue* args = fl_method_call_get_args(method_call);

  const double width = fl_value_get_float(fl_value_get_list_value(args, 0));
  const double height = fl_value_get_float(fl_value_get_list_value(args, 1));

  self->width = width;
  self->height = height;

  auto context = glXGetCurrentContext();   
  self->viewer = (thermion_flutter::ThermionViewerFFI*)create_filament_viewer(
    (void*)context,
    callback
  );

  GtkWidget *w = gtk_widget_get_toplevel (GTK_WIDGET(self->fl_view));
  gtk_widget_add_tick_callback(w, on_frame_tick, self,NULL);

  // don't pass a surface to the SwapChain as we are effectively creating a headless SwapChain that will render into a RenderTarget associated with a texture
  create_swap_chain(self->viewer, nullptr, width, height);
  create_render_target(self->viewer, ((FilamentTextureGL*)self->texture)->texture_id,width,height);   
  update_viewport_and_camera_projection(self->viewer, width, height, 1.0f); 

  g_autoptr(FlValue) result =   
         fl_value_new_int(reinterpret_cast<int64_t>(self->viewer));   
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* _create_texture(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
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

    Log("Successfully created texture.");
    
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}


static FlMethodResponse* _update_viewport_and_camera_projection(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
    FlValue* args = fl_method_call_get_args(method_call);

    auto width = fl_value_get_int(fl_value_get_list_value(args, 0));
    auto height = fl_value_get_int(fl_value_get_list_value(args, 1));
    auto scaleFactor = fl_value_get_float(fl_value_get_list_value(args, 2));

    update_viewport_and_camera_projection(self->viewer, width, height, scaleFactor);
    
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));
}


static FlMethodResponse* _get_asset_manager(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
    auto assetManager = get_asset_manager(self->viewer);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int(reinterpret_cast<int64_t>(assetManager))));
}

static FlMethodResponse* _resize(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  
  const double width = fl_value_get_float(fl_value_get_list_value(args, 0));
  const double height = fl_value_get_float(fl_value_get_list_value(args, 1));

  destroy_filament_texture(self->texture, self->texture_registrar);

  self->texture = create_filament_texture(uint32_t(width), uint32_t(height), self->texture_registrar);

  create_swap_chain(self->viewer, nullptr, width, height);
  create_render_target(self->viewer, ((FilamentTextureGL*)self->texture)->texture_id,width,height);

  update_viewport_and_camera_projection(self->viewer, width, height, 1.0f);
  
  g_autoptr(FlValue) result =   
         fl_value_new_int(reinterpret_cast<int64_t>(self->texture));   
      
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _loadSkybox(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);

  const gchar* path = fl_value_get_string(args);

  load_skybox(self->viewer, path);
                                       
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* _remove_ibl(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  remove_ibl(self->viewer);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* _loadIbl(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);

  auto path = fl_value_get_string(fl_value_get_list_value(args, 0));
  auto intensity = fl_value_get_float(fl_value_get_list_value(args, 1));

  load_ibl(self->viewer, path, intensity);
                                       
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* _removeSkybox(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  std::cout << "Removing skybox" << std::endl;
  remove_skybox(self->viewer);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_background_image(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 

  FlValue* args = fl_method_call_get_args(method_call);

  const gchar* path = fl_value_get_string(args);

  set_background_image(self->viewer, path);
  
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_background_color(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  const float r = fl_value_get_float(fl_value_get_list_value(args, 0));
  const float g = fl_value_get_float(fl_value_get_list_value(args, 1));
  const float b = fl_value_get_float(fl_value_get_list_value(args, 2));
  const float a = fl_value_get_float(fl_value_get_list_value(args, 3));
  set_background_color(self->viewer, r,g,b,a);
  
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _add_light(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 

  FlValue* args = fl_method_call_get_args(method_call);
  
  auto type = (uint8_t)fl_value_get_int(fl_value_get_list_value(args, 0));
  auto color = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
  auto intensity = float(fl_value_get_float(fl_value_get_list_value(args, 2)));
  auto posX = (float)fl_value_get_float(fl_value_get_list_value(args, 3));
  auto posY = (float)fl_value_get_float(fl_value_get_list_value(args, 4));
  auto posZ = (float)fl_value_get_float(fl_value_get_list_value(args, 5));
  auto dirX = (float)fl_value_get_float(fl_value_get_list_value(args, 6));
  auto dirY = (float)fl_value_get_float(fl_value_get_list_value(args, 7));
  auto dirZ = (float)fl_value_get_float(fl_value_get_list_value(args, 8));
  auto shadows = fl_value_get_bool(fl_value_get_list_value(args, 9));

  auto entityId = add_light(self->viewer, type, color, intensity, posX, posY, posZ, dirX, dirY, dirZ, shadows);
  g_autoptr(FlValue) result = fl_value_new_int(entityId);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    

}

static FlMethodResponse* _load_glb(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
    FlValue* args = fl_method_call_get_args(method_call);
    auto assetManager = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
    auto path = fl_value_get_string(fl_value_get_list_value(args, 1));
    auto unlit = fl_value_get_bool(fl_value_get_list_value(args, 2));
    auto entityId = load_glb(assetManager, path, unlit);
    g_autoptr(FlValue) result = fl_value_new_int((int64_t)entityId);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _get_animation_names(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  
  FlValue* args = fl_method_call_get_args(method_call);
  auto assetManager = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 1));
  g_autoptr(FlValue) result = fl_value_new_list();

  auto numNames = get_animation_count(assetManager, asset);

  for(int i = 0; i < numNames; i++) {
    gchar out[255];
    get_animation_name(assetManager, asset, out, i);
    fl_value_append_take (result, fl_value_new_string (out));
  }
      
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _remove_asset(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 1));
  remove_asset(self->viewer, asset);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _transform_to_unit_cube(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto assetManager = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 1));
  transform_to_unit_cube(assetManager, asset);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _rotate_start(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  
  auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
  auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));

  grab_begin(self->viewer, x,y, false);

  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _rotate_end(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  grab_end(self->viewer);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _rotate_update(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
  auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));

  grab_update(self->viewer, x,y);

  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _pan_start(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 

  FlValue* args = fl_method_call_get_args(method_call);

  auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
  auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));

  grab_begin(self->viewer, x,y, true);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _pan_update(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
  auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));

  grab_update(self->viewer, x,y);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _pan_end(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  grab_end(self->viewer);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_position(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto assetManager = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 1));

  set_position(
    assetManager,
    asset, 
    (float)fl_value_get_float(fl_value_get_list_value(args, 2)), // x
    (float)fl_value_get_float(fl_value_get_list_value(args, 3)), // y
    (float)fl_value_get_float(fl_value_get_list_value(args, 4)) // z
  );
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_rotation(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto assetManager = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));

  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 1));

  set_rotation(
    assetManager,
    asset, 
    (float)fl_value_get_float(fl_value_get_list_value(args, 2)), // rads
    (float)fl_value_get_float(fl_value_get_list_value(args, 3)), // x
    (float)fl_value_get_float(fl_value_get_list_value(args, 4)), // y
  (float)fl_value_get_float(fl_value_get_list_value(args, 5 )) // z
  );
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}



static FlMethodResponse* _set_bone_transform(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
   throw std::invalid_argument( "received negative value" );
  // FlValue* args = fl_method_call_get_args(method_call);
  // auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
  // auto boneName = fl_value_get_string(fl_value_get_list_value(args, 1));
  // auto meshName = fl_value_get_string(fl_value_get_list_value(args, 2));

  // set_bone_transform(
  //   assetPtr, 
  //   boneName,
  //   meshName,
  //   (float)fl_value_get_float(fl_value_get_list_value(args, 3)), // transX
  //   (float)fl_value_get_float(fl_value_get_list_value(args, 4)), // transY
  //   (float)fl_value_get_float(fl_value_get_list_value(args, 5)), // transZ
  //   (float)fl_value_get_float(fl_value_get_list_value(args, 6)), // quatX
  //   (float)fl_value_get_float(fl_value_get_list_value(args, 7)), // quatY
  //   (float)fl_value_get_float(fl_value_get_list_value(args, 8)), // quatZ
  //   (float)fl_value_get_float(fl_value_get_list_value(args, 9)) // quatW
  // );
  // g_autoptr(FlValue) result = fl_value_new_string("OK");
  // return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_camera(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 0));
  auto cameraName = fl_value_get_string(fl_value_get_list_value(args, 1)) ;
  
  set_camera(self->viewer, asset, cameraName);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_camera_model_matrix(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  set_camera_model_matrix(self->viewer, fl_value_get_float32_list(args));
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_camera_exposure(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto aperture = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
  auto shutter_speed = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
  auto sensitivity = (float)fl_value_get_float(fl_value_get_list_value(args, 2));
  set_camera_exposure(self->viewer, aperture, shutter_speed, sensitivity);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_camera_position(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
  auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
  auto z = (float)fl_value_get_float(fl_value_get_list_value(args, 2));
  set_camera_position(self->viewer, x,y, z);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_camera_rotation(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto rads = (float)fl_value_get_float(fl_value_get_list_value(args,0 ));
  auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
  auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 2));
  auto z = (float)fl_value_get_float(fl_value_get_list_value(args, 3));
  
  set_camera_rotation(self->viewer, rads, x,y, z);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_rendering(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  self->rendering = (bool)fl_value_get_bool(args);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_frame_interval(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto val = (float) fl_value_get_float(args);
  set_frame_interval(self->viewer, val);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _grab_begin(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
  auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
  auto pan = (bool)fl_value_get_bool(fl_value_get_list_value(args, 2));
  grab_begin(self->viewer, x, y, pan);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _grab_end(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  grab_end(self->viewer);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _grab_update(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
  auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
  
  grab_update(self->viewer, x,y);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _scroll_begin(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  scroll_begin(self->viewer);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _scroll_end(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  scroll_end(self->viewer);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _scroll_update(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto x = (float)fl_value_get_float(fl_value_get_list_value(args, 0));
  auto y = (float)fl_value_get_float(fl_value_get_list_value(args, 1));
  auto z = (float)fl_value_get_float(fl_value_get_list_value(args, 2));
  
  scroll_update(self->viewer, x,y, z);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _play_animation(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto assetManager = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 1));
  auto animationId = (int)fl_value_get_int(fl_value_get_list_value(args, 2));  
  auto loop = (bool)fl_value_get_bool(fl_value_get_list_value(args, 3));  
  auto reverse = (bool)fl_value_get_bool(fl_value_get_list_value(args, 4));  
  auto replaceActive = (bool)fl_value_get_bool(fl_value_get_list_value(args, 5));  
  auto crossfade = (bool)fl_value_get_float(fl_value_get_list_value(args, 6));  
  play_animation(assetManager, asset, animationId, loop, reverse, replaceActive, crossfade);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}


static FlMethodResponse* _stop_animation(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto assetManager = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 1));
  auto animationId = (int)fl_value_get_int(fl_value_get_list_value(args, 2));  
  stop_animation(assetManager, asset, animationId);
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}


static FlMethodResponse* _set_morph_target_weights(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto assetManager = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 1));
  auto entityName = fl_value_get_string(fl_value_get_list_value(args, 2));
  auto flWeights = fl_value_get_list_value(args, 3);
  size_t numWeights = fl_value_get_length(flWeights);

  std::vector<float> weights(numWeights);
  for(int i =0; i < numWeights; i++) {
      float val = fl_value_get_float(fl_value_get_list_value(flWeights, i));
      weights[i] = val;
  }
    
  set_morph_target_weights(assetManager, asset, entityName, weights.data(), (int)numWeights);
  
  g_autoptr(FlValue) result = fl_value_new_string("OK");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

template class std::vector<int>;

static FlMethodResponse* _set_morph_animation(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto assetManager = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 1));
  auto entityName = fl_value_get_string(fl_value_get_list_value(args, 2));
  
  auto morphDataList = fl_value_get_list_value(args, 3);
  auto morphDataListLength = fl_value_get_length(morphDataList);
  auto morphData = std::vector<float>(morphDataListLength);
  
  for(int i =0; i < morphDataListLength; i++) {
    morphData[i] = fl_value_get_float(fl_value_get_list_value(morphDataList, i));
  }

  auto morphIndicesList = fl_value_get_list_value(args, 4);
  auto morphIndicesListLength =  fl_value_get_length(morphIndicesList);
  auto indices = std::vector<int32_t>(morphIndicesListLength);
  
  for(int i =0; i < morphIndicesListLength; i++) {
    FlValue* flMorphIndex = fl_value_get_list_value(morphIndicesList, i);
    indices[i] = static_cast<int32_t>(fl_value_get_int(flMorphIndex));
  }
  
  int64_t numMorphTargets = fl_value_get_int(fl_value_get_list_value(args, 5));
  int64_t numFrames = fl_value_get_int(fl_value_get_list_value(args, 6));
  float frameLengthInMs = fl_value_get_float(fl_value_get_list_value(args, 7));

  bool success = set_morph_animation(
      assetManager, 
      asset, 
      (const char *const)entityName, 
      (const float *const)morphData.data(), 
      (const int* const)indices.data(), 
      static_cast<int>(numMorphTargets), 
      static_cast<int>(numFrames), 
      frameLengthInMs
  );  
  g_autoptr(FlValue) result = fl_value_new_bool(success);

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_animation(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
   throw std::invalid_argument( "received negative value" );
  // FlValue* args = fl_method_call_get_args(method_call);
  // auto assetPtr = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));

  // const char* entityName = fl_value_get_string(fl_value_get_list_value(args, 1));  
  
  // float* const morphData = (float* const) fl_value_get_float32_list(fl_value_get_list_value(args, 2));  
  
  // int64_t numMorphWeights = fl_value_get_int(fl_value_get_list_value(args, 3));

  // FlValue* flBoneAnimations = fl_value_get_list_value(args, 4);

  // size_t numBoneAnimations = fl_value_get_length(flBoneAnimations);

  // vector<BoneAnimation> boneAnimations;

  // for(int i = 0; i < numBoneAnimations; i++) {  
    
  //   FlValue* flBoneAnimation = fl_value_get_list_value(flBoneAnimations, i);

  //   FlValue* flBoneNames = fl_value_get_list_value(flBoneAnimation, 0);  
  //   FlValue* flMeshNames = fl_value_get_list_value(flBoneAnimation, 1);  
  //   float* const frameData = (float* const) fl_value_get_float32_list(fl_value_get_list_value(flBoneAnimation, 2));  

  //   Log("Framedata %f", frameData);

  //   vector<const char*> boneNames;
  //   boneNames.resize(fl_value_get_length(flBoneNames));

  //   for(int i=0; i < boneNames.size(); i++) {
  //     boneNames[i] = fl_value_get_string(fl_value_get_list_value(flBoneNames, i)) ;
  //   }

  //   vector<const char*> meshNames;
  //   meshNames.resize(fl_value_get_length(flMeshNames));
  //   for(int i=0; i < meshNames.size(); i++) {
  //     meshNames[i] = fl_value_get_string(fl_value_get_list_value(flMeshNames, i));
  //   }
  
  //   const char** boneNamesPtr = (const char**)malloc(boneNames.size() * sizeof(char*));
  //   memcpy((void*)boneNamesPtr, (void*)boneNames.data(), boneNames.size() * sizeof(char*));
  //   auto meshNamesPtr = (const char**)malloc(meshNames.size() * sizeof(char*));
  //   memcpy((void*)meshNamesPtr, (void*)meshNames.data(), meshNames.size() * sizeof(char*));

  //   BoneAnimation animation {
  //     .boneNames = boneNamesPtr,
  //     .meshNames = meshNamesPtr,
  //     .data = frameData,
  //     .numBones = boneNames.size(),
  //     .numMeshTargets = meshNames.size()
  //   };

  //   boneAnimations.push_back(animation);

  // }

  // int64_t numFrames = fl_value_get_int(fl_value_get_list_value(args, 5));
  
  // float frameLengthInMs = fl_value_get_float(fl_value_get_list_value(args, 6));

  // auto boneAnimationsPointer = boneAnimations.data();
  // auto boneAnimationsSize = boneAnimations.size();
  
  // set_animation(
  //   assetPtr, 
  //   entityName,
  //   morphData, 
  //   numMorphWeights, 
  //   boneAnimationsPointer,
  //   boneAnimationsSize,
  //   numFrames, 
  //   frameLengthInMs);

  // g_autoptr(FlValue) result = fl_value_new_string("OK");
  // return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _get_morph_target_names(ThermionFlutterPlugin* self, FlMethodCall* method_call) { 
  FlValue* args = fl_method_call_get_args(method_call);
  auto assetManager = (void*)fl_value_get_int(fl_value_get_list_value(args, 0));
  auto asset = (EntityId)fl_value_get_int(fl_value_get_list_value(args, 1));
  auto meshName = fl_value_get_string(fl_value_get_list_value(args, 2));
  
  g_autoptr(FlValue) result = fl_value_new_list();

  auto numNames = get_morph_target_name_count(assetManager, asset, meshName);

  for(int i = 0; i < numNames; i++) {
    gchar out[255];
    get_morph_target_name(assetManager, asset, meshName, out, i);
    fl_value_append_take (result, fl_value_new_string (out));
  }
      
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
}

static FlMethodResponse* _set_tone_mapping(ThermionFlutterPlugin* self, FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  thermion_flutter::ToneMapping toneMapping = static_cast<thermion_flutter::ToneMapping>(fl_value_get_int(args)); 
  set_tone_mapping(self->viewer, toneMapping);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));      
}

static FlMethodResponse* _set_bloom(ThermionFlutterPlugin* self, FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  set_bloom(self->viewer, fl_value_get_float(args));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));      
}

// Called when a method call is received from Flutter.
static void thermion_flutter_plugin_handle_method_call(
    ThermionFlutterPlugin* self,
    FlMethodCall* method_call) {

  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if(strcmp(method, "createThermionViewerFFI") == 0) {
    response = _create_filament_viewer(self, method_call);
  } else if(strcmp(method, "createTexture") == 0) {
    response = _create_texture(self, method_call);    
  } else if(strcmp(method, "updateViewportAndCameraProjection")==0){ 
    response = _update_viewport_and_camera_projection(self, method_call);
  } else if(strcmp(method, "getAssetManager") ==0){ 
    response = _get_asset_manager(self, method_call);
  } else if(strcmp(method, "setToneMapping") == 0) {
    response = _set_tone_mapping(self, method_call);
  } else if(strcmp(method, "setBloom") == 0) {
    response = _set_bloom(self, method_call);
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
  } else if(strcmp(method, "getResourceLoader") == 0) {
    ResourceLoaderWrapper* resourceLoader = new ResourceLoaderWrapper(loadResource, freeResource);
    g_autoptr(FlValue) result =   
         fl_value_new_int(reinterpret_cast<int64_t>(resourceLoader));   
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if(strcmp(method, "setRendering") == 0) {
    self->rendering =  fl_value_get_bool(fl_method_call_get_args(method_call));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string("OK")));
  } else if(strcmp(method, "loadSkybox") == 0) {
    response = _loadSkybox(self, method_call);
  } else if(strcmp(method, "loadIbl") == 0) {
    response = _loadIbl(self, method_call);
  } else if(strcmp(method, "removeIbl") ==0) { 
    response = _remove_ibl(self, method_call);
  } else if(strcmp(method, "removeSkybox") == 0) {
    response = _removeSkybox(self, method_call);    
  } else if(strcmp(method, "render") == 0) {
    render(self->viewer, 0);
    g_autoptr(FlValue) result = fl_value_new_string("OK");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  } else if(strcmp(method, "setBackgroundColor") == 0) {
    response = _set_background_color(self, method_call);
  } else if(strcmp(method, "setBackgroundImage") == 0) {
    response = _set_background_image(self, method_call);
  } else if(strcmp(method, "addLight") == 0) {
    response = _add_light(self, method_call);  
  } else if(strcmp(method, "loadGlb") == 0) {
    response = _load_glb(self, method_call);
  } else if(strcmp(method, "getAnimationNames") == 0) {
    response = _get_animation_names(self, method_call);
  } else if(strcmp(method, "clearAssets") == 0) {
    clear_assets(self->viewer);
    g_autoptr(FlValue) result = fl_value_new_string("OK");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  } else if(strcmp(method, "removeAsset") == 0) {
    response = _remove_asset(self, method_call);
  } else if(strcmp(method, "transformToUnitCube") == 0) {
    response = _transform_to_unit_cube(self, method_call);
  } else if(strcmp(method, "clearLights") == 0) {
    clear_lights(self->viewer);
    g_autoptr(FlValue) result = fl_value_new_string("OK");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));    
  } else if(strcmp(method, "panStart") == 0) {
    response = _pan_start(self, method_call);
  } else if(strcmp(method, "panEnd") == 0) {
    response = _pan_end(self, method_call);
  } else if(strcmp(method, "panUpdate") == 0) {
    response = _pan_update(self, method_call);
  } else if(strcmp(method, "rotateStart") == 0) {
    response = _rotate_start(self, method_call);
  } else if(strcmp(method, "rotateEnd") == 0) {
    response = _rotate_end(self, method_call);
  } else if(strcmp(method, "rotateUpdate") == 0) {
    response = _rotate_update(self, method_call);
  } else if(strcmp(method, "setRotation") == 0) {
    response = _set_rotation(self, method_call);
  } else if(strcmp(method, "setCamera") == 0) {
    response = _set_camera(self, method_call);
  } else if(strcmp(method, "setCameraModelMatrix") == 0) {
    response = _set_camera_model_matrix(self, method_call);
  } else if(strcmp(method, "setCameraExposure") == 0) {
    response = _set_camera_exposure(self, method_call);
  } else if(strcmp(method, "setCameraPosition") == 0) {
    response = _set_camera_position(self, method_call);
  } else if(strcmp(method, "setCameraRotation") == 0) {
    response = _set_camera_rotation(self, method_call);
  } else if(strcmp(method, "setFrameInterval") == 0) {
    response = _set_frame_interval(self, method_call);
  } else if(strcmp(method, "scrollBegin") == 0) {
    response = _scroll_begin(self, method_call);
  } else if(strcmp(method, "scrollEnd") == 0) {
    response = _scroll_end(self, method_call);
  } else if(strcmp(method, "scrollUpdate") == 0) {
    response = _scroll_update(self, method_call);
  } else if(strcmp(method, "grabBegin") == 0) {
    response = _grab_begin(self, method_call);
  } else if(strcmp(method, "grabEnd") == 0) {
    response = _grab_end(self, method_call);
  } else if(strcmp(method, "grabUpdate") == 0) {
    response = _grab_update(self, method_call);
  } else if(strcmp(method, "playAnimation") == 0) {
    response = _play_animation(self, method_call);
  } else if(strcmp(method, "stopAnimation") == 0) {
    response = _stop_animation(self, method_call);
  } else if(strcmp(method, "setMorphTargetWeights") == 0) {
    response = _set_morph_target_weights(self, method_call);
  } else if(strcmp(method, "setMorphAnimation") == 0) {
    response = _set_morph_animation(self, method_call);
  } else if(strcmp(method, "getMorphTargetNames") == 0) {
    response = _get_morph_target_names(self, method_call);
  } else if(strcmp(method, "setPosition") == 0) {
    response = _set_position(self, method_call);
  } else if(strcmp(method, "setBoneTransform") == 0) {
    response = _set_bone_transform(self, method_call);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);

}

static void thermion_flutter_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(thermion_flutter_plugin_parent_class)->dispose(object);
}

static void thermion_flutter_plugin_class_init(ThermionFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = thermion_flutter_plugin_dispose;
}

static void thermion_flutter_plugin_init(ThermionFlutterPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  ThermionFlutterPlugin* plugin = FLUTTER_FILAMENT_PLUGIN(user_data);
  thermion_flutter_plugin_handle_method_call(plugin, method_call);
}

void thermion_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  ThermionFlutterPlugin* plugin = FLUTTER_FILAMENT_PLUGIN(
      g_object_new(thermion_flutter_plugin_get_type(), nullptr));

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







  