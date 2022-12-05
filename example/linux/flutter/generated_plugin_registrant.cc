//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <polyvox_filament/polyvox_filament_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) polyvox_filament_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "PolyvoxFilamentPlugin");
  polyvox_filament_plugin_register_with_registrar(polyvox_filament_registrar);
}
