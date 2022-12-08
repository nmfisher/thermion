#ifndef FILAMENT_TEXTURE_H
#define FILAMENT_TEXTURE_H
#include <gtk/gtk.h>
#include <glib-object.h>
#include <flutter_linux/flutter_linux.h>
#include <flutter_linux/fl_texture_gl.h>
#include <flutter_linux/fl_texture.h>
#include <flutter_linux/fl_texture_registrar.h>


#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif


G_BEGIN_DECLS

#define FILAMENT_TEXTURE_GL(obj) \
   (G_TYPE_CHECK_INSTANCE_CAST((obj), filament_texture_gl_get_type(), \
                               FilamentTextureGL))

struct _FilamentTextureGL {
    FlTextureGL parent_instance;
    GLuint texture_id;
    uint32_t width;
    uint32_t height;
};

typedef struct _FilamentTextureGL FilamentTextureGL;
typedef struct {
  FlTextureGLClass parent_instance;
  gboolean (*populate)(FlTextureGL* texture,
                       uint32_t* target,
                       uint32_t* name,
                       uint32_t* width,
                       uint32_t* height,
                       GError** error);

  GLuint texture_id;
} FilamentTextureGLClass;

G_END_DECLS

FLUTTER_PLUGIN_EXPORT FlTexture* create_filament_texture(uint32_t width, uint32_t height, FlTextureRegistrar* registrar);

#endif 