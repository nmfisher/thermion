// ThreadSanitizer annotations for GMutex on Linux.
//
// GLib implements GMutex on Linux with raw futex syscalls, which TSan does not
// model, so every access the plugin guards with a GMutex (ThermionTextureGL::
// lock) would be reported as a race. Interpose the GMutex entry points the
// plugin calls, forward to GLib, and tell TSan about the lock operations.
// (On macOS GLib uses pthread mutexes, which TSan already understands.)
#include <dlfcn.h>
#include <glib.h>
#include <sanitizer/tsan_interface.h>

namespace {

template <typename Fn>
Fn Next(const char* name) {
  return reinterpret_cast<Fn>(dlsym(RTLD_NEXT, name));
}

using MutexFn = void (*)(GMutex*);
using TryLockFn = gboolean (*)(GMutex*);

}  // namespace

extern "C" {

void g_mutex_init(GMutex* mutex) {
  static MutexFn next = Next<MutexFn>("g_mutex_init");
  next(mutex);
  __tsan_mutex_create(mutex, 0);
}

void g_mutex_clear(GMutex* mutex) {
  static MutexFn next = Next<MutexFn>("g_mutex_clear");
  __tsan_mutex_destroy(mutex, 0);
  next(mutex);
}

void g_mutex_lock(GMutex* mutex) {
  static MutexFn next = Next<MutexFn>("g_mutex_lock");
  __tsan_mutex_pre_lock(mutex, 0);
  next(mutex);
  __tsan_mutex_post_lock(mutex, 0, 0);
}

gboolean g_mutex_trylock(GMutex* mutex) {
  static TryLockFn next = Next<TryLockFn>("g_mutex_trylock");
  __tsan_mutex_pre_lock(mutex, __tsan_mutex_try_lock);
  gboolean locked = next(mutex);
  __tsan_mutex_post_lock(
      mutex, locked ? __tsan_mutex_try_lock : __tsan_mutex_try_lock_failed, 0);
  return locked;
}

void g_mutex_unlock(GMutex* mutex) {
  static MutexFn next = Next<MutexFn>("g_mutex_unlock");
  __tsan_mutex_pre_unlock(mutex, 0);
  next(mutex);
  __tsan_mutex_post_unlock(mutex, 0);
}

}  // extern "C"
