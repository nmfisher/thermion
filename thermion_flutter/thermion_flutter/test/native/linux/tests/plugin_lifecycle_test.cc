// Lifecycle tests for the thermion_flutter Linux plugin's EGL texture
// ownership. The plugin sources are compiled unmodified; see fakes/ for the
// Flutter, EGL/GL and producer stand-ins.
//
// Each test drives the plugin like the engine does: method calls on the
// platform (main) thread, populate() on a separate raster thread with Flutter's
// render context current, and deferred responses through the GLib main loop.
#include <atomic>
#include <chrono>
#include <cstring>
#include <iostream>
#include <thread>

#include "fakes/fake_state.h"
#include "test_harness.h"

extern "C" void* thermion_flutter_get_plugin_handle();
extern "C" void thermion_flutter_mark_textures(void* plugin);

namespace {

constexpr int64_t kOpenGL = 1;
constexpr int64_t kVulkan = 2;

// Owns one method call reference and returns its response.
fake::Response Call(const char* method, FlValue* args = nullptr) {
  FlMethodCall* call = fake::Invoke(method, args);
  fake::Response response = fake::GetResponse(call);
  g_object_unref(call);
  return response;
}

int64_t CreateBootstrap() {
  auto r = Call("createContextBootstrap", fake::IntList({1, 1}));
  EXPECT_TRUE(r.success);
  EXPECT_TRUE(r.hasInt);
  return r.intValue;
}

fake::PopulateResult PopulateOnRaster(int64_t id) {
  fake::PopulateResult result;
  fake::OnRasterThread([&] { result = fake::Populate(id); });
  return result;
}

// Bootstrap handshake followed by Filament OpenGL initialization. Leaves the
// bootstrap registered, as the widget does until it is torn down.
int64_t InitOpenGL() {
  int64_t bootstrap = CreateBootstrap();
  EXPECT_TRUE(PopulateOnRaster(bootstrap).ok);
  fake::PumpMainLoop();
  auto r = Call("getDriverPlatform", fake::Int(kOpenGL));
  EXPECT_TRUE(r.success);
  return bootstrap;
}

void InitVulkan() {
  auto r = Call("getDriverPlatform", fake::Int(kVulkan));
  EXPECT_TRUE(r.success);
}

int64_t CreateTexture(int64_t width = 64, int64_t height = 32) {
  auto r = Call("createTexture", fake::IntList({width, height}));
  EXPECT_TRUE(r.success);
  EXPECT_EQ(r.intList.size(), size_t(3));
  return r.intList.empty() ? -1 : r.intList[0];
}

void Destroy(int64_t id) {
  auto r = Call("destroyTexture", fake::Int(id));
  EXPECT_TRUE(r.success);
}

void ExpectNoViolations() {
  auto violations = fake::Violations();
  for (auto& v : violations) {
    harness::Fail("fake detected: " + v, __FILE__, __LINE__);
  }
}

// Everything the plugin allocated through EGL/GL/producers/fds is released.
void ExpectNoLeaks(int baselineFds) {
  EXPECT_EQ(fake::LiveGlTextures(), 0);
  EXPECT_EQ(fake::LiveEglImages(), 0);
  EXPECT_EQ(fake::LiveCreatedEglContexts(), 0);
  EXPECT_EQ(fake::LiveProducerSurfaces(), 0);
  EXPECT_EQ(fake::RegisteredCount(), 0);
  EXPECT_EQ(fake::OpenFdCount(), baselineFds);
}

struct Session {
  int baselineFds;
  Session() {
    fake::ResetAll();
    // GLib opens its main-loop wakeup fds lazily; open them before sampling
    // the baseline so they are not reported as leaks.
    fake::PumpMainLoop();
    baselineFds = fake::OpenFdCount();
    fake::StartEngine();
  }
  ~Session() { fake::StopEngine(); }
};

}  // namespace

// --- Context bootstrap ----------------------------------------------------------

THERMION_TEST(bootstrap_resolves_every_waiter) {
  Session s;
  int64_t id = CreateBootstrap();
  FlMethodCall* first = fake::Invoke("awaitTextureReady", fake::Int(id));
  FlMethodCall* second = fake::Invoke("awaitTextureReady", fake::Int(id));
  EXPECT_EQ(fake::GetResponse(first).responseCount, 0);
  EXPECT_EQ(fake::GetResponse(second).responseCount, 0);

  auto populated = PopulateOnRaster(id);
  EXPECT_TRUE(populated.ok);
  // Responses are deferred to the platform loop, never sent from populate().
  EXPECT_EQ(fake::GetResponse(first).responseCount, 0);
  fake::PumpMainLoop();

  for (FlMethodCall* call : {first, second}) {
    auto r = fake::GetResponse(call);
    EXPECT_EQ(r.responseCount, 1);
    EXPECT_TRUE(r.success);
    EXPECT_EQ(r.intValue, int64_t(populated.name));
    g_object_unref(call);
  }
  Destroy(id);
  ExpectNoViolations();
}

