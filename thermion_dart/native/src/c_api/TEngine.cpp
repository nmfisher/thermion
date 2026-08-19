#ifdef __EMSCRIPTEN__
#include <emscripten/html5.h>
#include "ThermionWebApi.h"
#include <backend/platforms/PlatformWebGL.h>
#endif

#include "c_api/TEngine.h"

#include <filament/Camera.h>
#include <backend/DriverEnums.h>
#include <filament/DebugRegistry.h>
#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/IndirectLight.h>
#include <filament/Material.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/View.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>
#include <gltfio/math.h>
#include <gltfio/materials/uberarchive.h>

#include <imageio/ImageDecoder.h>
#include <imageio/ImageEncoder.h>
#include <image/ColorTransform.h>

#include <utils/EntityManager.h>
#include <utils/NameComponentManager.h>

#ifdef THERMION_RUNTIME_MATERIAL_COMPILE
#include <filamat/MaterialBuilder.h>
#include <filamat/Package.h>
#include <filament-matp/Config.h>
#include <filament-matp/MaterialParser.h>
#include <utils/Status.h>

// The prebuilt artifact's include tree does not ship utils/JobSystem.h; a
// forward declaration is all Engine_compileMaterial needs (it only passes
// engine->getJobSystem() by reference).
namespace utils
{
    class JobSystem;
}

#include <cstring>
#include <cstdio>
#include <memory>
#include <mutex>
#include <string>
#include <vector>
#endif

#include "Log.hpp"
#include "MathUtils.hpp"

namespace thermion
{

    void writeError(char *outError, size_t outErrorCap, const char *message)
    {
        if (outError == nullptr || outErrorCap == 0)
        {
            return;
        }
        snprintf(outError, outErrorCap, "%s", message);
    }
#ifdef THERMION_RUNTIME_MATERIAL_COMPILE
    // =====================================================================
    // Runtime material compilation (Phase 1 of
    // docs/research/runtime-material-compile.md).
    //
    // The proven sequence, mirroring matc: MaterialBuilder::init() once,
    // matp::MaterialParser::parse() of the (already include-resolved)
    // source into a MaterialBuilder, then MaterialBuilder::build() on the
    // engine's JobSystem.
    // =====================================================================

    /// Minimal matp::Config for runtime compilation. matc fills this from
    /// command-line flags; we only need the platform/target/optimization
    /// selection — output/input sinks and the string forms are unused by
    /// MaterialParser::parse.
    class RuntimeMaterialConfig : public matp::Config
    {
    public:
        RuntimeMaterialConfig(
            Platform platform,
            TargetApi targetApi,
            Optimization optimization,
            bool includeSourceMaterial)
        {
            mPlatform = platform;
            mTargetApi = targetApi;
            mOptimizationLevel = optimization;
            mIncludeSourceMaterial = includeSourceMaterial;
            // Engine_create pins the engine to FEATURE_LEVEL_1; generate
            // for the same level so packages always load.
            mFeatureLevel = filament::backend::FeatureLevel::FEATURE_LEVEL_1;
        }

        Output *getOutput() const noexcept override { return nullptr; }
        Input *getInput() const noexcept override { return nullptr; }
        std::string toString() const noexcept override { return "thermion_runtime_compile"; }
        std::string toPIISafeString() const noexcept override { return "thermion_runtime_compile"; }
    };

    /// Serializes every compile. MaterialBuilder::init()/shutdown() are
    /// refcounted but glslang's global initialization is not thread-safe,
    /// so the first init and all builds share one mutex. We never call
    /// shutdown — the builder state lives for the process lifetime, which
    /// also removes any racing with a concurrent engine teardown.
    std::mutex &materialCompileMutex()
    {
        static std::mutex mutex;
        return mutex;
    }

