# Frame Timing Improvements

This document outlines timing issues in the current Flutter render loop implementation and proposed improvements while preserving the multithreaded structure.

## Current Implementation

The rendering system consists of three main components:

- **`RenderThread.cpp`** - Manages the render thread loop and frame requests
- **`RenderTicker.cpp`** - Handles actual rendering and animation updates
- **`ffi_filament_app.dart`** - Flutter-side integration for frame requests

### Desktop Flow

```
Flutter (Dart)                  Render Thread (C++)
─────────────                   ─────────────────
requestFrame()
   │
   ├─> Run hooks
   │
   └─> RenderThread_requestFrameAsync()
         │
         └─> requestFrame() sets mRender = true
               │
               └─> _cv.notify_one() wakes render thread
                     │
                     └─> iter() loop checks mRender
                           │
                           ├─> mRenderTicker->render(nanos)
                           │
                           └─> mRendered = true
                                 │
                                 └─> Next iteration: mRendered = false
```

### Web (Emscripten) Flow

Uses `emscripten_set_main_loop_arg()` with a 12ms time budget per iteration.

### Flutter Widget Integration

**Current Location:** `thermion_flutter/thermion_flutter/lib/src/widgets/src/thermion_widget_internal_native_texture.dart:155-190`

```dart
void _requestFrame() async {
    if (!mounted) return;

    await _frameCompleter?.future;
    _frameCompleter = Completer();

    var headroom = _deadline.difference(DateTime.now());
    if (headroom.inMilliseconds > 5) {
      var waitForNs = headroom.inMicroseconds - 5000;
      await Future.delayed(Duration(microseconds: waitForNs));
    }

    if (widget.viewer.rendering && _resizing.isEmpty) {
      if (_states.isNotEmpty && this == _states.first && _texture != null) {
        await FilamentApp.instance!.requestFrame();
      }
    }

    WidgetsBinding.instance.scheduleFrameCallback((Duration d) async {
      _texture?.markTextureFrameAvailable();
      _frameCompleter?.complete();
    });

    var deadlineInMicros = (widget.viewer.msPerFrame * 1000).toInt();
    _deadline = DateTime.now().add(Duration(microseconds: deadlineInMicros));

    Timer.run(_requestFrame);  // ← Self-scheduling via Timer
}
```

**Problem:** The current implementation uses `Timer.run()` to continuously self-schedule frames, which is not synchronized with Flutter's vsync. This means:
- Thermion renders on its own timer, independent of Flutter's render pipeline
- No guarantee of alignment with Flutter's frame boundaries
- The `msPerFrame` timing is approximate (based on `DateTime.now()`) not vsync-locked
- Bump allocators cannot be safely used because there's no guaranteed frame boundary

### Flutter Scheduler Callbacks Available

Flutter's `SchedulerBinding` provides several hooks for frame synchronization:

| Callback | When Called | Use Case |
|----------|-------------|----------|
| `addPersistentFrameCallback()` | At start of every frame (after vsync) | Per-frame logic like animation |
| `addPostFrameCallback()` | After frame completes (after rasterization) | One-time cleanup after render |
| `scheduleFrame()` | Request next frame from engine | Trigger a new frame |
| `onBeginFrame` | Fired at vsync, before build/layout/paint | Low-level frame start |
| `onDrawFrame` | Fired after beginFrame, before build | Low-level draw phase |

---

## Identified Issues

### 1. Race Condition in `mRendered` Flag

**Location:** `RenderThread.cpp:76-82, 108-120`

```cpp
// Desktop thread loop - resets mRendered AFTER each iteration
while (!mStop) {
    iter();
    mRendered = false;  // ← Reset happens at START of next iteration
}

// requestFrame() can be skipped if called after render but before reset
void RenderThread::requestFrame() {
    if(mRendered) { return; }  // ← May skip legitimate requests
    if(mRender) {
        TRACE("Warning - frame requested before previous frame has completed rendering");
    }
    mRender = true;
    #ifndef __EMSCRIPTEN__
    _cv.notify_one();
    #endif
}
```

