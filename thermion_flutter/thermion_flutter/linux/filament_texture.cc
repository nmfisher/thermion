#include <flutter_linux/flutter_linux.h>
#include <flutter_linux/fl_texture_registrar.h>
#include <flutter_linux/fl_texture.h>
#include <flutter_linux/fl_texture_gl.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <epoxy/gl.h>
#include "include/thermion_flutter/filament_texture.h"

#include <iostream>
#include <vector>


G_DEFINE_TYPE(FilamentTextureGL,
              filament_texture_gl,
              fl_texture_gl_get_type())

static gboolean
filament_texture_populate (FlTextureGL *texture,
                        uint32_t *target,
                        uint32_t *name,
                        uint32_t *width,
                        uint32_t *height,
                        GError **error) {
  FilamentTextureGL *self = FILAMENT_TEXTURE_GL (texture);
  *target = GL_TEXTURE_2D;
  *name = self->texture_id;
  *width = self->width;
  *height = self->height;
  return TRUE;
}

void filament_texture_gl_dispose(GObject* object) {
  auto filamentTextureGL = FILAMENT_TEXTURE_GL(object);
  glDeleteTextures(1, &(filamentTextureGL->texture_id));
  filamentTextureGL->texture_id = 0;
}

void filament_texture_gl_class_init(FilamentTextureGLClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = filament_texture_gl_dispose;
  FL_TEXTURE_GL_CLASS(klass)->populate = filament_texture_populate;
}

void filament_texture_gl_init(FilamentTextureGL* self) { }

void destroy_filament_texture(FlTexture* texture, FlTextureRegistrar* registrar) { 
  fl_texture_registrar_unregister_texture(registrar, texture);
}

FlTexture* create_filament_texture(uint32_t width, uint32_t height, FlTextureRegistrar* registrar) {   
  auto textureGL = FILAMENT_TEXTURE_GL(g_object_new(filament_texture_gl_get_type(), nullptr));
  textureGL->width = width;
  textureGL->height = height;
  textureGL->registrar = registrar;

  g_autoptr(FlTexture) texture = FL_TEXTURE(textureGL);

  glGenTextures(1, &textureGL->texture_id);

  glBindTexture(GL_TEXTURE_2D, textureGL->texture_id);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  glTexImage2D (GL_TEXTURE_2D, 0, GL_RGBA8, textureGL->width, textureGL->height, 0, GL_RGBA,
                  GL_UNSIGNED_BYTE, 0);
   
  if(fl_texture_registrar_register_texture(registrar, texture) == TRUE) { 

    if(fl_texture_registrar_mark_texture_frame_available(registrar,
                                                    texture) != TRUE) {
      std::cout << "FAILED" << std::endl;
      return nullptr;
    } 
  }
  return texture;
}