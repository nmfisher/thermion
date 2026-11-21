// Fake Filament ExternalImage / Thermion ExternalVulkanImage for the Linux
// plugin harness. Mirrors the intrusive reference counting the plugin relies
// on: an ExternalImageHandle retains the image and deletes it on last release.
#pragma once

#include <atomic>
#include <cstdint>

namespace filament::backend {

struct Platform {
  struct ExternalImage {
    void retain() { refs.fetch_add(1); }
    void release() {
      if (refs.fetch_sub(1) == 1) delete this;
    }

   protected:
    ExternalImage();
    virtual ~ExternalImage();

   private:
    std::atomic<int> refs{0};
  };

  class ExternalImageHandle {
   public:
    explicit ExternalImageHandle(ExternalImage* image) : image_(image) {
      if (image_) image_->retain();
    }
    ~ExternalImageHandle() {
      if (image_) image_->release();
    }
    ExternalImageHandle(const ExternalImageHandle&) = delete;
    ExternalImageHandle& operator=(const ExternalImageHandle&) = delete;

   private:
    ExternalImage* image_;
  };
};

}  // namespace filament::backend

namespace thermion::vulkan {

struct ExternalVulkanImage : public filament::backend::Platform::ExternalImage {
  int64_t surfaceId = -1;

 protected:
  ~ExternalVulkanImage() override = default;
};

}  // namespace thermion::vulkan
