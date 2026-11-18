// Fake EGL/GL with share-group and thread-current-context tracking.
//
// Models just enough of EGL to catch ownership bugs:
//  - a GL texture name belongs to the share group of the context that was
//    current when it was generated; deleting it requires a context from the
//    same share group to be current on the calling thread;
//  - every GL call requires some context to be current;
//  - a context can be current on at most one thread (EGL_BAD_ACCESS);
//  - no context can be made current on GTK's platform thread. On NVIDIA,
//    eglMakeCurrent there fails with EGL_BAD_ACCESS because GTK/GDK keeps its
//    own GL state on that thread (see LinuxOpenGLContext's EGL worker);
//  - EGLImages must be destroyed exactly once;
//  - an EGLImage import must see a valid dma-buf fd for its whole duration.
#include <epoxy/egl.h>
#include <epoxy/gl.h>
#include <fcntl.h>

#include <map>
#include <mutex>
#include <set>
#include <string>
#include <thread>

#include "fake_state.h"

namespace {

struct Context {
  int group = 0;
  bool destroyed = false;
  bool current = false;
  std::thread::id owner;
};

struct GlState {
  std::mutex mutex;
  // Context handles are small integers cast to pointers. 1 is Flutter's.
  std::map<uintptr_t, Context> contexts;
  uintptr_t nextContext = 2;
  int nextGroup = 2;
  // texture name -> share group
  std::map<GLuint, int> textures;
  std::set<GLuint> deletedTextures;
  GLuint nextTexture = 1;
  std::set<uintptr_t> images;
  uintptr_t nextImage = 1;
  std::function<void()> createImageHook;
  std::thread::id platformThread;
};

GlState& State() {
  static GlState* state = new GlState();
  return *state;
}

const uintptr_t kFlutterContext = 1;
EGLDisplay const kFlutterDisplay = reinterpret_cast<EGLDisplay>(0xD15);
EGLConfig const kConfig = reinterpret_cast<EGLConfig>(0xC0F);
const int kFlutterGroup = 1;

thread_local uintptr_t tlContext = 0;
thread_local EGLDisplay tlDisplay = EGL_NO_DISPLAY;
thread_local EGLenum tlApi = EGL_OPENGL_ES_API;
thread_local EGLint tlError = EGL_SUCCESS;

// Updates context ownership when the calling thread switches contexts.
// Caller holds State().mutex.
void SetCurrentLocked(uintptr_t id) {
  if (tlContext != 0) {
    auto it = State().contexts.find(tlContext);
    if (it != State().contexts.end()) it->second.current = false;
  }
  if (id != 0) {
    auto& ctx = State().contexts[id];
    ctx.current = true;
    ctx.owner = std::this_thread::get_id();
  }
  tlContext = id;
}

// Returns the share group of the context current on this thread, or 0.
int CurrentGroup(const char* call) {
  std::lock_guard<std::mutex> lock(State().mutex);
  if (tlContext == 0) {
    fake::Violation(std::string(call) + " called with no current EGL context");
    return 0;
  }
  auto it = State().contexts.find(tlContext);
  if (it == State().contexts.end() || it->second.destroyed) {
    fake::Violation(std::string(call) + " called on a destroyed EGL context");
    return 0;
  }
  return it->second.group;
}

bool FdIsOpen(int fd) { return fd >= 0 && fcntl(fd, F_GETFD) != -1; }

EGLImageKHR FakeCreateImage(EGLDisplay dpy,
                            EGLContext,
                            EGLenum target,
                            EGLClientBuffer,
                            const EGLint* attribs) {
  if (dpy != kFlutterDisplay) {
    fake::Violation("eglCreateImageKHR on a display other than Flutter's");
  }
  if (target != EGL_LINUX_DMA_BUF_EXT) {
    fake::Violation("eglCreateImageKHR with unexpected target");
    return EGL_NO_IMAGE_KHR;
  }
  int fd = -1;
  for (const EGLint* a = attribs; a && *a != EGL_NONE; a += 2) {
    if (a[0] == EGL_DMA_BUF_PLANE0_FD_EXT) fd = a[1];
  }
  if (!FdIsOpen(fd)) {
    fake::Violation("eglCreateImageKHR imported a closed dma-buf fd " +
                    std::to_string(fd));
    return EGL_NO_IMAGE_KHR;
  }
  std::function<void()> hook;
  {
    std::lock_guard<std::mutex> lock(State().mutex);
    hook = State().createImageHook;
  }
  if (hook) hook();
  if (!FdIsOpen(fd)) {
    fake::Violation("dma-buf fd " + std::to_string(fd) +
                    " was closed while eglCreateImageKHR was importing it");
    return EGL_NO_IMAGE_KHR;
  }
  uintptr_t image;
  {
    std::lock_guard<std::mutex> lock(State().mutex);
    image = State().nextImage++;
    State().images.insert(image);
  }
  fake::Record("egl.create_image id=" + std::to_string(image));
  return reinterpret_cast<EGLImageKHR>(image);
}

EGLBoolean FakeDestroyImage(EGLDisplay dpy, EGLImageKHR image) {
  if (dpy != kFlutterDisplay) {
    fake::Violation("eglDestroyImageKHR on a display other than Flutter's");
  }
  auto id = reinterpret_cast<uintptr_t>(image);
  {
    std::lock_guard<std::mutex> lock(State().mutex);
    if (State().images.erase(id) == 0) {
      fake::Violation("eglDestroyImageKHR of unknown or already destroyed image " +
                      std::to_string(id));
      return EGL_FALSE;
    }
  }
  fake::Record("egl.destroy_image id=" + std::to_string(id));
  return EGL_TRUE;
}

void FakeImageTargetTexture(GLenum, GLeglImageOES image) {
  CurrentGroup("glEGLImageTargetTexture2DOES");
  std::lock_guard<std::mutex> lock(State().mutex);
  if (!State().images.count(reinterpret_cast<uintptr_t>(image))) {
    fake::Violation("glEGLImageTargetTexture2DOES with an unknown EGLImage");
  }
}

}  // namespace

