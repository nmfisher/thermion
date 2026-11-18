// Test-facing control and inspection API for the Linux plugin harness fakes.
//
// The plugin under test (thermion_flutter_plugin.cc + egl_texture.cc) is
// compiled unmodified against stub Flutter/EGL/GL/producer headers. These
// helpers drive it the way the Flutter engine would (method channel calls on
// the platform thread, populate() on a raster thread) and expose what it did
// to EGL/GL/producers so tests can assert ownership and ordering.
#pragma once

#include <epoxy/egl.h>
#include <flutter_linux/flutter_linux.h>

#include <cstdint>
#include <functional>
#include <initializer_list>
#include <string>
#include <vector>

namespace fake {

// ---- Event log and invariant violations ------------------------------------

// Every fake records significant calls ("gl.delete_texture name=3 group=1").
void Record(const std::string& event);
std::vector<std::string> Events();
// Index of the first event starting with `prefix` (or -1).
int IndexOf(const std::string& prefix);
// Index of the last event starting with `prefix` (or -1).
int LastIndexOf(const std::string& prefix);
int Count(const std::string& prefix);

// Misuse detected by a fake (GL call with no current context, import of a
// closed fd, double-destroy, ...). Tests assert this stays empty.
void Violation(const std::string& message);
std::vector<std::string> Violations();

// Clears logs and all fake state. Call between tests.
void ResetAll();

// ---- EGL / GL ----------------------------------------------------------------

EGLDisplay FlutterDisplay();
EGLContext FlutterRenderContext();
int FlutterShareGroup();
// Live GL texture names in a share group (or all groups for -1).
int LiveGlTextures(int shareGroup = -1);
int LiveEglImages();
// Contexts created through eglCreateContext and not yet destroyed.
int LiveCreatedEglContexts();
// Runs inside eglCreateImageKHR on the importing thread, after the fd has
// been validated. Used to hold an import open while another thread acts.
void SetCreateImageHook(std::function<void()> hook);

// ---- File descriptors ----------------------------------------------------------

int OpenFdCount();

// ---- Producers -----------------------------------------------------------------

struct ProducerConfig {
  bool openglValid = true;
  bool vulkanNeedsBlit = false;
};
ProducerConfig& Producers();
int LiveProducerSurfaces();
int LiveExternalImages();

// ---- Engine / registrar --------------------------------------------------------

// Creates the texture registrar, plugin registrar and messenger, then calls
// thermion_flutter_plugin_register_with_registrar().
void StartEngine();
// Drops the method channel, releasing the plugin (runs its dispose), then
// releases the registrar.
void StopEngine();

// Invokes a method on the plugin's channel on the calling (platform) thread.
// Returns the call (caller owns a reference) for response inspection.
FlMethodCall* Invoke(const char* method, FlValue* args = nullptr);

struct Response {
  int responseCount = 0;  // >1 means the call was answered twice
  bool success = false;
  bool notImplemented = false;
  std::string errorCode;
  bool hasInt = false;
  int64_t intValue = 0;
  std::vector<int64_t> intList;
};
Response GetResponse(FlMethodCall* call);

FlValue* Int(int64_t value);
FlValue* IntList(std::initializer_list<int64_t> values);

struct PopulateResult {
  bool found = false;
  bool ok = false;
  uint32_t target = 0;
  uint32_t name = 0;
  std::string error;
};

// Emulates fl_engine's external texture callback: looks up the texture by id
// (without taking a reference, like the real registrar) and calls populate.
// The calling thread must have the Flutter raster context current.
PopulateResult Populate(int64_t textureId);
// Raw-pointer lookup, exactly as the engine performs it.
FlTexture* LookupRaw(int64_t textureId);
PopulateResult PopulateRaw(FlTexture* texture);
// Runs `fn` on a fresh thread with Flutter's raster context current and joins.
void OnRasterThread(const std::function<void()>& fn);

bool IsRegistered(int64_t textureId);
int RegisteredCount();
int FrameAvailableCount(int64_t textureId);
void FailNextRegistration();
// Number of register attempts and whether the texture object passed to the
// given attempt has been finalized.
int RegisterAttempts();
bool AttemptFinalized(int attempt);

// Dispatches pending GLib main-loop sources (deferred method responses).
void PumpMainLoop();

// ---- Internal (used between fakes) ---------------------------------------------

void ResetEglGl();
void ResetProducers();
void ResetEngine();
void MakeFlutterRasterContextCurrent();
void ReleaseCurrentContext();

}  // namespace fake
