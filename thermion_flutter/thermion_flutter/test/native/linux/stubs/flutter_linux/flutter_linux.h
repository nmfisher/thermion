// Minimal stand-in for the Flutter Linux embedder API used by the
// thermion_flutter Linux plugin. Implemented by fakes/fake_flutter.cc.
//
// Only the subset of the API the plugin calls is declared. Types that the
// plugin subclasses or embeds by value (FlTextureGL, FlTextureGLClass) match
// the real layout: a GObject instance and a GObjectClass followed by the
// populate vfunc.
#pragma once

#include <glib-object.h>
#include <stdint.h>

G_BEGIN_DECLS

// --- FlValue ----------------------------------------------------------------

typedef enum {
  FL_VALUE_TYPE_NULL,
  FL_VALUE_TYPE_BOOL,
  FL_VALUE_TYPE_INT,
  FL_VALUE_TYPE_FLOAT,
  FL_VALUE_TYPE_STRING,
  FL_VALUE_TYPE_UINT8_LIST,
  FL_VALUE_TYPE_INT32_LIST,
  FL_VALUE_TYPE_INT64_LIST,
  FL_VALUE_TYPE_FLOAT_LIST,
  FL_VALUE_TYPE_LIST,
  FL_VALUE_TYPE_MAP,
} FlValueType;

typedef struct _FlValue FlValue;

FlValue* fl_value_new_null(void);
FlValue* fl_value_new_int(int64_t value);
FlValue* fl_value_new_list(void);
FlValue* fl_value_ref(FlValue* value);
void fl_value_unref(FlValue* value);
FlValueType fl_value_get_type(FlValue* value);
int64_t fl_value_get_int(FlValue* value);
size_t fl_value_get_length(FlValue* value);
FlValue* fl_value_get_list_value(FlValue* value, size_t index);
void fl_value_append_take(FlValue* list, FlValue* child);

G_DEFINE_AUTOPTR_CLEANUP_FUNC(FlValue, fl_value_unref)

// --- Method responses -------------------------------------------------------

G_DECLARE_FINAL_TYPE(FlMethodResponse, fl_method_response, FL, METHOD_RESPONSE,
                     GObject)
// The real embedder has one subclass per response kind. The plugin only
// passes them on as FlMethodResponse, so one concrete type is enough.
typedef FlMethodResponse FlMethodSuccessResponse;
typedef FlMethodResponse FlMethodErrorResponse;
typedef FlMethodResponse FlMethodNotImplementedResponse;

FlMethodSuccessResponse* fl_method_success_response_new(FlValue* result);
FlMethodErrorResponse* fl_method_error_response_new(const gchar* code,
                                                    const gchar* message,
                                                    FlValue* details);
FlMethodNotImplementedResponse* fl_method_not_implemented_response_new(void);

// --- Method calls and channels ----------------------------------------------

G_DECLARE_FINAL_TYPE(FlMethodCall, fl_method_call, FL, METHOD_CALL, GObject)

const gchar* fl_method_call_get_name(FlMethodCall* method_call);
FlValue* fl_method_call_get_args(FlMethodCall* method_call);
gboolean fl_method_call_respond(FlMethodCall* method_call,
                                FlMethodResponse* response,
                                GError** error);

typedef struct _FlBinaryMessenger FlBinaryMessenger;
typedef struct _FlMethodCodec FlMethodCodec;
#define FL_METHOD_CODEC(obj) ((FlMethodCodec*)(obj))

G_DECLARE_FINAL_TYPE(FlStandardMethodCodec, fl_standard_method_codec, FL,
                     STANDARD_METHOD_CODEC, GObject)
FlStandardMethodCodec* fl_standard_method_codec_new(void);

G_DECLARE_FINAL_TYPE(FlMethodChannel, fl_method_channel, FL, METHOD_CHANNEL,
                     GObject)
typedef void (*FlMethodChannelMethodCallHandler)(FlMethodChannel* channel,
                                                 FlMethodCall* method_call,
                                                 gpointer user_data);
FlMethodChannel* fl_method_channel_new(FlBinaryMessenger* messenger,
                                       const gchar* name,
                                       FlMethodCodec* codec);
void fl_method_channel_set_method_call_handler(
    FlMethodChannel* channel,
    FlMethodChannelMethodCallHandler handler,
    gpointer user_data,
    GDestroyNotify destroy_notify);

// --- Textures ---------------------------------------------------------------

G_DECLARE_INTERFACE(FlTexture, fl_texture, FL, TEXTURE, GObject)
struct _FlTextureInterface {
  GTypeInterface g_iface;
};
int64_t fl_texture_get_id(FlTexture* texture);

G_DECLARE_DERIVABLE_TYPE(FlTextureGL, fl_texture_gl, FL, TEXTURE_GL, GObject)
struct _FlTextureGLClass {
  GObjectClass parent_class;
  gboolean (*populate)(FlTextureGL* texture,
                       uint32_t* target,
                       uint32_t* name,
                       uint32_t* width,
                       uint32_t* height,
                       GError** error);
  gpointer padding[8];
};

G_DECLARE_FINAL_TYPE(FlTextureRegistrar, fl_texture_registrar, FL,
                     TEXTURE_REGISTRAR, GObject)
gboolean fl_texture_registrar_register_texture(FlTextureRegistrar* registrar,
                                               FlTexture* texture);
gboolean fl_texture_registrar_mark_texture_frame_available(
    FlTextureRegistrar* registrar,
    FlTexture* texture);
gboolean fl_texture_registrar_unregister_texture(FlTextureRegistrar* registrar,
                                                 FlTexture* texture);

// --- Plugin registrar -------------------------------------------------------

typedef struct _FlView FlView;
typedef struct _FlPluginRegistrar FlPluginRegistrar;
FlTextureRegistrar* fl_plugin_registrar_get_texture_registrar(
    FlPluginRegistrar* registrar);
FlView* fl_plugin_registrar_get_view(FlPluginRegistrar* registrar);
FlBinaryMessenger* fl_plugin_registrar_get_messenger(
    FlPluginRegistrar* registrar);

G_END_DECLS
