// Fake GL used by the Linux plugin harness. Implemented in fakes/fake_egl_gl.cc.
#pragma once

#include <stdint.h>

typedef unsigned int GLuint;
typedef unsigned int GLenum;
typedef int GLint;
typedef int GLsizei;
typedef unsigned char GLubyte;
typedef void* GLeglImageOES;

#define GL_NO_ERROR 0
#define GL_TEXTURE_2D 0x0DE1
#define GL_UNSIGNED_BYTE 0x1401
#define GL_RGBA 0x1908
#define GL_VERSION 0x1F02
#define GL_LINEAR 0x2601
#define GL_TEXTURE_MAG_FILTER 0x2800
#define GL_TEXTURE_MIN_FILTER 0x2801
#define GL_TEXTURE_WRAP_S 0x2802
#define GL_TEXTURE_WRAP_T 0x2803
#define GL_RGBA8 0x8058
#define GL_CLAMP_TO_EDGE 0x812F

typedef void (*PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)(GLenum target,
                                                    GLeglImageOES image);

#ifdef __cplusplus
extern "C" {
#endif

void glGenTextures(GLsizei n, GLuint* textures);
void glDeleteTextures(GLsizei n, const GLuint* textures);
void glBindTexture(GLenum target, GLuint texture);
void glTexImage2D(GLenum target,
                  GLint level,
                  GLint internalformat,
                  GLsizei width,
                  GLsizei height,
                  GLint border,
                  GLenum format,
                  GLenum type,
                  const void* pixels);
void glTexParameteri(GLenum target, GLenum pname, GLint param);
GLenum glGetError(void);
const GLubyte* glGetString(GLenum name);

#ifdef __cplusplus
}
#endif