**Problem:** If `requestFrame()` is called after `iter()` completes but before the next iteration resets `mRendered` to `false`, the request is silently dropped.

### 2. No Frame Pacing

**Location:** `RenderThread.cpp:149-162`

```cpp
std::unique_lock<std::mutex> taskLock(_taskMutex);

if (!_tasks.empty()) {
    auto task = std::move(_tasks.front());
    _tasks.pop_front();
    taskLock.unlock();
    task();
    taskLock.lock();
}
#ifndef __EMSCRIPTEN__
_cv.wait_for(taskLock, std::chrono::microseconds(2000), [this]
            { return !_tasks.empty() || mStop; });
#endif
```

**Problem:** The 2µs wait is essentially a busy-wait that consumes CPU. The loop doesn't track target frame times or align with vsync. Frames are rendered immediately upon request rather than at a consistent cadence.

### 3. Frame Time Calculation Issues

**Location:** `RenderThread.cpp:127-128`

```cpp
auto currentTime = std::chrono::high_resolution_clock::now();
auto frameStartInNanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
    currentTime.time_since_epoch()).count();
```

**Problem:** This passes absolute time (epoch) to the renderer. For smooth animation, the renderer needs consistent delta times between frames. Absolute timestamps can cause jitter if frames don't render at exactly consistent intervals.

### 4. Web Platform Time Budget

**Location:** `RenderThread.cpp:36`

```cpp
while (!rt->mStop && !rt->mRestart && elapsed < 12) {
    rt->iter();
    numIters++;
    auto now = std::chrono::high_resolution_clock::now();
    elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - startTime).count();
}
```

**Problem:** The 12ms budget doesn't align with standard vsync intervals:
- 60Hz = 16.67ms per frame
- 90Hz = 11.11ms per frame
- 120Hz = 8.33ms per frame

### 5. Synchronous Hook Execution

**Location:** `ffi_filament_app.dart:708-719`

```dart
@override
Future requestFrame() async {
    _requesting = true;
    try {
      for (final hook in _hooks) {
        await hook.call();  // ← Sequential, blocks frame request
      }
    } catch (err) {
      _logger.severe(err);
    }
    _requesting = false;
    RenderThread_requestFrameAsync();
}
```

**Problem:** Hooks run sequentially and synchronously before requesting the frame. If hooks take significant time, this adds latency to the frame request.

---

## Proposed Improvements

### 1. Fix the Frame Request State Machine

Replace the dual `mRender`/`mRendered` boolean flags with a proper state enum:

```cpp
// In RenderThread.hpp
enum class RenderState : uint8_t {
    Idle,           // No frame pending, ready to accept request
    Requested,      // Frame requested, not yet started
    Rendering,      // Frame currently being rendered
    Completed       // Frame completed, awaiting next request
};

class RenderThread {
    std::atomic<RenderState> mRenderState{RenderState::Idle};

    void requestFrame() {
        RenderState expected = RenderState::Idle;
        if (mRenderState.compare_exchange_strong(expected, RenderState::Requested)) {
            #ifndef __EMSCRIPTEN__
            _cv.notify_one();
            #endif
        }
    }
};

// In RenderThread.cpp iter()
void RenderThread::iter() {
    RenderState expected = RenderState::Requested;
    if (mRenderState.compare_exchange_strong(expected, RenderState::Rendering)) {
        // ... render logic ...
        mRenderState.store(RenderState::Completed);
    }

    // Reset to Idle when ready for next frame
    if (mRenderState.load() == RenderState::Completed) {
        mRenderState.store(RenderState::Idle);
    }

    // ... task processing ...
}
```

**Benefits:**
- Eliminates race condition
- Clear state transitions
- Thread-safe with atomic operations

### 2. Add Frame Pacing with Target FPS

