#include "include/thermion_flutter/thermion_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "thermion_flutter_plugin.h"

void ThermionFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  thermion_flutter::ThermionFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
