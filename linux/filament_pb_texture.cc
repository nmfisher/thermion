#include <flutter_linux/flutter_linux.h>
#include <flutter_linux/fl_texture_registrar.h>
#include <flutter_linux/fl_texture.h>
#include <flutter_linux/fl_pixel_buffer_texture.h>
#include <flutter_linux/fl_texture_gl.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <epoxy/gl.h>
#include "include/polyvox_filament/filament_pb_texture.h"

#include <iostream>
#include <vector>

// This was just an experiment for copying pixel buffers to Flutter. This won't actually render anything from Filament.
G_DEFINE_TYPE(FilamentPBTexture,
              filament_pb_texture,
              fl_pixel_buffer_texture_get_type())


static gboolean video_texture_copy_pixels (FlPixelBufferTexture* texture,
                               const uint8_t** out_buffer,
                               uint32_t* width,
                               uint32_t* height,
                               GError** error) {

    auto buffer = new std::vector<uint8_t>(width*height*4);
    for (int i = 0; i < width*height*4; i++)
    {
      if(i%4 == 1 || i % 4 == 3) {
        buffer->at(i) = (uint8_t)255;
      } else {
        buffer->at(i) = (uint8_t)0;
      }
    }
  *width = width;
  *height = height;
  *out_buffer = buffer->data();
  std::cout << "COPYING PIXEL BUFFER" << std::endl;
  return TRUE;
}

void filament_pb_texture_dispose(GObject* object) {
    G_OBJECT_CLASS(filament_pb_texture_parent_class)->dispose(object);
}

void filament_pb_texture_class_init(FilamentPBTextureClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = filament_pb_texture_dispose;
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = video_texture_copy_pixels;
}

void filament_pb_texture_init(FilamentPBTexture* self) { }

FLUTTER_PLUGIN_EXPORT FlTexture* create_filament_pb_texture(uint32_t width, uint32_t height, FlTextureRegistrar* registrar) {

    auto pbTexture = FILAMENT_PB_TEXTURE(g_object_new(filament_pb_texture_get_type(), nullptr));

    g_autoptr(FlTexture) texture = FL_TEXTURE(pbTexture);
   
    if(fl_texture_registrar_register_texture(registrar, texture) == TRUE) { 
       if(fl_texture_registrar_mark_texture_frame_available(registrar,
                                                       texture) != TRUE) {
         std::cout << "FAILED" << std::endl;
       } 
    }
    return texture;
}