    /// Parses a flat JSON object of string -> string, e.g.
    /// {"OCCLUSION": "1", "TINT": "0.5"}. Accepts whitespace between
    /// tokens and the backslash escapes \" \\ \/ \n \t \r. Returns false
    /// on malformed input (the whole compile then fails with an error
    /// pointing at the defines).
    bool parseDefinesJson(const char *json, std::vector<std::pair<std::string, std::string>> &out)
    {
        const char *p = json;
        auto skipWhitespace = [&p]()
        {
            while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')
            {
                p++;
            }
        };
        auto parseString = [&](std::string &result) -> bool
        {
            if (*p != '"')
            {
                return false;
            }
            p++;
            result.clear();
            while (*p != '"')
            {
                if (*p == '\0')
                {
                    return false;
                }
                if (*p == '\\')
                {
                    p++;
                    switch (*p)
                    {
                        case '"': result += '"'; break;
                        case '\\': result += '\\'; break;
                        case '/': result += '/'; break;
                        case 'n': result += '\n'; break;
                        case 't': result += '\t'; break;
                        case 'r': result += '\r'; break;
                        default: return false;
                    }
                }
                else
                {
                    result += *p;
                }
                p++;
            }
            p++; // closing quote
            return true;
        };

        skipWhitespace();
        if (*p != '{')
        {
            return false;
        }
        p++;
        skipWhitespace();
        if (*p == '}')
        {
            return true;
        }
        while (true)
        {
            skipWhitespace();
            std::string key;
            if (!parseString(key))
            {
                return false;
            }
            skipWhitespace();
            if (*p != ':')
            {
                return false;
            }
            p++;
            skipWhitespace();
            std::string value;
            if (!parseString(value))
            {
                return false;
            }
            out.emplace_back(std::move(key), std::move(value));
            skipWhitespace();
            if (*p == ',')
            {
                p++;
                continue;
            }
            if (*p == '}')
            {
                return true;
            }
            return false;
        }
    }

#endif

}

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;

        // Defined in ThermionDartRenderThreadApi.cpp. Direct-API getters use
        // these to record which render thread owns an engine-scoped object
        // (and which canvas the active thread's engine renders to).
        void RenderThread_registerOwnerFromOwner(void *owner, void *knownOwner);
        const char *RenderThread_getActiveCanvasSelector();
