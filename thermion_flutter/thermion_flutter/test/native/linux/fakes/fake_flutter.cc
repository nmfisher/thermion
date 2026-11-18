// Fake Flutter Linux embedder objects plus the engine-side harness that drives
// the plugin: method channel dispatch on the platform thread and populate()
// via a raw registrar lookup on a raster thread, as fl_engine does.
#include <fcntl.h>

#include <atomic>
#include <map>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "egl_texture.h"
#include "fake_state.h"

extern "C" void thermion_flutter_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

// ---- Event log -----------------------------------------------------------------

namespace {

struct Log {
  std::mutex mutex;
  std::vector<std::string> events;
  std::vector<std::string> violations;
};

Log& TheLog() {
  static Log* log = new Log();
  return *log;
}

}  // namespace

namespace fake {

void Record(const std::string& event) {
  std::lock_guard<std::mutex> lock(TheLog().mutex);
  TheLog().events.push_back(event);
}

std::vector<std::string> Events() {
  std::lock_guard<std::mutex> lock(TheLog().mutex);
  return TheLog().events;
}

int IndexOf(const std::string& prefix) {
  auto events = Events();
  for (size_t i = 0; i < events.size(); i++) {
    if (events[i].rfind(prefix, 0) == 0) return static_cast<int>(i);
  }
  return -1;
}

int LastIndexOf(const std::string& prefix) {
  auto events = Events();
  for (size_t i = events.size(); i-- > 0;) {
    if (events[i].rfind(prefix, 0) == 0) return static_cast<int>(i);
  }
  return -1;
}

int Count(const std::string& prefix) {
  int count = 0;
  for (auto& e : Events()) {
    if (e.rfind(prefix, 0) == 0) count++;
  }
  return count;
}

void Violation(const std::string& message) {
  std::lock_guard<std::mutex> lock(TheLog().mutex);
  TheLog().violations.push_back(message);
  TheLog().events.push_back("VIOLATION " + message);
}

std::vector<std::string> Violations() {
  std::lock_guard<std::mutex> lock(TheLog().mutex);
  return TheLog().violations;
}

int OpenFdCount() {
  int count = 0;
  for (int fd = 0; fd < 4096; fd++) {
    if (fcntl(fd, F_GETFD) != -1) count++;
  }
  return count;
}

}  // namespace fake

// ---- FlValue -------------------------------------------------------------------

struct _FlValue {
  std::atomic<int> refs{1};
  FlValueType type = FL_VALUE_TYPE_NULL;
  int64_t i = 0;
  std::vector<FlValue*> list;
};

FlValue* fl_value_new_null(void) { return new _FlValue(); }

FlValue* fl_value_new_int(int64_t value) {
  auto* v = new _FlValue();
  v->type = FL_VALUE_TYPE_INT;
  v->i = value;
  return v;
}

FlValue* fl_value_new_list(void) {
  auto* v = new _FlValue();
  v->type = FL_VALUE_TYPE_LIST;
  return v;
}

FlValue* fl_value_ref(FlValue* value) {
  value->refs.fetch_add(1);
  return value;
}

void fl_value_unref(FlValue* value) {
  if (value->refs.fetch_sub(1) == 1) {
    for (auto* child : value->list) fl_value_unref(child);
    delete value;
  }
}

FlValueType fl_value_get_type(FlValue* value) { return value->type; }

int64_t fl_value_get_int(FlValue* value) {
  if (value->type != FL_VALUE_TYPE_INT) {
    fake::Violation("fl_value_get_int on a non-int value");
  }
  return value->i;
}

size_t fl_value_get_length(FlValue* value) { return value->list.size(); }

FlValue* fl_value_get_list_value(FlValue* value, size_t index) {
  return value->list.at(index);
}

void fl_value_append_take(FlValue* list, FlValue* child) {
  list->list.push_back(child);
}

// ---- FlMethodResponse ----------------------------------------------------------

enum ResponseKind { kSuccess, kError, kNotImplemented };

struct _FlMethodResponse {
  GObject parent_instance;
  ResponseKind kind;
  gchar* code;
  FlValue* result;
};

