// Fake Vulkan producer for the Linux plugin harness (fakes/fake_producers.cc).
// Same public API as thermion_dart's LinuxVulkanContext, minus Vulkan types.
#pragma once

#include <cstdint>

#include "SurfaceExportInfo.h"

namespace thermion::vulkan::linux_platform {

class LinuxVulkanContext {
 public:
  LinuxVulkanContext();
  ~LinuxVulkanContext();

  int64_t CreateRenderingSurface(uint32_t width, uint32_t height);
  SurfaceExportInfo GetSurfaceExportInfo(int64_t surfaceId);
  int NeedsBlit(int64_t surfaceId);
  void BlitToExport(int64_t surfaceId);
  void DestroyRenderingSurface(int64_t surfaceId);
  void* GetSharedContext();
  void* GetPlatform();
  void* CreateExternalImageForSurface(int64_t surfaceId);
};

}  // namespace thermion::vulkan::linux_platform
