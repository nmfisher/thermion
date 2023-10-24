//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <polyvox_filament/polyvox_filament_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  PolyvoxFilamentPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PolyvoxFilamentPluginCApi"));
}
