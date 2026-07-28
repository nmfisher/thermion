#ifdef __ANDROID__

#include "c_api/APIExport.h"

#include <jni.h>

// Filament does not publish a header for this Android initialization hook.
// Give its existing C++ symbol a local C identifier without duplicating
// Filament's private VirtualMachineEnv class definition.
extern "C" void filamentVirtualMachineEnvOnLoad(JavaVM* vm)
        __asm__("_ZN8filament17VirtualMachineEnv10JNI_OnLoadEP7_JavaVM");

extern "C" EMSCRIPTEN_KEEPALIVE void
Thermion_filament_JNI_OnLoad(JavaVM* vm) noexcept {
    filamentVirtualMachineEnvOnLoad(vm);
}

#endif
