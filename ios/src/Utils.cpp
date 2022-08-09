/*
 * Copyright (C) 2020 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <jni.h>

#include <filament/Engine.h>
#include <filament/IndirectLight.h>
#include <filament/Skybox.h>

#include <image/KtxUtility.h>

#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>

#include "common/NioUtils.h"

#include <android/log.h>

using namespace filament;
using namespace filament::math;
using namespace image;

jlong nCreateHDRTexture(JNIEnv* env, jclass,
        jlong nativeEngine, jobject javaBuffer, jint remaining, jint internalFormat);

static jlong nCreateKTXTexture(JNIEnv* env, jclass,
        jlong nativeEngine, jobject javaBuffer, jint remaining, jboolean srgb) {
    Engine* engine = (Engine*) nativeEngine;
    AutoBuffer buffer(env, javaBuffer, remaining);
    KtxBundle* bundle = new KtxBundle((const uint8_t*) buffer.getData(), buffer.getSize());
    return (jlong) ktx::createTexture(engine, *bundle, srgb, [](void* userdata) {
        KtxBundle* bundle = (KtxBundle*) userdata;
        delete bundle;
    }, bundle);
}

static jlong nCreateIndirectLight(JNIEnv* env, jclass,
        jlong nativeEngine, jobject javaBuffer, jint remaining, jboolean srgb) {
    Engine* engine = (Engine*) nativeEngine;
    AutoBuffer buffer(env, javaBuffer, remaining);
    KtxBundle* bundle = new KtxBundle((const uint8_t*) buffer.getData(), buffer.getSize());
    Texture* cubemap = ktx::createTexture(engine, *bundle, srgb,  [](void* userdata) {
        KtxBundle* bundle = (KtxBundle*) userdata;
        delete bundle;
    }, bundle);

    float3 harmonics[9];
    bundle->getSphericalHarmonics(harmonics);

    IndirectLight* indirectLight = IndirectLight::Builder()
        .reflections(cubemap)
        .irradiance(3, harmonics)
        .intensity(30000)
        .build(*engine);

    return (jlong) indirectLight;
}

static jlong nCreateSkybox(JNIEnv* env, jclass,
        jlong nativeEngine, jobject javaBuffer, jint remaining, jboolean srgb, jobject assetManager, jstring outpath) {

    AAssetManager *mgr = AAssetManager_fromJava(env, assetManager);

    AAsset *asset = AAssetManager_open(mgr, "envs/default_env/default_env_skybox.ktx", AASSET_MODE_BUFFER);
    if(asset == nullptr) {
      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Couldn't open asset");
      return 0;
    }

    off_t length = AAsset_getLength(asset);
    const void * buffer = AAsset_getBuffer(asset);
    jboolean isCopy = (jboolean)false;
    const char* out_cstr = env->GetStringUTFChars(outpath, &isCopy);

    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Opening outfile %s for writing", out_cstr);

    FILE* outfile = fopen(out_cstr, "w");

    fwrite(buffer, 1, length, outfile);

    fclose(outfile);

    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Closed outfile %s", out_cstr);

    Engine* engine = (Engine*) nativeEngine;
    // __android_log_print(ANDROID_LOG_VERBOSE, "UTILS", "CREATing autobuffer");     
    // AutoBuffer buffer(env, javaBuffer, remaining);
    // __android_log_print(ANDROID_LOG_VERBOSE, "UTILS", "CREATied autobuffer");     
    
    KtxBundle* bundle = new KtxBundle((const uint8_t*) buffer, length);
    // KtxBundle* bundle = new KtxBundle((const uint8_t*) buffer.getData(), buffer.getSize());
    __android_log_print(ANDROID_LOG_VERBOSE, "UTILS", "CREATED BUNDLE FROM API");     


    Texture* cubemap = ktx::createTexture(engine, *bundle, srgb,  [](void* userdata) {
        KtxBundle* bundle = (KtxBundle*) userdata;
        delete bundle;
    }, bundle);
    __android_log_print(ANDROID_LOG_VERBOSE, "UTILS", "CREATED TEXTURE");     
    return (jlong) Skybox::Builder().environment(cubemap).showSun(true).build(*engine);
}

static jboolean nGetSphericalHarmonics(JNIEnv* env, jclass, jobject javaBuffer, jint remaining,
        jfloatArray outSphericalHarmonics_) {
    AutoBuffer buffer(env, javaBuffer, remaining);
    KtxBundle bundle((const uint8_t*) buffer.getData(), buffer.getSize());

    jfloat* outSphericalHarmonics = env->GetFloatArrayElements(outSphericalHarmonics_, nullptr);
    const auto success = bundle.getSphericalHarmonics(
        reinterpret_cast<filament::math::float3*>(outSphericalHarmonics)
    );
    env->ReleaseFloatArrayElements(outSphericalHarmonics_, outSphericalHarmonics, JNI_ABORT);

    return success ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void*) {
    JNIEnv* env;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return -1;
    }

    int rc;

    // KTXLoader
    jclass ktxloaderClass = env->FindClass("app/polyvox/filament/KTXLoader2");
    if (ktxloaderClass == nullptr) return JNI_ERR;
    static const JNINativeMethod ktxMethods[] = {
        {(char*)"nCreateKTXTexture", (char*)"(JLjava/nio/Buffer;IZ)J", reinterpret_cast<void*>(nCreateKTXTexture)},
        {(char*)"nCreateIndirectLight", (char*)"(JLjava/nio/Buffer;IZ)J", reinterpret_cast<void*>(nCreateIndirectLight)},
        {(char*)"nCreateSkybox", (char*)"(JLjava/nio/Buffer;IZLandroid/content/res/AssetManager;Ljava/lang/String;)J", reinterpret_cast<void*>(nCreateSkybox)},
        {(char*)"nGetSphericalHarmonics", (char*)"(Ljava/nio/Buffer;I[F)Z", reinterpret_cast<void*>(nGetSphericalHarmonics)},
    };
    rc = env->RegisterNatives(ktxloaderClass, ktxMethods, sizeof(ktxMethods) / sizeof(JNINativeMethod));
    if (rc != JNI_OK) return rc;

    // HDRLoader
    jclass hdrloaderClass = env->FindClass("com/google/android/filament/utils/HDRLoader");
    if (hdrloaderClass == nullptr) return JNI_ERR;
    static const JNINativeMethod hdrMethods[] = {
        {(char*)"nCreateHDRTexture", (char*)"(JLjava/nio/Buffer;II)J", reinterpret_cast<void*>(nCreateHDRTexture)},
    };
    rc = env->RegisterNatives(hdrloaderClass, hdrMethods, sizeof(hdrMethods) / sizeof(JNINativeMethod));
    if (rc != JNI_OK) return rc;

    return JNI_VERSION_1_6;
}
