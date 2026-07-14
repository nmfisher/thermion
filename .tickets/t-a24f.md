---
id: t-a24f
status: open
deps: []
links: []
created: 2026-01-24T06:56:32Z
type: task
priority: 2
assignee: Nick Fisher
---
# Use same VkQueue for Filament rendering and blit operations

Investigate using the same VkQueue from Filament's Platform instance for blit operations to ensure proper GPU synchronization without explicit semaphores.

## Design

## Current State

The blit operations in vulkan_context.cpp use a VkQueue obtained from createCommandResources(), while Filament uses the queue specified in the VulkanSharedContext passed via GetSharedContext().

## Problem

If these are different queues, the pipeline barriers in Blit() are insufficient for Filament→Blit synchronization:
- Pipeline barriers only synchronize within a queue
- Cross-queue sync requires semaphores or queue family ownership transfers

## Analysis

### If Same Queue (Preferred)
- Pipeline barriers are sufficient
- Implicit queue submission ordering provides sync
- Current barrier (srcAccessMask=COLOR_ATTACHMENT_WRITE, oldLayout=COLOR_ATTACHMENT_OPTIMAL) correctly waits for render

### If Different Queues (Requires Changes)
Options:
1. **Use Filament's queue for blit**: Access via Platform instance, submit blit commands to same queue
2. **Add semaphore**: Filament signals after render, blit waits before starting
3. **Timeline semaphore**: More flexible, allows multiple sync points

## Implementation Path

1. Verify queue configuration in createCommandResources() vs _sharedContext
2. If different: modify to use Platform's queue for blit submission
3. If not possible: implement semaphore-based sync

## Files to Investigate
- thermion_dart/native/src/windows/vulkan/vulkan_context.cpp (createCommandResources, queue usage)
- Filament's VulkanPlatform interface for queue access

