// Fake OpenGL and Vulkan producers. Each rendering surface owns a real file
// descriptor (standing in for the exported dma-buf) that is closed when the
// surface is destroyed, so fd lifetime bugs are observable.
#include <fcntl.h>
#include <unistd.h>

#include <map>
#include <mutex>
#include <set>
#include <string>

#include "LinuxOpenGLContext.h"
#include "fake_state.h"
#include "vulkan/ExternalVulkanImage.h"
#include "vulkan/linux/LinuxVulkanContext.h"

namespace {

struct Surface {
  int fd = -1;
  uint32_t width = 0;
  uint32_t height = 0;
};

struct ProducerState {
  std::mutex mutex;
  fake::ProducerConfig config;
  // Surface ids are per-producer counters, like the real contexts.
  std::map<int64_t, Surface> glSurfaces;
  std::map<int64_t, Surface> vkSurfaces;
  int64_t nextGlSurface = 1;
  int64_t nextVkSurface = 1;
  int liveExternalImages = 0;
  int liveGlProducers = 0;
  int liveVkProducers = 0;
};

ProducerState& State() {
  static ProducerState* state = new ProducerState();
  return *state;
}

int64_t CreateSurface(std::map<int64_t, Surface>& surfaces,
                      int64_t& next,
                      uint32_t width,
                      uint32_t height) {
  int fd = open("/dev/null", O_RDONLY);
  if (fd < 0) return -1;
  int64_t id = next++;
  surfaces[id] = Surface{fd, width, height};
  return id;
}

SurfaceExportInfo ExportInfo(std::map<int64_t, Surface>& surfaces,
                             int64_t id,
                             const char* producer) {
  SurfaceExportInfo info{};
  info.dmabuf_fd = -1;
  auto it = surfaces.find(id);
  if (it == surfaces.end()) {
    fake::Violation(std::string(producer) + " GetSurfaceExportInfo for unknown surface " +
                    std::to_string(id));
    return info;
  }
  info.dmabuf_fd = it->second.fd;
  info.stride = it->second.width * 4;
  info.offset = 0;
  info.drm_format = 0x34324241;  // DRM_FORMAT_ABGR8888
  info.drm_modifier = 0;
  info.width = it->second.width;
  info.height = it->second.height;
  return info;
}

void DestroySurface(std::map<int64_t, Surface>& surfaces,
                    int64_t id,
                    const char* producer) {
  auto it = surfaces.find(id);
  if (it == surfaces.end()) {
    fake::Violation(std::string(producer) + " DestroyRenderingSurface for unknown surface " +
                    std::to_string(id));
    return;
  }
  close(it->second.fd);
  surfaces.erase(it);
}

}  // namespace

namespace fake {

ProducerConfig& Producers() { return State().config; }

int LiveProducerSurfaces() {
  std::lock_guard<std::mutex> lock(State().mutex);
  return static_cast<int>(State().glSurfaces.size() + State().vkSurfaces.size());
}

int LiveExternalImages() {
  std::lock_guard<std::mutex> lock(State().mutex);
  return State().liveExternalImages;
}

void ResetProducers() {
  std::lock_guard<std::mutex> lock(State().mutex);
  auto& s = State();
  for (auto& [id, surface] : s.glSurfaces) close(surface.fd);
  for (auto& [id, surface] : s.vkSurfaces) close(surface.fd);
  s.glSurfaces.clear();
  s.vkSurfaces.clear();
  s.nextGlSurface = 1;
  s.nextVkSurface = 1;
  s.config = ProducerConfig{};
  s.liveExternalImages = 0;
  s.liveGlProducers = 0;
  s.liveVkProducers = 0;
}

}  // namespace fake

// ---- Filament ExternalImage --------------------------------------------------

filament::backend::Platform::ExternalImage::ExternalImage() {
  std::lock_guard<std::mutex> lock(State().mutex);
  State().liveExternalImages++;
}

filament::backend::Platform::ExternalImage::~ExternalImage() {
  std::lock_guard<std::mutex> lock(State().mutex);
  State().liveExternalImages--;
}

// ---- OpenGL producer -----------------------------------------------------------