THERMION_TEST(bootstrap_destroyed_before_populate_rejects_every_waiter) {
  Session s;
  int64_t id = CreateBootstrap();
  FlMethodCall* first = fake::Invoke("awaitTextureReady", fake::Int(id));
  FlMethodCall* second = fake::Invoke("awaitTextureReady", fake::Int(id));
  Destroy(id);
  fake::PumpMainLoop();
  for (FlMethodCall* call : {first, second}) {
    auto r = fake::GetResponse(call);
    EXPECT_EQ(r.responseCount, 1);
    EXPECT_EQ(r.errorCode, std::string("DESTROYED"));
    g_object_unref(call);
  }
  ExpectNoViolations();
  EXPECT_EQ(fake::LiveGlTextures(), 0);
}

THERMION_TEST(bootstrap_destroyed_before_deferred_response_reports_destroyed) {
  Session s;
  int64_t id = CreateBootstrap();
  FlMethodCall* waiter = fake::Invoke("awaitTextureReady", fake::Int(id));
  EXPECT_TRUE(PopulateOnRaster(id).ok);
  // populate() queued the response; the widget is torn down before it runs.
  Destroy(id);
  fake::PumpMainLoop();
  auto r = fake::GetResponse(waiter);
  EXPECT_EQ(r.responseCount, 1);
  EXPECT_EQ(r.errorCode, std::string("DESTROYED"));
  g_object_unref(waiter);
  ExpectNoViolations();
}

THERMION_TEST(cancelled_bootstrap_deletes_gl_texture_in_flutter_share_group) {
  Session s;
  int64_t id = CreateBootstrap();
  EXPECT_TRUE(PopulateOnRaster(id).ok);
  fake::PumpMainLoop();
  EXPECT_EQ(fake::LiveGlTextures(fake::FlutterShareGroup()), 1);

  // Widget disposed before Dart requested the driver platform.
  Destroy(id);
  EXPECT_EQ(fake::Count("gl.delete_texture"), 1);
  EXPECT_EQ(fake::LiveGlTextures(), 0);
  // The utility context created only for this cleanup is torn down again,
  // and no producer was initialized.
  EXPECT_EQ(fake::LiveCreatedEglContexts(), 0);
  EXPECT_EQ(fake::Count("gl_producer.ctor"), 0);
  ExpectNoViolations();
}

THERMION_TEST(sibling_bootstrap_survives_cancelled_bootstrap) {
  Session s;
  // Two viewers bootstrap concurrently; one is disposed first.
  int64_t a = CreateBootstrap();
  int64_t b = CreateBootstrap();
  EXPECT_TRUE(PopulateOnRaster(a).ok);
  EXPECT_TRUE(PopulateOnRaster(b).ok);
  fake::PumpMainLoop();
  Destroy(b);

  // Flutter's raster context is still valid, so the surviving viewer must be
  // able to initialize Filament without another populate().
  auto r = Call("getDriverPlatform", fake::Int(kOpenGL));
  EXPECT_TRUE(r.success);
  EXPECT_EQ(r.errorCode, std::string(""));
  Destroy(a);
  ExpectNoViolations();
  EXPECT_EQ(fake::LiveGlTextures(), 0);
}

// --- DMA-BUF texture teardown -----------------------------------------------------

THERMION_TEST(opengl_texture_teardown_releases_consumer_before_producer) {
  Session s;
  int64_t bootstrap = InitOpenGL();
  Destroy(bootstrap);
  int64_t id = CreateTexture();
  auto populated = PopulateOnRaster(id);
  EXPECT_TRUE(populated.ok);
  EXPECT_EQ(fake::LiveEglImages(), 1);

  Destroy(id);
  int deleteTex = fake::LastIndexOf("gl.delete_texture name=" +
                                    std::to_string(populated.name));
  int destroyImage = fake::IndexOf("egl.destroy_image");
  int destroySurface = fake::IndexOf("gl_producer.destroy_surface");
  EXPECT_TRUE(deleteTex >= 0);
  EXPECT_TRUE(destroyImage >= 0);
  EXPECT_TRUE(destroySurface >= 0);
  EXPECT_TRUE(deleteTex < destroySurface);
  EXPECT_TRUE(destroyImage < destroySurface);
  EXPECT_FALSE(fake::IsRegistered(id));
  ExpectNoViolations();
  EXPECT_EQ(fake::LiveGlTextures(), 0);
  EXPECT_EQ(fake::LiveEglImages(), 0);
  EXPECT_EQ(fake::LiveProducerSurfaces(), 0);
}

