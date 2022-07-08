#include "FilamentViewer.hpp"
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <android/native_window_jni.h>
#include <android/log.h>

void load_skybox(void* viewer, const char* skyboxPath, const char* iblPath);

void* filament_viewer_new(
    void* layer, 
    void* assetManager
);
}