```cpp
// In RenderThread.hpp
class RenderThread {
    std::chrono::nanoseconds _targetFrameTime{16'666'666}; // 60 FPS by default
    std::chrono::high_resolution_clock::time_point _lastFrameEndTime;
    bool _framePacingEnabled = true;

public:
    void setTargetFPS(int fps) {
        if (fps > 0) {
            _targetFrameTime = std::chrono::nanoseconds(1'000'000'000 / fps);
        } else {
            _framePacingEnabled = false;
        }
    }
};

// In RenderThread.cpp iter()
void RenderThread::iter() {
    auto iterStartTime = std::chrono::high_resolution_clock::now();

    // Render if requested
    RenderState expected = RenderState::Requested;
    if (mRenderState.compare_exchange_strong(expected, RenderState::Rendering)) {
        auto currentTime = std::chrono::high_resolution_clock::now();
        auto frameStartInNanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
            currentTime.time_since_epoch()).count();

        if (mRenderTicker->render(frameStartInNanos)) {
            _lastFrameEndTime = std::chrono::high_resolution_clock::now();

            // FPS tracking
            float deltaTime = std::chrono::duration<float, std::chrono::seconds::period>(
                currentTime - _lastFrameTime).count();
            _lastFrameTime = currentTime;
            _frameCount++;
            _accumulatedTime += deltaTime;

            if (_accumulatedTime >= 1.0f) {
                _fps = _frameCount / _accumulatedTime;
                _frameCount = 0;
                _accumulatedTime = 0.0f;
                TRACE("FPS: %.1f", _fps);
            }
        }
        mRenderState.store(RenderState::Completed);
        mRenderState.store(RenderState::Idle);
    }

    // Process tasks
    std::unique_lock<std::mutex> taskLock(_taskMutex);
    if (!_tasks.empty()) {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        taskLock.unlock();
        task();
        taskLock.lock();
    }

    // Frame pacing: calculate appropriate sleep time
    if (_framePacingEnabled && !_tasks.empty() == false) {
        auto now = std::chrono::high_resolution_clock::now();
        auto timeSinceLastFrame = now - _lastFrameEndTime;
        auto timeUntilNextFrame = _targetFrameTime - timeSinceLastFrame;

        if (timeUntilNextFrame > std::chrono::milliseconds(1)) {
            _cv.wait_for(taskLock, timeUntilNextFrame, [this] {
                return !_tasks.empty() || mStop || mRenderState.load() == RenderState::Requested;
            });
        } else {
            // Minimal sleep to yield CPU
            _cv.wait_for(taskLock, std::chrono::microseconds(500), [this] {
                return !_tasks.empty() || mStop || mRenderState.load() == RenderState::Requested;
            });
        }
    } else {
        // No pacing, minimal wait
        #ifndef __EMSCRIPTEN__
        _cv.wait_for(taskLock, std::chrono::microseconds(500), [this] {
            return !_tasks.empty() || mStop;
        });
        #endif
    }
}
```

### 3. Delta Time Smoothing

Add delta time smoothing in `RenderTicker` to reduce jitter:

```cpp
// In RenderTicker.hpp
class RenderTicker {
    static constexpr size_t FRAME_HISTORY_SIZE = 5;
    std::array<uint64_t, FRAME_HISTORY_SIZE> _frameTimeHistory{};
    size_t _historyIndex = 0;
    uint64_t _lastFrameTime = 0;

public:
    bool render(uint64_t frameTimeInNanos) {
        // Calculate smoothed delta time
        uint64_t deltaTime = 0;
        if (_lastFrameTime > 0) {
            deltaTime = frameTimeInNanos - _lastFrameTime;

            // Sanity check: reject extremely large deltas (e.g., after pause)
            if (deltaTime > 100_000'000) { // 100ms
                deltaTime = 16'666'666; // Assume 60 FPS
            }
        }
        _lastFrameTime = frameTimeInNanos;

        uint64_t smoothedDelta = getSmoothedDeltaTime(deltaTime);

        // ... rest of render logic using smoothedDelta ...

        std::lock_guard lock(mMutex);

        for (auto animationManager : mAnimationManagers) {
            animationManager->update(smoothedDelta);
        }

        thermion::plugin::UpdatePlugins(smoothedDelta);

        // ... rendering ...
    }

private:
    uint64_t getSmoothedDeltaTime(uint64_t rawDelta) {
        _frameTimeHistory[_historyIndex] = rawDelta;
        _historyIndex = (_historyIndex + 1) % FRAME_HISTORY_SIZE;

        uint64_t sum = 0;
        for (auto t : _frameTimeHistory) {
            sum += t;
        }
        return sum / FRAME_HISTORY_SIZE;
    }
};
```