namespace thermion::opengl::linux_platform {

LinuxOpenGLContext::LinuxOpenGLContext(void* eglDisplay) {
  if (eglDisplay != fake::FlutterDisplay()) {
    fake::Violation("LinuxOpenGLContext created on a display other than Flutter's");
  }
  std::lock_guard<std::mutex> lock(State().mutex);
  State().liveGlProducers++;
  fake::Record("gl_producer.ctor");
}

LinuxOpenGLContext::~LinuxOpenGLContext() {
  std::lock_guard<std::mutex> lock(State().mutex);
  State().liveGlProducers--;
  // The real producer frees every GBM buffer with its EGL context. A consumer
  // texture still registered with Flutter would then import freed memory.
  for (auto& [id, surface] : State().glSurfaces) {
    fake::Record("gl_producer.dtor_freed_surface id=" + std::to_string(id));
    close(surface.fd);
  }
  State().glSurfaces.clear();
  fake::Record("gl_producer.dtor");
}

bool LinuxOpenGLContext::IsValid() const { return State().config.openglValid; }

const char* LinuxOpenGLContext::GetLastError() const {
  return "fake OpenGL producer configured invalid";
}

int64_t LinuxOpenGLContext::CreateRenderingSurface(uint32_t width, uint32_t height) {
  std::lock_guard<std::mutex> lock(State().mutex);
  int64_t id = CreateSurface(State().glSurfaces, State().nextGlSurface, width, height);
  fake::Record("gl_producer.create_surface id=" + std::to_string(id));
  return id;
}

void LinuxOpenGLContext::DestroyRenderingSurface(int64_t surfaceId) {
  std::lock_guard<std::mutex> lock(State().mutex);
  DestroySurface(State().glSurfaces, surfaceId, "LinuxOpenGLContext");
  fake::Record("gl_producer.destroy_surface id=" + std::to_string(surfaceId));
}

uint32_t LinuxOpenGLContext::GetGLTextureId(int64_t surfaceId) {
  return static_cast<uint32_t>(1000 + surfaceId);
}

SurfaceExportInfo LinuxOpenGLContext::GetSurfaceExportInfo(int64_t surfaceId) {
  std::lock_guard<std::mutex> lock(State().mutex);
  return ExportInfo(State().glSurfaces, surfaceId, "LinuxOpenGLContext");
}

void* LinuxOpenGLContext::GetSharedContext() {
  return reinterpret_cast<void*>(0x5C);
}

void* LinuxOpenGLContext::GetPlatform() { return reinterpret_cast<void*>(0x9F); }

}  // namespace thermion::opengl::linux_platform

// ---- Vulkan producer -----------------------------------------------------------

namespace {
struct FakeExternalVulkanImage : thermion::vulkan::ExternalVulkanImage {};
}  // namespace

namespace thermion::vulkan::linux_platform {

LinuxVulkanContext::LinuxVulkanContext() {
  std::lock_guard<std::mutex> lock(State().mutex);
  State().liveVkProducers++;
  fake::Record("vk_producer.ctor");
}

LinuxVulkanContext::~LinuxVulkanContext() {
  std::lock_guard<std::mutex> lock(State().mutex);
  State().liveVkProducers--;
  for (auto& [id, surface] : State().vkSurfaces) {
    fake::Record("vk_producer.dtor_freed_surface id=" + std::to_string(id));
    close(surface.fd);
  }
  State().vkSurfaces.clear();
  fake::Record("vk_producer.dtor");
}

int64_t LinuxVulkanContext::CreateRenderingSurface(uint32_t width, uint32_t height) {
  std::lock_guard<std::mutex> lock(State().mutex);
  int64_t id = CreateSurface(State().vkSurfaces, State().nextVkSurface, width, height);
  fake::Record("vk_producer.create_surface id=" + std::to_string(id));
  return id;
}

SurfaceExportInfo LinuxVulkanContext::GetSurfaceExportInfo(int64_t surfaceId) {
  std::lock_guard<std::mutex> lock(State().mutex);
  return ExportInfo(State().vkSurfaces, surfaceId, "LinuxVulkanContext");
}

int LinuxVulkanContext::NeedsBlit(int64_t) { return State().config.vulkanNeedsBlit; }

void LinuxVulkanContext::BlitToExport(int64_t surfaceId) {
  fake::Record("vk_producer.blit id=" + std::to_string(surfaceId));
}

void LinuxVulkanContext::DestroyRenderingSurface(int64_t surfaceId) {
  std::lock_guard<std::mutex> lock(State().mutex);
  DestroySurface(State().vkSurfaces, surfaceId, "LinuxVulkanContext");
  fake::Record("vk_producer.destroy_surface id=" + std::to_string(surfaceId));
}

void* LinuxVulkanContext::GetSharedContext() { return nullptr; }

void* LinuxVulkanContext::GetPlatform() { return reinterpret_cast<void*>(0x9E); }

void* LinuxVulkanContext::CreateExternalImageForSurface(int64_t surfaceId) {
  auto* image = new FakeExternalVulkanImage();
  image->surfaceId = surfaceId;
  return static_cast<thermion::vulkan::ExternalVulkanImage*>(image);
}

}  // namespace thermion::vulkan::linux_platform
