// The worker has translation-unit-local linkage. Including the production
// implementation lets this fixture exercise it without adding test hooks to
// the shipping plugin or duplicating its worker/lifetime logic. Build this as
// a DLL, not into the child executable: the regression happens at DLL detach.
#include "../thermion_flutter_plugin.cpp"

namespace thermion::tflutter::windows {
namespace {

// Plugin construction registers a method handler, but these native lifetime
// tests do not need a Flutter engine, texture registrar, or GPU resources.
class ShutdownTestMessenger final : public flutter::BinaryMessenger {
 public:
  void Send(const std::string&, const uint8_t*, size_t,
            flutter::BinaryReply) const override {}
  void SetMessageHandler(const std::string&,
                         flutter::BinaryMessageHandler) override {}
};

}  // namespace

extern "C" __declspec(dllexport) void* ThermionTestStartBlitWorker() {
  static ShutdownTestMessenger messenger;
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      &messenger, "thermion/shutdown-test",
      &flutter::StandardMethodCodec::GetInstance());
  auto* plugin = new ThermionFlutterPlugin(nullptr, nullptr, channel);
  EnsureBlitWorkerStarted();
  return plugin;
}

extern "C" __declspec(dllexport) void ThermionTestDestroyPlugin(void* plugin) {
  delete static_cast<ThermionFlutterPlugin*>(plugin);
}

}  // namespace thermion::tflutter::windows