### 4. Parallel Hook Execution on Flutter Side

```dart
// In ffi_filament_app.dart
@override
Future requestFrame() async {
    // Early exit if a request is already in flight
    if (_requesting) {
        _logger.finest("Frame request already in flight, skipping");
        return;
    }

    _requesting = true;
    try {
        // Run hooks in parallel where possible for lower latency
        if (_hooks.isEmpty) {
            // Fast path - no hooks
        } else if (_hooks.length == 1) {
            await _hooks.first.call();
        } else {
            // Run hooks in parallel, wait for all to complete
            await Future.wait(_hooks.map((h) => h.call()), eagerError: true);
        }
    } catch (err) {
        _logger.severe("Error in requestFrame hook: $err");
    } finally {
        _requesting = false;
    }

    RenderThread_requestFrameAsync();
}
```

### 5. Platform-Specific VSync Integration

**Desktop (macOS/iOS):**

```cpp
#ifdef __APPLE__
#include <QuartzCore/CADisplayLink.h>

class RenderThread {
    CVDisplayLinkRef _displayLink = nullptr;

    static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink,
                                        const CVTimeStamp* inNow,
                                        const CVTimeStamp* inOutputTime,
                                        CVOptionFlags flagsIn,
                                        CVOptionFlags* flagsOut,
                                        void* displayLinkContext) {
        auto* rt = static_cast<RenderThread*>(displayLinkContext);
        rt->requestFrame();
        return kCVReturnSuccess;
    }

    void enableVSync() {
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, &displayLinkCallback, this);
        CVDisplayLinkStart(_displayLink);
    }
};
#endif
```

**Web (Emscripten):**

Replace the 12ms budget with proper `requestAnimationFrame` integration:

```cpp
#ifdef __EMSCRIPTEN
static void rAFLoop(void* arg) {
    auto* rt = static_cast<RenderThread*>(arg);

    rt->mRestart = false;
    rt->mRendered = false;

    // Single iteration per rAF call
    rt->iter();

    if(rt->mStop) {
        Log("RenderThread stopped");
        emscripten_set_main_loop_arg(nullptr, nullptr, 0, true);
        Log("Cleared main loop");
    }
    // Browser will call us again at next vsync
}

static void *startHelper(void * parm) {
    loopStart = std::chrono::high_resolution_clock::now();
    // Use requestAnimationFrame (simulate = true)
    emscripten_set_main_loop_arg(&rAFLoop, parm, 0, true);
    return nullptr;
}
#endif
```

### 6. Adaptive Frame Rate

Add dynamic frame rate adjustment based on render time:

