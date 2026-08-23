//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <thermion_flutter/thermion_flutter_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) thermion_flutter_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "ThermionFlutterPlugin");
  thermion_flutter_plugin_register_with_registrar(thermion_flutter_registrar);
}