G_DEFINE_TYPE(FlMethodResponse, fl_method_response, G_TYPE_OBJECT)

static void fl_method_response_finalize(GObject* object) {
  auto* self = FL_METHOD_RESPONSE(object);
  g_free(self->code);
  if (self->result) fl_value_unref(self->result);
  G_OBJECT_CLASS(fl_method_response_parent_class)->finalize(object);
}

static void fl_method_response_class_init(FlMethodResponseClass* klass) {
  G_OBJECT_CLASS(klass)->finalize = fl_method_response_finalize;
}

static void fl_method_response_init(FlMethodResponse* self) {
  self->kind = kSuccess;
  self->code = nullptr;
  self->result = nullptr;
}

FlMethodSuccessResponse* fl_method_success_response_new(FlValue* result) {
  auto* r = FL_METHOD_RESPONSE(g_object_new(fl_method_response_get_type(), nullptr));
  r->kind = kSuccess;
  r->result = result ? fl_value_ref(result) : fl_value_new_null();
  return r;
}

FlMethodErrorResponse* fl_method_error_response_new(const gchar* code,
                                                    const gchar*,
                                                    FlValue*) {
  auto* r = FL_METHOD_RESPONSE(g_object_new(fl_method_response_get_type(), nullptr));
  r->kind = kError;
  r->code = g_strdup(code);
  return r;
}

FlMethodNotImplementedResponse* fl_method_not_implemented_response_new(void) {
  auto* r = FL_METHOD_RESPONSE(g_object_new(fl_method_response_get_type(), nullptr));
  r->kind = kNotImplemented;
  return r;
}

// ---- FlMethodCall --------------------------------------------------------------

struct _FlMethodCall {
  GObject parent_instance;
  gchar* name;
  FlValue* args;
  int responseCount;
  FlMethodResponse* response;
};

G_DEFINE_TYPE(FlMethodCall, fl_method_call, G_TYPE_OBJECT)

static void fl_method_call_finalize(GObject* object) {
  auto* self = FL_METHOD_CALL(object);
  g_free(self->name);
  if (self->args) fl_value_unref(self->args);
  g_clear_object(&self->response);
  G_OBJECT_CLASS(fl_method_call_parent_class)->finalize(object);
}

static void fl_method_call_class_init(FlMethodCallClass* klass) {
  G_OBJECT_CLASS(klass)->finalize = fl_method_call_finalize;
}

static void fl_method_call_init(FlMethodCall* self) {
  self->name = nullptr;
  self->args = nullptr;
  self->responseCount = 0;
  self->response = nullptr;
}

const gchar* fl_method_call_get_name(FlMethodCall* call) { return call->name; }

FlValue* fl_method_call_get_args(FlMethodCall* call) { return call->args; }

gboolean fl_method_call_respond(FlMethodCall* call,
                                FlMethodResponse* response,
                                GError**) {
  call->responseCount++;
  if (call->responseCount > 1) {
    fake::Violation(std::string("method call '") + call->name +
                    "' was answered more than once");
    return FALSE;
  }
  call->response = FL_METHOD_RESPONSE(g_object_ref(response));
  return TRUE;
}

// ---- Codec / channel / messenger -----------------------------------------------

struct _FlStandardMethodCodec {
  GObject parent_instance;
};
G_DEFINE_TYPE(FlStandardMethodCodec, fl_standard_method_codec, G_TYPE_OBJECT)
static void fl_standard_method_codec_class_init(FlStandardMethodCodecClass*) {}
static void fl_standard_method_codec_init(FlStandardMethodCodec*) {}
FlStandardMethodCodec* fl_standard_method_codec_new(void) {
  return FL_STANDARD_METHOD_CODEC(
      g_object_new(fl_standard_method_codec_get_type(), nullptr));
}

struct _FlMethodChannel {
  GObject parent_instance;
  FlMethodChannelMethodCallHandler handler;
  gpointer user_data;
  GDestroyNotify destroy_notify;
};