```cpp
// In RenderThread
class RenderThread {
    std::array<float, 60> _renderTimeHistory{};
    size_t _renderTimeIndex = 0;
    int _targetFPS = 60;

    void updateAdaptiveFrameRate(float lastRenderTimeMs) {
        _renderTimeHistory[_renderTimeIndex] = lastRenderTimeMs;
        _renderTimeIndex = (_renderTimeIndex + 1) % _renderTimeHistory.size();

        // Calculate average render time
        float avgRenderTime = 0;
        for (auto t : _renderTimeHistory) {
            avgRenderTime += t;
        }
        avgRenderTime /= _renderTimeHistory.size();

        // Adjust target FPS if we're consistently missing targets
        float targetFrameTimeMs = 1000.0f / _targetFPS;

        if (avgRenderTime > targetFrameTimeMs * 0.9f && _targetFPS > 30) {
            // Dropping frames, reduce target FPS
            _targetFPS = std::max(30, _targetFPS - 10);
            setTargetFPS(_targetFPS);
            TRACE("Reduced target FPS to %d", _targetFPS);
        } else if (avgRenderTime < targetFrameTimeMs * 0.5f && _targetFPS < 120) {
            // Headroom available, increase target FPS
            _targetFPS = std::min(120, _targetFPS + 10);
            setTargetFPS(_targetFPS);
            TRACE("Increased target FPS to %d", _targetFPS);
        }
    }
};
```

### 7. Flutter VSync Synchronization (Bump Allocator Pattern)

For use cases requiring synchronized frame boundaries (e.g., bump allocators that reset per frame), integrate Thermion's render loop with Flutter's vsync using `SchedulerBinding`.

#### The Bump Allocator Problem

A bump allocator needs:
1. **Deterministic lifecycle** - Allocations are valid for exactly one frame
2. **Synchronized reset** - Reset happens after all consumers are done
3. **No async/threading issues** - Allocations must not be freed while in use

```
Frame N                          Frame N+1
────────                         ──────────────
┌─────────────────┐              ┌─────────────────┐
│ Reset allocator │              │ Reset allocator │
└────────┬────────┘              └────────┬────────┘
         │                                │
         ▼                                ▼
┌─────────────────┐              ┌─────────────────┐
│ Allocate        │              │ Allocate        │
│ - vertices      │              │ - vertices      │
│ - indices       │              │ - indices       │
│ - transforms    │              │ - transforms    │
└────────┬────────┘              └────────┬────────┘
         │                                │
         ▼                                ▼
┌─────────────────┐              ┌─────────────────┐
│ Submit to GPU   │              │ Submit to GPU   │
└────────┬────────┘              └────────┬────────┘
         │                                │
         ▼                                │
┌─────────────────┐                      │
│ Render (uses    │◄─────────────────────┘
│ allocations)    │  Still valid!
└─────────────────┘
```

#### Implementation: Flutter-Synchronized Frame Request

Replace the `Timer.run()`-based loop with Flutter's `SchedulerBinding`:

```dart
// In thermion_widget_internal_native_texture.dart
class _ThermionTextureWidgetState extends State<ThermionWidgetInternal> {
  bool _isFrameScheduled = false;
  int _persistentFrameCallbackId = 0;

  @override
  void initState() {
    super.initState();
    // ... existing init ...

    // Register persistent frame callback for vsync synchronization
    _persistentFrameCallbackId =
        SchedulerBinding.instance.scheduleFrameCallback(_onVSync);

    // Start the render loop
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.cancelFrameCallback(_persistentFrameCallbackId);
    // ... existing dispose ...
    super.dispose();
  }

  /// Called by Flutter at vsync - start of frame boundary
  void _onVSync(Duration timestamp) {
    if (!mounted) return;

    // Reset bump allocator at frame start
    // All allocations from previous frame are now invalid
    _bumpAllocator?.reset();

    // Request Thermion render for this frame
    if (widget.viewer.rendering && _resizing.isEmpty && _texture != null) {
      if (_states.isNotEmpty && this == _states.first) {
        _requestThermionFrame();
      }
    }

    // Schedule next frame
    SchedulerBinding.instance.scheduleFrame();

    // Mark texture available after Flutter's build/layout/paint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _texture?.markTextureFrameAvailable();
    });
  }

  Future<void> _requestThermionFrame() async {
    try {
      await FilamentApp.instance!.requestFrame();
      if (widget.showFpsCounter) {
        _frameCount++;
      }
    } catch (e) {
      _logger.warning('Frame request failed: $e');
    }
  }
}
```

#### Alternative: Using `addPersistentFrameCallback`

