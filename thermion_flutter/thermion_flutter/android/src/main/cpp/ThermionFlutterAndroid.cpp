#include <android/native_window_jni.h>
#include <android/native_activity.h>
#include <jni.h>

extern "C" {
    JNIEXPORT jlong JNICALL Java_dev_thermion_android_NativeWindowHelper_00024Companion_getNativeWindowFromSurface(
        JNIEnv* env, 
        jclass clazz, 
        jobject surface
    ) {
        ANativeWindow* window = ANativeWindow_fromSurface(env, surface);
        return (jlong)window; 
    }
}


