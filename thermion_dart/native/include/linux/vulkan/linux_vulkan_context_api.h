#pragma once

#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to the Linux Vulkan context
typedef struct ThermionLinuxVulkanContext_t* ThermionLinuxVulkanContextHandle;

ThermionLinuxVulkanContextHandle ThermionLinuxVulkanContext_Create();
void ThermionLinuxVulkanContext_Destroy(ThermionLinuxVulkanContextHandle ctx);

int64_t ThermionLinuxVulkanContext_CreateRenderingSurface(
    ThermionLinuxVulkanContextHandle ctx, uint32_t width, uint32_t height);
void ThermionLinuxVulkanContext_DestroyRenderingSurface(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId);

int64_t ThermionLinuxVulkanContext_GetVulkanImage(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId);
int ThermionLinuxVulkanContext_GetDmaBufFd(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId);
uint32_t ThermionLinuxVulkanContext_GetDrmFormat(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId);
uint32_t ThermionLinuxVulkanContext_GetStride(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId);
uint32_t ThermionLinuxVulkanContext_GetOffset(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId);
uint32_t ThermionLinuxVulkanContext_GetWidth(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId);
uint32_t ThermionLinuxVulkanContext_GetHeight(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId);

void ThermionLinuxVulkanContext_Blit(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId);

// Returns opaque platform pointer (filament::backend::VulkanPlatform*)
int64_t ThermionLinuxVulkanContext_GetPlatform(
    ThermionLinuxVulkanContextHandle ctx);
// Returns opaque shared context pointer
int64_t ThermionLinuxVulkanContext_GetSharedContext(
    ThermionLinuxVulkanContextHandle ctx);

#ifdef __cplusplus
}
#endif