#endif


        EMSCRIPTEN_KEEPALIVE uint64_t TSWAP_CHAIN_CONFIG_TRANSPARENT = filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT;
        EMSCRIPTEN_KEEPALIVE uint64_t TSWAP_CHAIN_CONFIG_READABLE = filament::backend::SWAP_CHAIN_CONFIG_READABLE;
        EMSCRIPTEN_KEEPALIVE uint64_t TSWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER = filament::backend::SWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER;
        EMSCRIPTEN_KEEPALIVE uint64_t TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER = filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;

        EMSCRIPTEN_KEEPALIVE TEngine *Engine_create(
            TBackend backend,
            void* tPlatform,
            void* tSharedContext,
            uint8_t stereoscopicEyeCount,
            bool disableHandleUseAfterFreeCheck)
        {
            #ifdef __EMSCRIPTEN__
            // Engine_create runs inside the engine's RenderThread task, so the
            // active thread IS this engine's thread — create the WebGL context
            // on the canvas that was transferred to it.
            auto handle = Thermion_createGLContext(RenderThread_getActiveCanvasSelector());
            tSharedContext = (void*)handle;
            tPlatform = (backend::Platform *)new filament::backend::PlatformWebGL();
            #endif
            filament::Engine::Config config;
            config.stereoscopicEyeCount = stereoscopicEyeCount;
            config.disableHandleUseAfterFreeCheck = disableHandleUseAfterFreeCheck;

            auto *platform = reinterpret_cast<filament::backend::Platform *>(tPlatform);
                  
            auto *engine = filament::Engine::Builder()
                .backend(static_cast<filament::Engine::Backend>(backend))
                .platform(platform)
                .featureLevel(filament::Engine::FeatureLevel::FEATURE_LEVEL_1)
                .sharedContext(tSharedContext)
                .config(&config)
                .build();
            
            return reinterpret_cast<TEngine *>(engine);
        }

        EMSCRIPTEN_KEEPALIVE TFeatureLevel Engine_getSupportedFeatureLevel(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto featureLevel = engine->getSupportedFeatureLevel();
            switch(featureLevel) {
                case filament::backend::FeatureLevel::FEATURE_LEVEL_0:
                    return FEATURE_LEVEL_0;
                case filament::backend::FeatureLevel::FEATURE_LEVEL_1:
                    return FEATURE_LEVEL_1;
                case filament::backend::FeatureLevel::FEATURE_LEVEL_2:
                    return FEATURE_LEVEL_2;
                case filament::backend::FeatureLevel::FEATURE_LEVEL_3:
                    return FEATURE_LEVEL_3;
            }
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroy(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            Engine::destroy(engine);
            TRACE("Engine destroyed");
        }

        EMSCRIPTEN_KEEPALIVE TRenderer *Engine_createRenderer(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *renderer = engine->createRenderer();
            return reinterpret_cast<TRenderer *>(renderer);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyRenderer(TEngine *tEngine, TRenderer *tRenderer)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *renderer = reinterpret_cast<Renderer *>(tRenderer);
            engine->destroy(renderer);
        }

        EMSCRIPTEN_KEEPALIVE TSwapChain *Engine_createSwapChain(TEngine *tEngine, void *window, uint64_t flags)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            #ifdef ENABLE_TRACING
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT) == filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT) {
                TRACE("SWAP_CHAIN_CONFIG_TRANSPARENT");
                
            }
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_READABLE) == filament::backend::SWAP_CHAIN_CONFIG_READABLE) {
                TRACE("SWAP_CHAIN_CONFIG_READABLE");
            }
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER) == filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER) {
                TRACE("SWAP_CHAIN_CONFIG_READABLE");
            }
            #endif
            auto *swapChain = engine->createSwapChain(window, flags);
            return reinterpret_cast<TSwapChain *>(swapChain);
        }

        EMSCRIPTEN_KEEPALIVE TSwapChain *Engine_createHeadlessSwapChain(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags)
        {
            TRACE("Creating headless swapchain %dx%d, flags %flags", width, height, flags);
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *swapChain = engine->createSwapChain(width, height, flags);
            #ifdef ENABLE_TRACING
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT) == filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT) {
                TRACE("SWAP_CHAIN_CONFIG_TRANSPARENT");
            }
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_READABLE) == filament::backend::SWAP_CHAIN_CONFIG_READABLE) {
                TRACE("SWAP_CHAIN_CONFIG_READABLE");
            }
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER) == filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER) {
                TRACE("SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER");
            }
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER) == filament::backend::SWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER) {
                TRACE("SWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER");
            }
            #endif
            return reinterpret_cast<TSwapChain *>(swapChain);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChain(TEngine *tEngine, TSwapChain *tSwapChain) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *swapChain = reinterpret_cast<SwapChain *>(tSwapChain);
            engine->destroy(swapChain);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyView(TEngine *tEngine, TView *tView) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *view = reinterpret_cast<View *>(tView);
            engine->destroy(view);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyScene(TEngine *tEngine, TScene *tScene) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *scene = reinterpret_cast<Scene *>(tScene);
            engine->destroy(scene);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyColorGrading(TEngine *tEngine, TColorGrading *tColorGrading) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *colorGrading = reinterpret_cast<ColorGrading *>(tColorGrading);
            engine->destroy(colorGrading);
        }

        EMSCRIPTEN_KEEPALIVE TView *Engine_createView(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *view = engine->createView();
            view->setShadowingEnabled(false);
            view->setAmbientOcclusionOptions({.enabled = false});
            view->setDynamicResolutionOptions({.enabled = false});
            return reinterpret_cast<TView *>(view);
        }

        EMSCRIPTEN_KEEPALIVE TTransformManager *Engine_getTransformManager(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &transformManager = engine->getTransformManager();
            // Direct-API getters run on the main thread; record which render
            // thread owns this manager so RenderThread dispatch can route to it.
            RenderThread_registerOwnerFromOwner(&transformManager, tEngine);
            return reinterpret_cast<TTransformManager *>(&transformManager);
        }

        EMSCRIPTEN_KEEPALIVE TRenderableManager *Engine_getRenderableManager(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &renderableManager = engine->getRenderableManager();
            RenderThread_registerOwnerFromOwner(&renderableManager, tEngine);
            return reinterpret_cast<TRenderableManager *>(&renderableManager);
        }

        EMSCRIPTEN_KEEPALIVE TLightManager *Engine_getLightManager(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &lightManager = engine->getLightManager();
            return reinterpret_cast<TLightManager *>(&lightManager);
        }

        EMSCRIPTEN_KEEPALIVE TEntityManager *Engine_getEntityManager(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &entityManager = engine->getEntityManager();
            RenderThread_registerOwnerFromOwner(&entityManager, tEngine);
            return reinterpret_cast<TEntityManager *>(&entityManager);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_setAutomaticInstancingEnabled(TEngine *tEngine, bool enabled) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            engine->setAutomaticInstancingEnabled(enabled);
        }

        EMSCRIPTEN_KEEPALIVE size_t Engine_getMaxAutomaticInstances(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            return engine->getMaxAutomaticInstances();
        }

        EMSCRIPTEN_KEEPALIVE TCamera *Engine_createCamera(TEngine *tEngine, EntityId entityId)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            utils::Entity entity = utils::Entity::import(entityId);
            auto *camera = engine->createCamera(entity);
            return reinterpret_cast<TCamera *>(camera);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyCamera(TEngine *tEngine, TCamera *tCamera) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            auto &em = utils::EntityManager::get();
            engine->destroyCameraComponent(camera->getEntity());
        }

        EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine *tEngine, EntityId entityId)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto entity = utils::Entity::import(entityId);
            if (entity.isNull())
            {
                return std::nullptr_t();
            }
            auto *camera = engine->getCameraComponent(entity);
            return reinterpret_cast<TCamera *>(camera);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_setTransform(TEngine *tEngine, EntityId entity, double4x4 transform)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &transformManager = engine->getTransformManager();

            auto transformInstance = transformManager.getInstance(utils::Entity::import(entity));
            if (!transformInstance.isValid())
            {
                Log("Transform instance not valid");
            }
            transformManager.setTransform(transformInstance, convert_double4x4_to_mat4(transform));
        }

        EMSCRIPTEN_KEEPALIVE TMaterial *Engine_buildMaterial(TEngine *tEngine, const uint8_t *materialData, size_t length)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *material = Material::Builder()
                                 .package(materialData, length)
                                 .build(*engine);
            return reinterpret_cast<TMaterial *>(material);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterial(TEngine *tEngine, TMaterial *tMaterial)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *material = reinterpret_cast<Material *>(tMaterial);
            engine->destroy(material);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstance(TEngine *tEngine, TMaterialInstance *tMaterialInstance) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *mi = reinterpret_cast<MaterialInstance *>(tMaterialInstance);
            engine->destroy(mi);
        }

