#ifndef FLUTTER_PLUGIN_FLUTTER_FILAMENT_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_FILAMENT_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>
#include <epoxy/gl.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

typedef struct _ThermionFlutterPlugin ThermionFlutterPlugin;
typedef struct {
  GObjectClass parent_class;
} ThermionFlutterPluginClass;

FLUTTER_PLUGIN_EXPORT GType thermion_flutter_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void thermion_flutter_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_FLUTTER_FILAMENT_PLUGIN_H_
