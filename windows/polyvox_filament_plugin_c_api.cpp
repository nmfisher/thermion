#include "include/polyvox_filament/polyvox_filament_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "polyvox_filament_plugin.h"

void PolyvoxFilamentPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  polyvox_filament::PolyvoxFilamentPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