#ifdef THERMION_RUNTIME_MATERIAL_COMPILE
        EMSCRIPTEN_KEEPALIVE const uint8_t *Engine_compileMaterial(
            TEngine *tEngine,
            const char *matSource,
            size_t length,
            TMaterialPlatform platform,
            TMaterialTargetApi targetApi,
            TMaterialOptimization optimization,
            const char *definesJson,
            uint8_t embedSource,
            char *outError,
            size_t outErrorCap,
            size_t *outSize)
        {
            if (outSize != nullptr)
            {
                *outSize = 0;
            }
            auto *engine = reinterpret_cast<Engine *>(tEngine);

            using BuilderPlatform = filamat::MaterialBuilder::Platform;
            using BuilderTargetApi = filamat::MaterialBuilder::TargetApi;
            using BuilderOptimization = filamat::MaterialBuilder::Optimization;

            if (platform > T_MATERIAL_PLATFORM_ALL)
            {
                writeError(outError, outErrorCap, "invalid platform");
                return nullptr;
            }
            if (optimization > T_MATERIAL_OPTIMIZATION_PERFORMANCE)
            {
                writeError(outError, outErrorCap, "invalid optimization level");
                return nullptr;
            }

            BuilderTargetApi builderTargetApi;
            uint32_t resolved = targetApi;
            if (targetApi == T_MATERIAL_TARGET_API_FROM_ENGINE)
            {
                builderTargetApi = filamat::targetApiFromBackend(engine->getBackend());
            }
            else
            {
                if ((targetApi & ~T_MATERIAL_TARGET_API_ALL) != 0)
                {
                    writeError(outError, outErrorCap, "invalid target API flags");
                    return nullptr;
                }
                builderTargetApi = (BuilderTargetApi)(resolved);
            }

            // Everything below shares one mutex: MaterialBuilder::init()'s
            // glslang setup is not thread-safe, and builds on one engine's
            // JobSystem should not race each other.
            std::lock_guard<std::mutex> lock(materialCompileMutex());
            static bool materialBuilderInitialized = false;
            if (!materialBuilderInitialized)
            {
                filamat::MaterialBuilder::init();
                materialBuilderInitialized = true;
            }

            std::vector<std::pair<std::string, std::string>> defines;
            if (definesJson != nullptr && definesJson[0] != '\0')
            {
                if (!parseDefinesJson(definesJson, defines))
                {
                    writeError(outError, outErrorCap,
                        "definesJson must be a flat JSON object of strings, e.g. {\"KEY\": \"value\"}");
                    return nullptr;
                }
            }

            // parse() takes a non-const buffer (it rewrites the source in
            // place when applying substitutions).
            std::unique_ptr<const char[]> buffer(new char[length + 1]);
            memcpy((void *)buffer.get(), matSource, length);
            ((char *)buffer.get())[length] = '\0';
            ssize_t size = (ssize_t)length;

            RuntimeMaterialConfig config(
                (BuilderPlatform)platform, builderTargetApi, (BuilderOptimization)optimization,
                embedSource != 0);

            filamat::MaterialBuilder builder;
            builder.platform(config.getPlatform())
                .targetApi(config.getTargetApi())
                .optimization(config.getOptimizationLevel())
                .featureLevel(config.getFeatureLevel())
                .materialSource(std::string_view(buffer.get(), length));
            for (const auto &define : defines)
            {
                builder.shaderDefine(define.first.c_str(), define.second.c_str());
            }

            matp::MaterialParser parser;
            utils::Status status = parser.parse(builder, config, size, buffer);
            if (status.getCode() != utils::StatusCode::OK)
            {
                auto message = status.getMessage();
                char formatted[512];
                snprintf(formatted, sizeof(formatted), "material parse failed: %.*s",
                    (int)message.size(), message.data());
                writeError(outError, outErrorCap, formatted);
                return nullptr;
            }

            filamat::Package package = builder.build(engine->getJobSystem());
            if (!package.isValid())
            {
                // Shader compilation diagnostics are emitted to the log by
                // glslang; there is no in-band channel for them.
                writeError(outError, outErrorCap,
                    "material build failed (see engine log for shader diagnostics)");
                return nullptr;
            }

            uint8_t *result = (uint8_t *)malloc(package.getSize());
            if (result == nullptr)
            {
                writeError(outError, outErrorCap, "out of memory copying package");
                return nullptr;
            }
            memcpy(result, package.getData(), package.getSize());
            if (outSize != nullptr)
            {
                *outSize = package.getSize();
            }
            return result;
        }

        EMSCRIPTEN_KEEPALIVE void Engine_freeCompiledMaterial(const uint8_t *data)
        {
            free((void *)data);
        }
