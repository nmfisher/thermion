#include "c_api/TMaterialCompiler.h"

// Runtime material compilation is opt-in: it links filamat (MaterialBuilder,
// glslang, SPIRV-Tools) into libthermion_dart, which adds tens of MB to the
// binary. The build hook defines THERMION_ENABLE_RUNTIME_MATERIALS when the
// consuming app sets `runtime_materials: true` under
// hooks.user_defines.thermion_dart in its pubspec.yaml. With the define
// absent, this translation unit still exports the same symbols (as no-ops),
// so the Dart bindings are identical either way and code running on both
// builds can feature-detect via MaterialCompiler_isSupported().
#ifdef THERMION_ENABLE_RUNTIME_MATERIALS

#include "c_api/TEngine.h"
#include "rendering/JobThread.hpp"

#include <filamat/MaterialBuilder.h>
#include <filament/Engine.h>

#include <cstring>
#include <future>
#include <mutex>
#include <new>
#include <vector>

namespace thermion
{
    extern "C"
    {

        namespace
        {

            // filamat::MaterialBuilder::init/shutdown configure process-global
            // state (glslang/SPIRV machinery), so builds are serialized and
            // each call brackets build() with a matched init/shutdown pair.
            std::mutex &compilerMutex()
            {
                static std::mutex mutex;
                return mutex;
            }

            struct PackagePayload
            {
                std::vector<uint8_t> bytes;
            };

            filamat::MaterialBuilder::Platform platformForThisBuild()
            {
#if defined(__APPLE__) || defined(__linux__) || defined(_WIN32)
                // Desktop shader models, matching the precompiled Thermion
                // materials for these targets.
                return filamat::MaterialBuilder::Platform::DESKTOP;
#elif defined(__EMSCRIPTEN__) || defined(__ANDROID__) || defined(__arm__) || defined(__aarch64__)
                return filamat::MaterialBuilder::Platform::MOBILE;
#else
                return filamat::MaterialBuilder::Platform::DESKTOP;
#endif
            }

            filamat::MaterialBuilder::TargetApi targetApiForThisBuild()
            {
#if defined(__APPLE__)
                // iOS/macOS are Metal-only.
                return filamat::MaterialBuilder::TargetApi::METAL;
#elif defined(__ANDROID__) || defined(__linux__) || defined(_WIN32)
                // Matches the precompiled Thermion materials: Vulkan + OpenGL.
                return static_cast<filamat::MaterialBuilder::TargetApi>(
                    uint8_t(filamat::MaterialBuilder::TargetApi::VULKAN) |
                    uint8_t(filamat::MaterialBuilder::TargetApi::OPENGL));
#else
                return filamat::MaterialBuilder::TargetApi::ALL;
#endif
            }

            filamat::MaterialBuilder::Shading toFilamatShading(TShading shading)
            {
                switch (shading)
                {
                case SHADING_UNLIT:
                    return filamat::MaterialBuilder::Shading::UNLIT;
                case SHADING_SUBSURFACE:
                    return filamat::MaterialBuilder::Shading::SUBSURFACE;
                case SHADING_CLOTH:
                    return filamat::MaterialBuilder::Shading::CLOTH;
                case SHADING_SPECULAR_GLOSSINESS:
                    return filamat::MaterialBuilder::Shading::SPECULAR_GLOSSINESS;
                case SHADING_LIT:
                default:
                    return filamat::MaterialBuilder::Shading::LIT;
                }
            }

            TMaterialCompilerPackage *compileLocked(
                filament::Engine *engine, const char *name,
                const char *materialSource, TShading shading)
            {
                if (materialSource == nullptr)
                {
                    return nullptr;
                }

                std::lock_guard<std::mutex> lock(compilerMutex());

                filamat::MaterialBuilder builder;
                builder.name(name ? name : "runtime_material")
                    .material(materialSource)
                    .shading(toFilamatShading(shading))
                    .platform(platformForThisBuild())
                    .targetApi(targetApiForThisBuild())
                    .optimization(filamat::MaterialBuilder::Optimization::PERFORMANCE);

                filamat::MaterialBuilder::init();

                filamat::Package package = builder.build(engine->getJobSystem());

                filamat::MaterialBuilder::shutdown();

                if (!package.isValid())
                {
                    return nullptr;
                }

                PackagePayload *payload = new (std::nothrow) PackagePayload();
                if (payload == nullptr)
                {
                    return nullptr;
                }
                payload->bytes.assign(package.getData(), package.getData() + package.getSize());
                return reinterpret_cast<TMaterialCompilerPackage *>(payload);
            }

        } // namespace

        EMSCRIPTEN_KEEPALIVE uint8_t MaterialCompiler_isSupported() { return 1; }

        EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialSource(
            TJobThread *tJobThread, TEngine *tEngine, const char *name, const char *materialSource, TShading shading)
        {
            if (tJobThread == nullptr || tEngine == nullptr)
            {
                return nullptr;
            }
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *jobThread = reinterpret_cast<JobThread *>(tJobThread);

            // Runs the CPU-bound compile on the job thread that created the
            // engine. MaterialBuilder::build drives the engine's JobSystem,
            // whose calling thread must have been adopted — true of the
            // engine-creating job thread (FEngine's constructor adopts its
            // creator), but not of an arbitrary Dart/native caller thread.
            // The packaged-task future blocks the submitting thread until the
            // job thread finishes, matching the other *JobThread entry points.
            std::packaged_task<TMaterialCompilerPackage *()> task(
                [engine, name, materialSource, shading]
                {
                    return compileLocked(engine, name, materialSource, shading);
                });
            auto future = jobThread->addTask(task);
            return future.get();
        }

        EMSCRIPTEN_KEEPALIVE size_t MaterialCompiler_getPackageSize(TMaterialCompilerPackage *package)
        {
            auto *payload = reinterpret_cast<PackagePayload *>(package);
            return payload == nullptr ? 0 : payload->bytes.size();
        }

        EMSCRIPTEN_KEEPALIVE size_t MaterialCompiler_getPackageBytes(
            TMaterialCompilerPackage *package, uint8_t *out, size_t capacity)
        {
            auto *payload = reinterpret_cast<PackagePayload *>(package);
            if (payload == nullptr || out == nullptr || capacity == 0)
            {
                return 0;
            }
            const size_t n = payload->bytes.size() < capacity ? payload->bytes.size() : capacity;
            std::memcpy(out, payload->bytes.data(), n);
            return n;
        }

        EMSCRIPTEN_KEEPALIVE void MaterialCompiler_destroyPackage(TMaterialCompilerPackage *package)
        {
            delete reinterpret_cast<PackagePayload *>(package);
        }

    } // extern "C"
} // namespace thermion

#else // THERMION_ENABLE_RUNTIME_MATERIALS

extern "C"
{

    EMSCRIPTEN_KEEPALIVE uint8_t MaterialCompiler_isSupported() { return 0; }

    EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialSource(
        TJobThread *tJobThread, TEngine *tEngine, const char *name, const char *materialSource, TShading shading)
    {
        (void)tJobThread;
        (void)tEngine;
        (void)name;
        (void)materialSource;
        (void)shading;
        return nullptr;
    }

    EMSCRIPTEN_KEEPALIVE size_t MaterialCompiler_getPackageSize(TMaterialCompilerPackage *package)
    {
        (void)package;
        return 0;
    }

    EMSCRIPTEN_KEEPALIVE size_t MaterialCompiler_getPackageBytes(
        TMaterialCompilerPackage *package, uint8_t *out, size_t capacity)
    {
        (void)package;
        (void)out;
        (void)capacity;
        return 0;
    }

    EMSCRIPTEN_KEEPALIVE void MaterialCompiler_destroyPackage(TMaterialCompilerPackage *package)
    {
        (void)package;
    }

}

#endif // THERMION_ENABLE_RUNTIME_MATERIALS