THERMION_TEST(vulkan_texture_teardown_releases_consumer_resources) {
  Session s;
  InitVulkan();
  int64_t id = CreateTexture();
  auto populated = PopulateOnRaster(id);
  EXPECT_TRUE(populated.ok);
  EXPECT_EQ(fake::LiveGlTextures(fake::FlutterShareGroup()), 1);
  EXPECT_EQ(fake::LiveEglImages(), 1);

  Destroy(id);
  EXPECT_EQ(fake::LiveGlTextures(), 0);
  EXPECT_EQ(fake::LiveEglImages(), 0);
  EXPECT_EQ(fake::LiveProducerSurfaces(), 0);
  int destroyImage = fake::IndexOf("egl.destroy_image");
  int destroySurface = fake::IndexOf("vk_producer.destroy_surface");
  EXPECT_TRUE(destroyImage >= 0 && destroyImage < destroySurface);
  ExpectNoViolations();
}

THERMION_TEST(repeated_resize_does_not_leak) {
  Session s;
  int64_t bootstrap = InitOpenGL();
  Destroy(bootstrap);
  int64_t current = CreateTexture();
  PopulateOnRaster(current);
  for (int i = 0; i < 25; i++) {
    int64_t next = CreateTexture(64 + i, 32 + i);
    PopulateOnRaster(next);
    Destroy(current);
    current = next;
  }
  Destroy(current);
  ExpectNoViolations();
  EXPECT_EQ(fake::LiveGlTextures(), 0);
  EXPECT_EQ(fake::LiveEglImages(), 0);
  EXPECT_EQ(fake::LiveProducerSurfaces(), 0);
}

// --- Raster thread races ------------------------------------------------------------

THERMION_TEST(populate_after_destroy_does_not_touch_texture) {
  Session s;
  int64_t bootstrap = InitOpenGL();
  Destroy(bootstrap);
  int64_t id = CreateTexture();
  // The engine's lookup returns a raw pointer without a reference. Take it,
  // then let the platform thread destroy the texture before populate() runs.
  FlTexture* raw = fake::LookupRaw(id);
  EXPECT_TRUE(raw != nullptr);
  Destroy(id);

  fake::PopulateResult late;
  fake::OnRasterThread([&] { late = fake::PopulateRaw(raw); });
  EXPECT_FALSE(late.ok);
  EXPECT_EQ(fake::Count("egl.create_image"), 0);
  EXPECT_EQ(fake::LiveGlTextures(), 0);
  ExpectNoViolations();
}

THERMION_TEST(destroy_waits_for_inflight_import) {
  Session s;
  int64_t bootstrap = InitOpenGL();
  Destroy(bootstrap);
  int64_t id = CreateTexture();

  std::atomic<bool> importing{false};
  fake::SetCreateImageHook([&] {
    importing = true;
    std::this_thread::sleep_for(std::chrono::milliseconds(150));
  });
  fake::PopulateResult result;
  std::thread raster([&] {
    fake::MakeFlutterRasterContextCurrent();
    result = fake::Populate(id);
    fake::ReleaseCurrentContext();
  });
  while (!importing) std::this_thread::yield();
  Destroy(id);  // platform thread, while the import is in progress
  raster.join();
  fake::SetCreateImageHook(nullptr);

  EXPECT_TRUE(fake::IndexOf("egl.create_image") <
              fake::IndexOf("gl_producer.destroy_surface"));
  ExpectNoViolations();
  // The import that completed first is still cleaned up.
  EXPECT_EQ(fake::LiveGlTextures(), 0);
  EXPECT_EQ(fake::LiveEglImages(), 0);
}

THERMION_TEST(concurrent_populate_and_resize_churn) {
  Session s;
  InitVulkan();
  std::atomic<bool> stop{false};
  std::atomic<int64_t> maxId{0};
  int64_t first = CreateTexture();
  maxId = first;

  std::thread raster([&] {
    fake::MakeFlutterRasterContextCurrent();
    while (!stop) {
      for (int64_t id = 1; id <= maxId; id++) {
        fake::PopulateRaw(fake::LookupRaw(id));
      }
    }
    fake::ReleaseCurrentContext();
  });

  int64_t current = first;
  for (int i = 0; i < 250; i++) {
    int64_t next = CreateTexture(64 + (i % 7), 32);
    maxId = next;
    thermion_flutter_mark_textures(thermion_flutter_get_plugin_handle());
    Destroy(current);
    current = next;
  }
  stop = true;
  raster.join();
  Destroy(current);
  ExpectNoViolations();
  EXPECT_EQ(fake::LiveGlTextures(), 0);
  EXPECT_EQ(fake::LiveEglImages(), 0);
  EXPECT_EQ(fake::LiveProducerSurfaces(), 0);
}

