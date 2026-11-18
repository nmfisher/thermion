// Fake EGL used by the Linux plugin harness. Implemented in fakes/fake_egl_gl.cc.
// Constant values match the Khronos registry so attribute lists parse the same.
#pragma once

#include <stdint.h>

typedef void* EGLDisplay;
typedef void* EGLContext;
typedef void* EGLSurface;
typedef void* EGLConfig;
typedef void* EGLImage;
typedef void* EGLImageKHR;
typedef void* EGLClientBuffer;
typedef void* EGLDeviceEXT;
typedef unsigned int EGLenum;
typedef int32_t EGLint;
typedef unsigned int EGLBoolean;
typedef intptr_t EGLAttrib;

#define EGL_FALSE 0
#define EGL_TRUE 1
#define EGL_NO_CONTEXT ((EGLContext)0)
#define EGL_NO_DISPLAY ((EGLDisplay)0)
#define EGL_NO_SURFACE ((EGLSurface)0)
#define EGL_NO_IMAGE_KHR ((EGLImageKHR)0)
#define EGL_NO_IMAGE ((EGLImage)0)

#define EGL_SUCCESS 0x3000
#define EGL_BAD_ACCESS 0x3002
#define EGL_BAD_CONTEXT 0x3006
#define EGL_CONFIG_ID 0x3028
#define EGL_NONE 0x3038
#define EGL_HEIGHT 0x3056
#define EGL_WIDTH 0x3057
#define EGL_DRAW 0x3059
#define EGL_READ 0x305A
#define EGL_CONTEXT_MAJOR_VERSION 0x3098
#define EGL_OPENGL_ES_API 0x30A0
#define EGL_OPENGL_API 0x30A2
#define EGL_CONTEXT_MINOR_VERSION 0x30FB
#define EGL_LINUX_DMA_BUF_EXT 0x3270
#define EGL_LINUX_DRM_FOURCC_EXT 0x3271
#define EGL_DMA_BUF_PLANE0_FD_EXT 0x3272
#define EGL_DMA_BUF_PLANE0_OFFSET_EXT 0x3273
#define EGL_DMA_BUF_PLANE0_PITCH_EXT 0x3274
#define EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT 0x3443
#define EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT 0x3444

typedef void (*__eglMustCastToProperFunctionPointerType)(void);
typedef EGLImageKHR (*PFNEGLCREATEIMAGEKHRPROC)(EGLDisplay dpy,
                                                EGLContext ctx,
                                                EGLenum target,
                                                EGLClientBuffer buffer,
                                                const EGLint* attrib_list);
typedef EGLBoolean (*PFNEGLDESTROYIMAGEKHRPROC)(EGLDisplay dpy,
                                                EGLImageKHR image);

#ifdef __cplusplus
extern "C" {
#endif

EGLContext eglGetCurrentContext(void);
EGLDisplay eglGetCurrentDisplay(void);
EGLSurface eglGetCurrentSurface(EGLint readdraw);
EGLBoolean eglMakeCurrent(EGLDisplay dpy,
                          EGLSurface draw,
                          EGLSurface read,
                          EGLContext ctx);
EGLBoolean eglBindAPI(EGLenum api);
EGLenum eglQueryAPI(void);
EGLContext eglCreateContext(EGLDisplay dpy,
                            EGLConfig config,
                            EGLContext share_context,
                            const EGLint* attrib_list);
EGLBoolean eglDestroyContext(EGLDisplay dpy, EGLContext ctx);
EGLBoolean eglQueryContext(EGLDisplay dpy,
                           EGLContext ctx,
                           EGLint attribute,
                           EGLint* value);
EGLBoolean eglChooseConfig(EGLDisplay dpy,
                           const EGLint* attrib_list,
                           EGLConfig* configs,
                           EGLint config_size,
                           EGLint* num_config);
EGLint eglGetError(void);
__eglMustCastToProperFunctionPointerType eglGetProcAddress(const char* name);

#ifdef __cplusplus
}
#endif