G_DEFINE_TYPE(FlMethodChannel, fl_method_channel, G_TYPE_OBJECT)

static void fl_method_channel_dispose(GObject* object) {
  auto* self = FL_METHOD_CHANNEL(object);
  if (self->destroy_notify && self->user_data) {
    self->destroy_notify(self->user_data);
  }
  self->destroy_notify = nullptr;
  self->user_data = nullptr;
  self->handler = nullptr;
  G_OBJECT_CLASS(fl_method_channel_parent_class)->dispose(object);
}

static void fl_method_channel_class_init(FlMethodChannelClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = fl_method_channel_dispose;
}

static void fl_method_channel_init(FlMethodChannel* self) {
  self->handler = nullptr;
  self->user_data = nullptr;
  self->destroy_notify = nullptr;
}

struct _FlBinaryMessenger {
  // The messenger keeps the channel alive while a handler is installed, as
  // the embedder's channel registration does.
  FlMethodChannel* channel = nullptr;
};

FlMethodChannel* fl_method_channel_new(FlBinaryMessenger* messenger,
                                       const gchar*,
                                       FlMethodCodec*) {
  auto* channel =
      FL_METHOD_CHANNEL(g_object_new(fl_method_channel_get_type(), nullptr));
  g_clear_object(&messenger->channel);
  messenger->channel = FL_METHOD_CHANNEL(g_object_ref(channel));
  return channel;
}

void fl_method_channel_set_method_call_handler(
    FlMethodChannel* channel,
    FlMethodChannelMethodCallHandler handler,
    gpointer user_data,
    GDestroyNotify destroy_notify) {
  if (channel->destroy_notify && channel->user_data) {
    channel->destroy_notify(channel->user_data);
  }
  channel->handler = handler;
  channel->user_data = user_data;
  channel->destroy_notify = destroy_notify;
}

// ---- Textures ------------------------------------------------------------------

G_DEFINE_INTERFACE(FlTexture, fl_texture, G_TYPE_OBJECT)
static void fl_texture_default_init(FlTextureInterface*) {}

static GQuark TextureIdQuark() {
  static GQuark quark = g_quark_from_static_string("fake-texture-id");
  return quark;
}

int64_t fl_texture_get_id(FlTexture* texture) {
  return GPOINTER_TO_SIZE(g_object_get_qdata(G_OBJECT(texture), TextureIdQuark()));
}

static void fl_texture_gl_texture_iface_init(FlTextureInterface*) {}

G_DEFINE_TYPE_WITH_CODE(FlTextureGL,
                        fl_texture_gl,
                        G_TYPE_OBJECT,
                        G_IMPLEMENT_INTERFACE(fl_texture_get_type(),
                                              fl_texture_gl_texture_iface_init))
static void fl_texture_gl_class_init(FlTextureGLClass* klass) {
  klass->populate = nullptr;
}
static void fl_texture_gl_init(FlTextureGL*) {}

struct _FlTextureRegistrar {
  GObject parent_instance;
};
G_DEFINE_TYPE(FlTextureRegistrar, fl_texture_registrar, G_TYPE_OBJECT)
static void fl_texture_registrar_class_init(FlTextureRegistrarClass*) {}
static void fl_texture_registrar_init(FlTextureRegistrar*) {}

namespace {

struct Attempt {
  bool finalized = false;
};

struct EngineState {
  std::mutex mutex;  // guards textures, like the real registrar's mutex
  std::map<int64_t, FlTexture*> textures;  // registrar holds a reference
  std::map<int64_t, int> frameAvailable;
  int64_t nextId = 1;
  bool failNextRegistration = false;
  std::vector<Attempt*> attempts;
  FlTextureRegistrar* registrar = nullptr;
  FlBinaryMessenger* messenger = nullptr;
};

EngineState& Engine() {
  static EngineState* state = new EngineState();
  return *state;
}

void OnAttemptFinalized(gpointer data, GObject*) {
  static_cast<Attempt*>(data)->finalized = true;
}

}  // namespace

struct _FlPluginRegistrar {
  FlTextureRegistrar* textures;
  FlBinaryMessenger* messenger;
};