// --- Context / plugin teardown --------------------------------------------------------

THERMION_TEST(destroy_context_releases_live_textures_first) {
  Session s;
  int64_t bootstrap = InitOpenGL();
  Destroy(bootstrap);
  int64_t a = CreateTexture();
  int64_t b = CreateTexture();
  PopulateOnRaster(a);
  PopulateOnRaster(b);

  // FilamentApp.destroy(): Dart forgets its descriptors, then destroys the
  // context without destroying each texture.
  auto r = Call("destroyContext");
  EXPECT_TRUE(r.success);
  EXPECT_FALSE(fake::IsRegistered(a));
  EXPECT_FALSE(fake::IsRegistered(b));
  EXPECT_EQ(fake::Count("gl_producer.dtor_freed_surface"), 0);
  EXPECT_TRUE(fake::LastIndexOf("gl_producer.destroy_surface") <
              fake::IndexOf("gl_producer.dtor"));
  ExpectNoViolations();
  ExpectNoLeaks(s.baselineFds);
}

THERMION_TEST(plugin_dispose_releases_live_textures_first) {
  int baseline;
  {
    Session s;
    baseline = s.baselineFds;
    InitVulkan();
    int64_t id = CreateTexture();
    PopulateOnRaster(id);
  }  // engine shutdown disposes the plugin
  EXPECT_EQ(fake::Count("vk_producer.dtor_freed_surface"), 0);
  EXPECT_EQ(thermion_flutter_get_plugin_handle(), nullptr);
  ExpectNoViolations();
  ExpectNoLeaks(baseline);
}

THERMION_TEST(registration_failure_releases_texture_and_fd) {
  Session s;
  InitVulkan();
  fake::FailNextRegistration();
  auto r = Call("createTexture", fake::IntList({64, 32}));
  EXPECT_EQ(r.errorCode, std::string("REGISTER_FAILED"));
  EXPECT_EQ(fake::RegisterAttempts(), 1);
  EXPECT_TRUE(fake::AttemptFinalized(0));
  EXPECT_EQ(fake::LiveExternalImages(), 0);
  ExpectNoViolations();
  ExpectNoLeaks(s.baselineFds);
}

// --- Frame publication ------------------------------------------------------------------

THERMION_TEST(vulkan_blit_precedes_frame_notification) {
  Session s;
  InitVulkan();
  fake::Producers().vulkanNeedsBlit = true;
  int64_t id = CreateTexture();

  thermion_flutter_mark_textures(thermion_flutter_get_plugin_handle());
  int blit = fake::IndexOf("vk_producer.blit");
  int mark = fake::IndexOf("registrar.mark id=" + std::to_string(id));
  EXPECT_TRUE(blit >= 0 && blit < mark);

  auto r = Call("markTextureFrameAvailable", fake::Int(id));
  EXPECT_TRUE(r.success);
  EXPECT_EQ(fake::Count("vk_producer.blit"), 2);
  EXPECT_EQ(fake::FrameAvailableCount(id), 2);
  Destroy(id);
  ExpectNoViolations();
}

// --- Runner -------------------------------------------------------------------------------

int main(int argc, char** argv) {
  if (argc > 1 && std::strcmp(argv[1], "--list") == 0) {
    for (auto& t : harness::Registry()) std::cout << t.name << "\n";
    return 0;
  }
  int failedTests = 0;
  int ran = 0;
  for (auto& t : harness::Registry()) {
    if (argc > 1 && std::strcmp(argv[1], t.name) != 0) continue;
    ran++;
    int before = harness::Failures();
    std::cout << "[ RUN  ] " << t.name << std::endl;
    t.fn();
    if (harness::Failures() != before) {
      failedTests++;
      std::cout << "[ FAIL ] " << t.name << "\n  events:\n";
      for (auto& e : fake::Events()) std::cout << "    " << e << "\n";
    } else {
      std::cout << "[  OK  ] " << t.name << std::endl;
    }
  }
  if (ran == 0) {
    std::cerr << "no test matched\n";
    return 2;
  }
  std::cout << ran - failedTests << "/" << ran << " passed" << std::endl;
  return failedTests == 0 ? 0 : 1;
}
