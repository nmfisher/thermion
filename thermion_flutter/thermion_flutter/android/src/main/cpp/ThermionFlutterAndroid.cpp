#include <android/log.h>
#include <android/native_activity.h>
#include <android/native_window_jni.h>
#include <jni.h>

#include <dlfcn.h>
#include <android/log.h>

typedef void (*JNI_OnLoad_Func)(JavaVM*);

extern "C" {
JNIEXPORT jlong JNICALL
Java_dev_thermion_android_NativeWindowHelper_00024Companion_getNativeWindowFromSurface(
    JNIEnv *env, jclass clazz, jobject surface) {
  ANativeWindow *window = ANativeWindow_fromSurface(env, surface);
  return (jlong)window;
}

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {

     void* filamentLib = dlopen("libthermion_dart.so", RTLD_NOW);
     if (!filamentLib) {
         __android_log_print(ANDROID_LOG_ERROR, "thermion_android", 
                            "Failed to load Filament library: %s", dlerror());
         return false;
     }
     
     dlerror();
     
     JNI_OnLoad_Func vmEnvOnLoad = (JNI_OnLoad_Func)dlsym(filamentLib, 
                                   "_ZN8filament17VirtualMachineEnv10JNI_OnLoadEP7_JavaVM");
     
     // Check for errors
     const char* dlsym_error = dlerror();
     if (dlsym_error) {
         __android_log_print(ANDROID_LOG_ERROR, "thermion_android", 
                            "Failed to find VirtualMachineEnv::JNI_OnLoad: %s", dlsym_error);
         dlclose(filamentLib);
         return false;
     }
     
     // Call the function
     vmEnvOnLoad(vm);
     
    
  JNIEnv *env;
  if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
    return JNI_ERR;
  }

  jclass c =
      env->FindClass("dev/thermion/android/NativeWindowHelper$Companion");
  if (c == nullptr)
    return JNI_ERR;

  static const JNINativeMethod methods[] = {
      {"getNativeWindowFromSurface", "(Landroid/view/Surface;)J",
       reinterpret_cast<void *>(
           Java_dev_thermion_android_NativeWindowHelper_00024Companion_getNativeWindowFromSurface)},
  };
  int rc = env->RegisterNatives(c, methods,
                                sizeof(methods) / sizeof(JNINativeMethod));
  if (rc != JNI_OK)
    return rc;

  return JNI_VERSION_1_6;
}
}