gboolean fl_texture_registrar_register_texture(FlTextureRegistrar*,
                                               FlTexture* texture) {
  auto* attempt = new Attempt();
  g_object_weak_ref(G_OBJECT(texture), OnAttemptFinalized, attempt);
  std::lock_guard<std::mutex> lock(Engine().mutex);
  Engine().attempts.push_back(attempt);
  if (Engine().failNextRegistration) {
    Engine().failNextRegistration = false;
    fake::Record("registrar.register_failed");
    return FALSE;
  }
  int64_t id = Engine().nextId++;
  g_object_set_qdata(G_OBJECT(texture), TextureIdQuark(), GSIZE_TO_POINTER(id));
  Engine().textures[id] = FL_TEXTURE(g_object_ref(texture));
  fake::Record("registrar.register id=" + std::to_string(id));
  return TRUE;
}

gboolean fl_texture_registrar_mark_texture_frame_available(FlTextureRegistrar*,
                                                           FlTexture* texture) {
  int64_t id = fl_texture_get_id(texture);
  std::lock_guard<std::mutex> lock(Engine().mutex);
  if (!Engine().textures.count(id)) {
    fake::Violation("mark_texture_frame_available on unregistered texture " +
                    std::to_string(id));
    return FALSE;
  }
  Engine().frameAvailable[id]++;
  fake::Record("registrar.mark id=" + std::to_string(id));
  return TRUE;
}

gboolean fl_texture_registrar_unregister_texture(FlTextureRegistrar*,
                                                 FlTexture* texture) {
  int64_t id = fl_texture_get_id(texture);
  FlTexture* owned = nullptr;
  {
    std::lock_guard<std::mutex> lock(Engine().mutex);
    auto it = Engine().textures.find(id);
    if (it == Engine().textures.end()) {
      fake::Violation("unregister of unregistered texture " + std::to_string(id));
      return FALSE;
    }
    owned = it->second;
    Engine().textures.erase(it);
  }
  fake::Record("registrar.unregister id=" + std::to_string(id));
  g_object_unref(owned);
  return TRUE;
}

FlTextureRegistrar* fl_plugin_registrar_get_texture_registrar(
    FlPluginRegistrar* registrar) {
  return registrar->textures;
}

FlView* fl_plugin_registrar_get_view(FlPluginRegistrar*) { return nullptr; }

FlBinaryMessenger* fl_plugin_registrar_get_messenger(FlPluginRegistrar* registrar) {
  return registrar->messenger;
}

// ---- Engine harness ------------------------------------------------------------

