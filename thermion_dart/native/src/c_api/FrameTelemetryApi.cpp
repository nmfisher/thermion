#include "c_api/FrameTelemetryApi.h"

#include <atomic>
#include <chrono>
#include <mutex>

namespace thermion
{
    namespace
    {
        constexpr uint64_t kSlots = 256; // power of two
        std::atomic<bool> gEnabled{false};
        std::atomic<uint64_t> gSlots[kSlots];
        std::atomic<uint64_t> gWritten{0}; // total frames recorded (writer: render thread)
        uint64_t gRead = 0;                // guarded by gDrainMutex
        std::mutex gDrainMutex;
    }

    void FrameTelemetry_record()
    {
        if (!gEnabled.load(std::memory_order_relaxed))
            return;
        uint64_t ns = std::chrono::duration_cast<std::chrono::nanoseconds>(
                          std::chrono::steady_clock::now().time_since_epoch())
                          .count();
        uint64_t n = gWritten.load(std::memory_order_relaxed);
        gSlots[n & (kSlots - 1)].store(ns, std::memory_order_relaxed);
        gWritten.store(n + 1, std::memory_order_release);
    }

    extern "C"
    {
        void FrameTelemetry_enable()
        {
            std::lock_guard<std::mutex> lock(gDrainMutex);
            gRead = gWritten.load(std::memory_order_acquire);
            gEnabled.store(true, std::memory_order_relaxed);
        }

        void FrameTelemetry_disable()
        {
            gEnabled.store(false, std::memory_order_relaxed);
        }

        int FrameTelemetry_drain(uint64_t *out, int cap)
        {
            if (!out || cap <= 0)
                return 0;
            std::lock_guard<std::mutex> lock(gDrainMutex);
            uint64_t written = gWritten.load(std::memory_order_acquire);
            if (written - gRead > kSlots)
                gRead = written - kSlots;
            int count = 0;
            while (gRead < written && count < cap)
            {
                out[count++] = gSlots[gRead & (kSlots - 1)].load(std::memory_order_relaxed);
                gRead++;
            }
            // Writer may have lapped the oldest slots while copying; drop those.
            uint64_t after = gWritten.load(std::memory_order_acquire);
            if (after - (gRead - count) > kSlots)
            {
                uint64_t lost = after - kSlots - (gRead - count);
                if (lost >= (uint64_t)count)
                    return 0;
                for (int i = 0; i + (int)lost < count; i++)
                    out[i] = out[i + lost];
                count -= (int)lost;
            }
            return count;
        }
    }
}