For a cleaner integration, use `addPersistentFrameCallback` which is automatically called every frame:

```dart
class _ThermionTextureWidgetState extends State<ThermionWidgetInternal> {
  VoidCallback? _persistentCallbackHandle;

  @override
  void initState() {
    super.initState();
    // ... existing init ...

    _persistentCallbackHandle =
        SchedulerBinding.instance.addPersistentFrameCallback(_onFrameStart);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _states.add(this);
      _requestFrame(); // Initial frame
    });
  }

  @override
  void dispose() {
    _persistentCallbackHandle?.call();
    // ... existing dispose ...
    super.dispose();
  }

  /// Called at the START of every Flutter frame (after vsync)
  void _onFrameStart(Duration timestamp) {
    if (!mounted) return;

    // Phase 1: Reset bump allocator
    // All allocations from previous frame are now invalid
    BumpAllocator.instance.reset();

    // Phase 2: Request Thermion render
    // Thermion will use the fresh allocator for this frame's data
    if (widget.viewer.rendering && _resizing.isEmpty && _texture != null) {
      if (_states.isNotEmpty && this == _states.first) {
        _renderThermion();
      }
    }

    // Phase 3: Mark texture available in post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _texture?.markTextureFrameAvailable();
    });
  }

  Future<void> _renderThermion() async {
    try {
      await FilamentApp.instance!.requestFrame();
      if (widget.showFpsCounter) {
        _frameCount++;
      }
    } catch (e) {
      _logger.warning('Frame request failed: $e');
    }
  }
}
```

#### Bump Allocator Implementation

```dart
// In thermion_dart package
class BumpAllocator {
  static final BumpAllocator instance = BumpAllocator._internal();
  BumpAllocator._internal();

  // Pre-allocated buffer for fast allocations
  final List<int> _buffer = [];
  int _offset = 0;
  int _highWaterMark = 0;

  /// Allocate space for [count] integers, returns offset
  int allocateInt32(int count) {
    final offset = _offset;
    _offset += count;

    // Grow buffer if needed
    while (_buffer.length < _offset) {
      _buffer.add(0);
    }

    // Track high water mark for buffer sizing
    if (_offset > _highWaterMark) {
      _highWaterMark = _offset;
    }

    return offset;
  }

  /// Get pointer to buffer at offset (for FFI)
  Pointer<Int32> getPointer(int offset) {
    return _buffer.cast<Int64>().elementAt(offset).cast<Int32>();
  }

  /// Reset allocator for new frame
  /// Safe because:
  /// 1. Called at vsync before any allocations
  /// 2. Previous frame's GPU commands are complete
  /// 3. No async operations can hold references
  void reset() {
    _offset = 0;
    // Optionally zero memory for debugging
    // _buffer.fillRange(0, _highWaterMark, 0);
  }

  /// Get current allocation size (for monitoring)
  int get currentSize => _offset;

  /// Get peak allocation size (for buffer sizing)
  int get peakSize => _highWaterMark;
}
```

#### Usage Example

```dart
// In your rendering code
Future<void> uploadGeometry(Geometry geometry) async {
  // Allocate from bump allocator (valid for this frame only)
  final vertexOffset = BumpAllocator.instance.allocateInt32(geometry.vertices.length);
  final indexOffset = BumpAllocator.instance.allocateInt32(geometry.indices.length);

  // Copy data to allocator buffer
  final vertexPtr = BumpAllocator.instance.getPointer(vertexOffset);
  final indexPtr = BumpAllocator.instance.getPointer(indexOffset);

  // Upload to GPU via FFI
  // ... FFI calls using vertexPtr, indexPtr ...

  // No need to free! Allocator resets at next vsync
  // GPU has the data in its own buffers by then
}
```

#### Flow Comparison

**Current (Timer-based, no synchronization):**
```
Timer.run() ──> requestFrame() ──> Render ──> markAvailable()
      │                                              │
      └──────────────────(~16ms)─────────────────────┘
```

