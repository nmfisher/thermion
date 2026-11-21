// Fake OpenGL/GBM producer for the Linux plugin harness
// (fakes/fake_producers.cc). Same public API as thermion_dart's
// LinuxOpenGLContext.
#pragma once

#include <cstdint>

#include "SurfaceExportInfo.h"

namespace thermion::opengl::linux_platform {

class LinuxOpenGLContext {
 public:
  explicit LinuxOpenGLContext(void* eglDisplay = nullptr);
  ~LinuxOpenGLContext();

  bool IsValid() const;
  const char* GetLastError() const;

  int64_t CreateRenderingSurface(uint32_t width, uint32_t height);
  void DestroyRenderingSurface(int64_t surfaceId);

  uint32_t GetGLTextureId(int64_t surfaceId);
  SurfaceExportInfo GetSurfaceExportInfo(int64_t surfaceId);

  void* GetSharedContext();
  void* GetPlatform();
};

}  // namespace thermion::opengl::linux_platform
