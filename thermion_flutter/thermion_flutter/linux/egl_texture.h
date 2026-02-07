#ifndef THERMION_EGL_TEXTURE_H
#define THERMION_EGL_TEXTURE_H

#include <epoxy/gl.h>
#include <epoxy/egl.h>

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

#define THERMION_TEXTURE_GL(obj) \
   (G_TYPE_CHECK_INSTANCE_CAST((obj), thermion_texture_gl_get_type(), \
                               ThermionTextureGL))

struct _ThermionTextureGL {
    FlTextureGL parent_instance;
    GLuint gl_texture_id;
    uint32_t width;
    uint32_t height;
    FlTextureRegistrar* registrar;
    // dmabuf info for lazy EGL import
    int dmabuf_fd;
    uint32_t stride;
    uint32_t offset;
    uint32_t drm_format;
    EGLImage egl_image;
    gboolean initialized;
    int64_t surface_id;  // for Blit() and destruction
};

typedef struct _ThermionTextureGL ThermionTextureGL;
typedef struct {
  FlTextureGLClass parent_instance;
  gboolean (*populate)(FlTextureGL* texture,
                       uint32_t* target,
                       uint32_t* name,
                       uint32_t* width,
                       uint32_t* height,
                       GError** error);
} ThermionTextureGLClass;

G_END_DECLS

FLUTTER_PLUGIN_EXPORT ThermionTextureGL* thermion_texture_gl_create(
    uint32_t width, uint32_t height,
    int dmabuf_fd, uint32_t stride, uint32_t offset, uint32_t drm_format,
    int64_t surface_id,
    FlTextureRegistrar* registrar);

FLUTTER_PLUGIN_EXPORT void thermion_texture_gl_destroy(ThermionTextureGL* texture);

#endif
