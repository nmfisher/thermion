#ifndef FILAMENT_PB_TEXTURE_H
#define FILAMENT_PB_TEXTURE_H
#include <gtk/gtk.h>
#include <glib-object.h>
#include <flutter_linux/flutter_linux.h>
#include <flutter_linux/fl_texture_gl.h>
#include <flutter_linux/fl_texture.h>
#include <flutter_linux/fl_pixel_buffer_texture.h>
#include <flutter_linux/fl_texture_registrar.h>


#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif


G_BEGIN_DECLS

#define FILAMENT_PB_TEXTURE(obj) \
   (G_TYPE_CHECK_INSTANCE_CAST((obj), filament_pb_texture_get_type(), \
                               FilamentPBTexture))

struct _FilamentPBTexture {
    FlPixelBufferTexture parent_instance;
};

typedef struct _FilamentPBTexture FilamentPBTexture;
typedef struct {
  FlPixelBufferTextureClass parent_instance;
  gboolean (*copy_pixels)(FlPixelBufferTexture* texture,
                          const uint8_t** buffer,
                          uint32_t* width,
                          uint32_t* height,
                          GError** error);

} FilamentPBTextureClass;

G_END_DECLS

FLUTTER_PLUGIN_EXPORT FlTexture* create_filament_pb_texture(uint32_t width, uint32_t height, FlTextureRegistrar* registrar);

#endif 