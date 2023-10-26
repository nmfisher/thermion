#include "include/flutter_filament/flutter_filament_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_filament_plugin.h"

void FlutterFilamentPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_filament::FlutterFilamentPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