namespace fake {

EGLDisplay FlutterDisplay() { return kFlutterDisplay; }
EGLContext FlutterRenderContext() {
  return reinterpret_cast<EGLContext>(kFlutterContext);
}
int FlutterShareGroup() { return kFlutterGroup; }

int LiveGlTextures(int shareGroup) {
  std::lock_guard<std::mutex> lock(State().mutex);
  int count = 0;
  for (auto& [name, group] : State().textures) {
    if (shareGroup < 0 || group == shareGroup) count++;
  }
  return count;
}

int LiveEglImages() {
  std::lock_guard<std::mutex> lock(State().mutex);
  return static_cast<int>(State().images.size());
}

int LiveCreatedEglContexts() {
  std::lock_guard<std::mutex> lock(State().mutex);
  int count = 0;
  for (auto& [id, ctx] : State().contexts) {
    if (id != kFlutterContext && !ctx.destroyed) count++;
  }
  return count;
}

void SetCreateImageHook(std::function<void()> hook) {
  std::lock_guard<std::mutex> lock(State().mutex);
  State().createImageHook = std::move(hook);
}

void ResetEglGl() {
  std::lock_guard<std::mutex> lock(State().mutex);
  auto& s = State();
  s.contexts.clear();
  s.contexts[kFlutterContext] = Context{kFlutterGroup, false};
  s.nextContext = 2;
  s.nextGroup = 2;
  s.textures.clear();
  s.deletedTextures.clear();
  s.nextTexture = 1;
  s.images.clear();
  s.nextImage = 1;
  s.createImageHook = nullptr;
  // Tests drive method calls from the thread that resets the fakes.
  s.platformThread = std::this_thread::get_id();
  tlContext = 0;
  tlDisplay = EGL_NO_DISPLAY;
  tlApi = EGL_OPENGL_ES_API;
  tlError = EGL_SUCCESS;
}

void MakeFlutterRasterContextCurrent() {
  std::lock_guard<std::mutex> lock(State().mutex);
  SetCurrentLocked(kFlutterContext);
  tlDisplay = kFlutterDisplay;
  tlApi = EGL_OPENGL_ES_API;
}

void ReleaseCurrentContext() {
  std::lock_guard<std::mutex> lock(State().mutex);
  SetCurrentLocked(0);
  tlDisplay = EGL_NO_DISPLAY;
}

}  // namespace fake