namespace fake {

void ResetEngine() {
  std::lock_guard<std::mutex> lock(Engine().mutex);
  // Textures still registered at reset belong to a previous test that failed
  // before cleanup. Leak them deliberately rather than finalize under test.
  Engine().textures.clear();
  Engine().frameAvailable.clear();
  Engine().nextId = 1;
  Engine().failNextRegistration = false;
  Engine().attempts.clear();  // Attempt records are leaked with their weak refs.
}

void ResetAll() {
  {
    std::lock_guard<std::mutex> lock(TheLog().mutex);
    TheLog().events.clear();
    TheLog().violations.clear();
  }
  ResetEglGl();
  ResetProducers();
  ResetEngine();
  thermion_flutter_render_context = EGL_NO_CONTEXT;
  thermion_flutter_render_display = EGL_NO_DISPLAY;
  thermion_flutter_render_api = EGL_NONE;
  thermion_flutter_render_gl_major = 0;
  thermion_flutter_render_gl_minor = 0;
}

void StartEngine() {
  auto& e = Engine();
  e.registrar =
      FL_TEXTURE_REGISTRAR(g_object_new(fl_texture_registrar_get_type(), nullptr));
  e.messenger = new _FlBinaryMessenger();
  _FlPluginRegistrar pluginRegistrar{e.registrar, e.messenger};
  thermion_flutter_plugin_register_with_registrar(&pluginRegistrar);
}

void StopEngine() {
  auto& e = Engine();
  if (e.messenger) {
    // Dropping the channel releases the handler's plugin reference, which
    // disposes the plugin.
    g_clear_object(&e.messenger->channel);
    delete e.messenger;
    e.messenger = nullptr;
  }
  PumpMainLoop();
  g_clear_object(&e.registrar);
}

FlMethodCall* Invoke(const char* method, FlValue* args) {
  auto* call = FL_METHOD_CALL(g_object_new(fl_method_call_get_type(), nullptr));
  call->name = g_strdup(method);
  call->args = args;
  FlMethodChannel* channel = Engine().messenger ? Engine().messenger->channel : nullptr;
  if (!channel || !channel->handler) {
    Violation(std::string("Invoke('") + method + "') with no channel handler");
    return call;
  }
  channel->handler(channel, call, channel->user_data);
  return call;
}

Response GetResponse(FlMethodCall* call) {
  Response r;
  r.responseCount = call->responseCount;
  if (!call->response) return r;
  auto* resp = call->response;
  r.success = resp->kind == kSuccess;
  r.notImplemented = resp->kind == kNotImplemented;
  if (resp->kind == kError && resp->code) r.errorCode = resp->code;
  if (resp->result) {
    if (resp->result->type == FL_VALUE_TYPE_INT) {
      r.hasInt = true;
      r.intValue = resp->result->i;
    } else if (resp->result->type == FL_VALUE_TYPE_LIST) {
      for (auto* v : resp->result->list) {
        r.intList.push_back(v->type == FL_VALUE_TYPE_INT ? v->i : 0);
      }
    }
  }
  return r;
}

FlValue* Int(int64_t value) { return fl_value_new_int(value); }

FlValue* IntList(std::initializer_list<int64_t> values) {
  FlValue* list = fl_value_new_list();
  for (auto v : values) fl_value_append_take(list, fl_value_new_int(v));
  return list;
}

FlTexture* LookupRaw(int64_t textureId) {
  std::lock_guard<std::mutex> lock(Engine().mutex);
  auto it = Engine().textures.find(textureId);
  return it == Engine().textures.end() ? nullptr : it->second;
}

PopulateResult PopulateRaw(FlTexture* texture) {
  PopulateResult result;
  if (!texture) return result;
  result.found = true;
  uint32_t width = 0, height = 0;
  GError* error = nullptr;
  auto* klass = FL_TEXTURE_GL_GET_CLASS(texture);
  result.ok = klass->populate(FL_TEXTURE_GL(texture), &result.target, &result.name,
                              &width, &height, &error);
  if (error) {
    result.error = error->message;
    g_error_free(error);
  }
  return result;
}

PopulateResult Populate(int64_t textureId) {
  return PopulateRaw(LookupRaw(textureId));
}

void OnRasterThread(const std::function<void()>& fn) {
  std::thread raster([&] {
    MakeFlutterRasterContextCurrent();
    fn();
    ReleaseCurrentContext();
  });
  raster.join();
}

bool IsRegistered(int64_t textureId) { return LookupRaw(textureId) != nullptr; }

int RegisteredCount() {
  std::lock_guard<std::mutex> lock(Engine().mutex);
  return static_cast<int>(Engine().textures.size());
}

int FrameAvailableCount(int64_t textureId) {
  std::lock_guard<std::mutex> lock(Engine().mutex);
  auto it = Engine().frameAvailable.find(textureId);
  return it == Engine().frameAvailable.end() ? 0 : it->second;
}

void FailNextRegistration() {
  std::lock_guard<std::mutex> lock(Engine().mutex);
  Engine().failNextRegistration = true;
}

int RegisterAttempts() {
  std::lock_guard<std::mutex> lock(Engine().mutex);
  return static_cast<int>(Engine().attempts.size());
}

bool AttemptFinalized(int attempt) {
  std::lock_guard<std::mutex> lock(Engine().mutex);
  return Engine().attempts.at(attempt)->finalized;
}

void PumpMainLoop() {
  while (g_main_context_iteration(nullptr, FALSE)) {
  }
}

}  // namespace fake