#else
        EMSCRIPTEN_KEEPALIVE const uint8_t *Engine_compileMaterial(
            TEngine *tEngine,
            const char *matSource,
            size_t length,
            TMaterialPlatform platform,
            TMaterialTargetApi targetApi,
            TMaterialOptimization optimization,
            const char *definesJson,
            uint8_t embedSource,
            char *outError,
            size_t outErrorCap,
            size_t *outSize)
        {
            // filamat/matp are not linked into this build (see
            // docs/research/runtime-material-compile.md section 5: Phase 1
            // covers desktop; mobile/web artifacts do not ship libmatp).
            writeError(outError, outErrorCap,
                "runtime material compilation is not supported on this platform");
            if (outSize != nullptr)
            {
                *outSize = 0;
            }
            return nullptr;
        }

        EMSCRIPTEN_KEEPALIVE void Engine_freeCompiledMaterial(const uint8_t *data) {}
#endif

        EMSCRIPTEN_KEEPALIVE void Engine_destroyTexture(TEngine *tEngine, TTexture *tTexture)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *texture = reinterpret_cast<Texture *>(tTexture);
            // Parent resources can release a texture as part of their queued
            // destruction. Treat a later explicit release as idempotent;
            // Engine::destroy on an invalid texture can raise inside the
            // render-thread packaged_task and strand the Dart completion.
            if (!engine->isValid(texture))
            {
                return;
            }
            engine->destroy(texture);
        }

        EMSCRIPTEN_KEEPALIVE TFence *Engine_createFence(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *fence = engine->createFence();
            return reinterpret_cast<TFence *>(fence);
        }

        EMSCRIPTEN_KEEPALIVE void Fence_waitAndDestroy(TFence *tFence) {
            auto *fence = reinterpret_cast<filament::Fence *>(tFence);
            Fence::waitAndDestroy(fence);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyFence(TEngine *tEngine, TFence *tFence)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *fence = reinterpret_cast<Fence *>(tFence);
            Fence::waitAndDestroy(fence);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_flushAndWait(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            engine->flushAndWait();
        }
        
        EMSCRIPTEN_KEEPALIVE void Engine_execute(TEngine *tEngine) {
            #ifdef __EMSCRIPTEN__
                auto *engine = reinterpret_cast<Engine *>(tEngine);
                engine->execute();
            #else
                Log("WARNING - ignored on non-WASM");
            #endif
        }

        EMSCRIPTEN_KEEPALIVE TScene *Engine_createScene(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *scene = engine->createScene();
            RenderThread_registerOwnerFromOwner(scene, tEngine);
            return reinterpret_cast<TScene *>(scene);
        }

        EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildSkybox(TEngine *tEngine, TTexture *tTexture, bool showSun, float intensity, uint8_t priority)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *texture = reinterpret_cast<Texture *>(tTexture);

            auto skyboxBuilder = filament::Skybox::Builder();

            if (texture)
            {
                skyboxBuilder.environment(texture);
            }
            skyboxBuilder.showSun(showSun);
            if (intensity >= 0.0f)
            {
                skyboxBuilder.intensity(intensity);
            }
            skyboxBuilder.priority(priority);

            auto *skybox = skyboxBuilder.build(*engine);

            return reinterpret_cast<TSkybox *>(skybox);
        }

        EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildColoredSkybox(TEngine *tEngine, float r, float g, float b, float a, bool showSun, float intensity, uint8_t priority)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto skyboxBuilder = filament::Skybox::Builder()
                .color({r, g, b, a})
                .showSun(showSun)
                .priority(priority);
            if (intensity >= 0.0f)
            {
                skyboxBuilder.intensity(intensity);
            }
            auto *skybox = skyboxBuilder.build(*engine);
            return reinterpret_cast<TSkybox *>(skybox);
        }

        EMSCRIPTEN_KEEPALIVE TIndirectLight *Engine_buildIndirectLightFromIrradianceTexture(TEngine *tEngine, TTexture *tReflectionsTexture, TTexture* tIrradianceTexture, float intensity)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *reflectionsTexture = reinterpret_cast<Texture *>(tReflectionsTexture);
            auto *irradianceTexture = reinterpret_cast<Texture *>(tIrradianceTexture);

            auto indirectLightBuilder = filament::IndirectLight::Builder().intensity(intensity);

            if(!irradianceTexture) {
                Log("Irradiance texture must not be empty");
                return std::nullptr_t();
            }
            
            if(reflectionsTexture) {
                indirectLightBuilder.reflections(reflectionsTexture);
            }

                                                                            
            auto *indirectLight = indirectLightBuilder.build(*engine);
            return reinterpret_cast<TIndirectLight *>(indirectLight);
        }

         EMSCRIPTEN_KEEPALIVE TIndirectLight *Engine_buildIndirectLightFromIrradianceHarmonics(TEngine *tEngine, TTexture *tReflectionsTexture, float *harmonics, float intensity)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *reflectionsTexture = reinterpret_cast<Texture *>(tReflectionsTexture);

            auto indirectLightBuilder = filament::IndirectLight::Builder().intensity(intensity);

            if(reflectionsTexture) {
                indirectLightBuilder.reflections(reflectionsTexture);
            }
            
            if(harmonics) {
                filament::math::float3 sphericalHarmonics[9];
                memcpy(sphericalHarmonics, harmonics, 27 * sizeof(float));
                indirectLightBuilder.irradiance(3, sphericalHarmonics);
            }
                                                                            
            auto *indirectLight = indirectLightBuilder.build(*engine);
            return reinterpret_cast<TIndirectLight *>(indirectLight);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroySkybox(TEngine *tEngine, TSkybox *tSkybox) {
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *skybox = reinterpret_cast<filament::Skybox *>(tSkybox);
            // Callers can destroy a caller-attached skybox themselves before
            // the scene (or a viewer teardown that derives from the scene)
            // releases it. Treat a later explicit release as idempotent, as
            // Engine_destroyTexture does.
            if (!engine->isValid(skybox))
            {
                return;
            }
            if(skybox->getTexture()) {
                engine->destroy(skybox->getTexture());
            }
            engine->destroy(skybox);
        }
        
        EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLight(TEngine *tEngine, TIndirectLight *tIndirectLight) {
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *indirectLight = reinterpret_cast<filament::IndirectLight *>(tIndirectLight);
            engine->destroy(indirectLight);
        }

        EMSCRIPTEN_KEEPALIVE EntityId EntityManager_createEntity(TEntityManager *tEntityManager) {
            auto entityManager = reinterpret_cast<utils::EntityManager *>(tEntityManager);
            auto entity = entityManager->create();
            return utils::Entity::smuggle(entity);
        }

        EMSCRIPTEN_KEEPALIVE void EntityManager_destroyEntity(TEntityManager *tEntityManager, EntityId entityId) {
            auto entityManager = reinterpret_cast<utils::EntityManager *>(tEntityManager);
            entityManager->destroy(utils::Entity::import(entityId));
        }

        EMSCRIPTEN_KEEPALIVE TDebugRegistry *Engine_getDebugRegistry(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &debugRegistry = engine->getDebugRegistry();
            return reinterpret_cast<TDebugRegistry *>(&debugRegistry);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_hasProperty(TDebugRegistry *tDebugRegistry, const char *name) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->hasProperty(name);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_setProperty_bool(TDebugRegistry *tDebugRegistry, const char *name, bool value) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->setProperty(name, value);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_setProperty_int(TDebugRegistry *tDebugRegistry, const char *name, int value) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->setProperty(name, value);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_setProperty_float(TDebugRegistry *tDebugRegistry, const char *name, float value) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->setProperty(name, value);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_getProperty_bool(TDebugRegistry *tDebugRegistry, const char *name, bool *outValue) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->getProperty(name, outValue);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_getProperty_int(TDebugRegistry *tDebugRegistry, const char *name, int *outValue) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->getProperty(name, outValue);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_getProperty_float(TDebugRegistry *tDebugRegistry, const char *name, float *outValue) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->getProperty(name, outValue);
        }

#ifdef __cplusplus
    }
}
#endif