extern "C" {

EGLContext eglGetCurrentContext(void) {
  return reinterpret_cast<EGLContext>(tlContext);
}

EGLDisplay eglGetCurrentDisplay(void) { return tlDisplay; }

EGLSurface eglGetCurrentSurface(EGLint) { return EGL_NO_SURFACE; }

EGLBoolean eglMakeCurrent(EGLDisplay dpy,
                          EGLSurface,
                          EGLSurface,
                          EGLContext ctx) {
  auto id = reinterpret_cast<uintptr_t>(ctx);
  std::lock_guard<std::mutex> lock(State().mutex);
  if (id != 0) {
    auto it = State().contexts.find(id);
    if (it == State().contexts.end() || it->second.destroyed) {
      fake::Violation("eglMakeCurrent with a destroyed or unknown context");
      tlError = EGL_BAD_CONTEXT;
      return EGL_FALSE;
    }
    if (dpy != kFlutterDisplay) {
      fake::Violation("eglMakeCurrent on a display other than Flutter's");
      tlError = EGL_BAD_ACCESS;
      return EGL_FALSE;
    }
    if (std::this_thread::get_id() == State().platformThread) {
      fake::Violation(
          "eglMakeCurrent of a context on GTK's platform thread "
          "(EGL_BAD_ACCESS on NVIDIA)");
      tlError = EGL_BAD_ACCESS;
      return EGL_FALSE;
    }
    if (it->second.current && it->second.owner != std::this_thread::get_id()) {
      fake::Violation("eglMakeCurrent of a context current on another thread");
      tlError = EGL_BAD_ACCESS;
      return EGL_FALSE;
    }
  }
  SetCurrentLocked(id);
  tlDisplay = id ? dpy : EGL_NO_DISPLAY;
  tlError = EGL_SUCCESS;
  return EGL_TRUE;
}

EGLBoolean eglBindAPI(EGLenum api) {
  if (api != EGL_OPENGL_API && api != EGL_OPENGL_ES_API) return EGL_FALSE;
  tlApi = api;
  return EGL_TRUE;
}

EGLenum eglQueryAPI(void) { return tlApi; }

EGLContext eglCreateContext(EGLDisplay dpy,
                            EGLConfig,
                            EGLContext share,
                            const EGLint*) {
  if (dpy != kFlutterDisplay) {
    fake::Violation("eglCreateContext on a display other than Flutter's");
    return EGL_NO_CONTEXT;
  }
  std::lock_guard<std::mutex> lock(State().mutex);
  int group;
  auto shareId = reinterpret_cast<uintptr_t>(share);
  if (shareId != 0) {
    auto it = State().contexts.find(shareId);
    if (it == State().contexts.end() || it->second.destroyed) {
      fake::Violation("eglCreateContext sharing with a destroyed context");
      return EGL_NO_CONTEXT;
    }
    group = it->second.group;
  } else {
    group = State().nextGroup++;
  }
  uintptr_t id = State().nextContext++;
  State().contexts[id] = Context{group, false};
  fake::Record("egl.create_context id=" + std::to_string(id) +
               " group=" + std::to_string(group));
  return reinterpret_cast<EGLContext>(id);
}

EGLBoolean eglDestroyContext(EGLDisplay, EGLContext ctx) {
  auto id = reinterpret_cast<uintptr_t>(ctx);
  {
    std::lock_guard<std::mutex> lock(State().mutex);
    auto it = State().contexts.find(id);
    if (it == State().contexts.end() || it->second.destroyed) {
      fake::Violation("eglDestroyContext of unknown or destroyed context");
      return EGL_FALSE;
    }
    if (id == kFlutterContext) {
      fake::Violation("plugin destroyed Flutter's raster context");
    }
    it->second.destroyed = true;
  }
  fake::Record("egl.destroy_context id=" + std::to_string(id));
  return EGL_TRUE;
}

EGLBoolean eglQueryContext(EGLDisplay dpy,
                           EGLContext ctx,
                           EGLint attribute,
                           EGLint* value) {
  std::lock_guard<std::mutex> lock(State().mutex);
  auto it = State().contexts.find(reinterpret_cast<uintptr_t>(ctx));
  if (dpy != kFlutterDisplay || it == State().contexts.end() ||
      it->second.destroyed || attribute != EGL_CONFIG_ID) {
    return EGL_FALSE;
  }
  *value = 7;
  return EGL_TRUE;
}

EGLBoolean eglChooseConfig(EGLDisplay dpy,
                           const EGLint*,
                           EGLConfig* configs,
                           EGLint config_size,
                           EGLint* num_config) {
  if (dpy != kFlutterDisplay || config_size < 1) return EGL_FALSE;
  configs[0] = kConfig;
  *num_config = 1;
  return EGL_TRUE;
}

EGLint eglGetError(void) {
  EGLint error = tlError;
  tlError = EGL_SUCCESS;
  return error;
}

__eglMustCastToProperFunctionPointerType eglGetProcAddress(const char* name) {
  std::string n(name);
  if (n == "eglCreateImageKHR") {
    return reinterpret_cast<__eglMustCastToProperFunctionPointerType>(
        &FakeCreateImage);
  }
  if (n == "eglDestroyImageKHR") {
    return reinterpret_cast<__eglMustCastToProperFunctionPointerType>(
        &FakeDestroyImage);
  }
  if (n == "glEGLImageTargetTexture2DOES") {
    return reinterpret_cast<__eglMustCastToProperFunctionPointerType>(
        &FakeImageTargetTexture);
  }
  return nullptr;
}

void glGenTextures(GLsizei n, GLuint* textures) {
  int group = CurrentGroup("glGenTextures");
  std::lock_guard<std::mutex> lock(State().mutex);
  for (GLsizei i = 0; i < n; i++) {
    GLuint name = State().nextTexture++;
    State().textures[name] = group;
    textures[i] = name;
  }
}

void glDeleteTextures(GLsizei n, const GLuint* textures) {
  int group = CurrentGroup("glDeleteTextures");
  for (GLsizei i = 0; i < n; i++) {
    GLuint name = textures[i];
    if (name == 0) continue;
    std::unique_lock<std::mutex> lock(State().mutex);
    auto it = State().textures.find(name);
    if (it == State().textures.end()) {
      if (State().deletedTextures.count(name)) {
        lock.unlock();
        fake::Violation("GL texture " + std::to_string(name) +
                        " deleted twice");
      }
      continue;
    }
    if (it->second != group) {
      int owner = it->second;
      lock.unlock();
      fake::Violation("GL texture " + std::to_string(name) + " from share group " +
                      std::to_string(owner) + " deleted with a context in group " +
                      std::to_string(group));
      continue;
    }
    State().textures.erase(it);
    State().deletedTextures.insert(name);
    lock.unlock();
    fake::Record("gl.delete_texture name=" + std::to_string(name) +
                 " group=" + std::to_string(group));
  }
}

void glBindTexture(GLenum, GLuint) { CurrentGroup("glBindTexture"); }

void glTexImage2D(GLenum,
                  GLint,
                  GLint,
                  GLsizei,
                  GLsizei,
                  GLint,
                  GLenum,
                  GLenum,
                  const void*) {
  CurrentGroup("glTexImage2D");
}

void glTexParameteri(GLenum, GLenum, GLint) { CurrentGroup("glTexParameteri"); }

GLenum glGetError(void) { return GL_NO_ERROR; }

const GLubyte* glGetString(GLenum name) {
  CurrentGroup("glGetString");
  if (name == GL_VERSION) {
    return reinterpret_cast<const GLubyte*>("OpenGL ES 3.2 Thermion harness");
  }
  return nullptr;
}

}  // extern "C"