**Synchronized (VSync-based):**
```
Flutter VSync ──> resetAllocator() ──> requestFrame() ──> Render
       │                                                │
       │                                                ▼
       └──────────────────────────────────────────> markAvailable()
                                                    (post-frame)
```

### 8. Hybrid Approach: Synchronized Rendering with Frame Skipping

For scenarios where Thermion should render at the same rate as Flutter (including frame drops), add frame state tracking:

```dart
class _ThermionTextureWidgetState extends State<ThermionWidgetInternal> {
  Duration? _lastFrameTime;
  int _skippedFrames = 0;

  void _onFrameStart(Duration timestamp) {
    if (!mounted) return;

    // Calculate actual frame time from Flutter's vsync
    final frameTime = _lastFrameTime != null
        ? timestamp - _lastFrameTime!
        : Duration.zero;
    _lastFrameTime = timestamp;

    // Reset bump allocator
    BumpAllocator.instance.reset();

    // Only render Thermion if we have budget
    final thermionFrameTime = Duration(microseconds: (widget.viewer.msPerFrame * 1000).toInt());

    if (frameTime >= thermionFrameTime || _skippedFrames > 3) {
      if (widget.viewer.rendering && _resizing.isEmpty && _texture != null) {
        if (_states.isNotEmpty && this == _states.first) {
          _renderThermion();
          _skippedFrames = 0;
        }
      }
    } else {
      _skippedFrames++;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _texture?.markTextureFrameAvailable();
    });
  }
}
```

---

## Implementation Priority

| Priority | Improvement | Impact | Complexity |
|----------|-------------|--------|------------|
| **High** | Fix state machine (#1) | Eliminates dropped frames | Low |
| **High** | Frame pacing (#2) | Consistent frame delivery | Medium |
| **High** | Flutter vsync sync (#7) | Bump allocator support, synchronized rendering | Low |
| **Medium** | Delta time smoothing (#3) | Smoother animations | Low |
| **Medium** | Web rAF integration (#5) | Better vsync on web | Low |
| **Low** | Parallel hooks (#4) | Reduced latency | Low |
| **Low** | Adaptive frame rate (#6) | Dynamic performance | Medium |
| **Low** | Hybrid frame skipping (#8) | Frame drop consistency | Low |

---

## Testing Checklist

After implementing improvements, verify:

- [ ] No frames are dropped when `requestFrame()` is called rapidly
- [ ] Frame intervals are consistent (measure with `std::chrono` logging)
- [ ] FPS matches target rate when frame pacing is enabled
- [ ] No increase in CPU usage when idle
- [ ] Smooth animation playback (no jitter or stuttering)
- [ ] Web platform maintains 60fps on standard displays
- [ ] Desktop platform respects vsync where available
- [ ] **Flutter vsync sync:** Bump allocator resets at Flutter frame boundaries
- [ ] **Flutter vsync sync:** Texture availability synchronized with Flutter's render pipeline
- [ ] **Flutter vsync sync:** No use-after-free errors with bump-allocated data
- [ ] **Flutter vsync sync:** Frame timing matches Flutter's reported frame timestamps

---

## References

- Files:
  - `thermion_dart/native/src/RenderTicker.cpp:85-150`
  - `thermion_dart/native/src/rendering/RenderThread.cpp:108-164`
  - `thermion_dart/native/include/rendering/RenderThread.hpp:26-107`
  - `thermion_dart/lib/src/filament/src/implementation/ffi_filament_app.dart:708-719`
  - `thermion_flutter/thermion_flutter/lib/src/widgets/src/thermion_widget_internal_native_texture.dart:155-190`

- Flutter SchedulerBinding API:
  - `SchedulerBinding.scheduleFrame()` - Request next frame from engine
  - `SchedulerBinding.addPersistentFrameCallback()` - Register callback for every frame
  - `SchedulerBinding.scheduleFrameCallback()` - Register one-time frame callback
  - `WidgetsBinding.addPostFrameCallback()` - Register callback after frame completes
