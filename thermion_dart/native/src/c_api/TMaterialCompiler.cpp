#include "c_api/TMaterialCompiler.h"

// Runtime material compilation is opt-in: it links filamat (MaterialBuilder,
// glslang, SPIRV-Tools) and matp (the .mat parser behind matc) into
// libthermion_dart, which adds tens of MB to the binary. The build hook
// defines THERMION_ENABLE_RUNTIME_MATERIALS when the consuming app sets
// `runtime_materials: true` under hooks.user_defines.thermion_dart in its
// pubspec.yaml. With the define absent, this translation unit still exports
// the same symbols (as no-ops), so the Dart bindings are identical either way
// and code running on both builds can feature-detect via
// MaterialCompiler_isSupported().
#ifdef THERMION_ENABLE_RUNTIME_MATERIALS

#include "c_api/TEngine.h"
#include "rendering/JobThread.hpp"

#include <filamat/MaterialBuilder.h>
#include <filament-matp/IncludeCallback.h>
#include <filament-matp/Includes.h>
#include <filament-matp/MaterialParser.h>
#include <filament/Engine.h>

#ifdef __APPLE__
// TARGET_OS_IPHONE for the iOS platform selection below.
#include <TargetConditionals.h>
#endif

#include <cstring>
#include <functional>
#include <future>
#include <memory>
#include <mutex>
#include <new>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace thermion
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
            std::string error;
        };

        TMaterialCompilerPackage *failedPackage(std::string_view error)
        {
            auto *payload = new (std::nothrow) PackagePayload();
            if (payload == nullptr) return nullptr;
            payload->error.assign(error.data(), error.size());
            return reinterpret_cast<TMaterialCompilerPackage *>(payload);
        }

        TMaterialCompilerPackage *successfulPackageOnly(TMaterialCompilerPackage *package)
        {
            auto *payload = reinterpret_cast<PackagePayload *>(package);
            if (payload != nullptr && !payload->error.empty())
            {
                delete payload;
                return nullptr;
            }
            return package;
        }

        filamat::MaterialBuilder::Platform platformForThisBuild()
        {
#if defined(__ANDROID__) || defined(__EMSCRIPTEN__) || \
        (defined(__APPLE__) && defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE)
            // Android also defines __linux__, so mobile targets must be
            // selected before the desktop platform checks below.
            return filamat::MaterialBuilder::Platform::MOBILE;
#elif defined(__APPLE__) || defined(__linux__) || defined(_WIN32)
            // Desktop shader models, matching the precompiled Thermion
            // materials for these targets.
            return filamat::MaterialBuilder::Platform::DESKTOP;
#elif defined(__arm__) || defined(__aarch64__)
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
#elif defined(__EMSCRIPTEN__)
            // Runtime Web materials target the WebGL engine. WebGPU engine
            // variants require their own separately compiled materials.
            return filamat::MaterialBuilder::TargetApi::OPENGL;
#elif defined(__ANDROID__) || defined(__linux__) || defined(_WIN32)
            // Matches the precompiled Thermion materials: Vulkan + OpenGL.
            return static_cast<filamat::MaterialBuilder::TargetApi>(
                uint8_t(filamat::MaterialBuilder::TargetApi::VULKAN) |
                uint8_t(filamat::MaterialBuilder::TargetApi::OPENGL));
#else
            return filamat::MaterialBuilder::TargetApi::ALL;
#endif
        }

        std::string compilationParametersForThisBuild()
        {
            const char *platform = platformForThisBuild() == filamat::MaterialBuilder::Platform::MOBILE
                ? "mobile" : "desktop";
            const auto api = targetApiForThisBuild();
            const char *targets = api == filamat::MaterialBuilder::TargetApi::METAL
                ? "-a metal" : api == filamat::MaterialBuilder::TargetApi::OPENGL
                ? "-a opengl" : "-a vulkan -a opengl";
            // Keep PERFORMANCE deliberately, matching matc's default / -O.
            return std::string("-O -p ") + platform + " " + targets;
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

        // Runs `compile` (which must return a valid/invalid Package) under
        // the compiler mutex, brackets it with MaterialBuilder::
        // init/shutdown, and copies a valid package into an owned payload.
        template <typename F>
        TMaterialCompilerPackage *buildPackageLocked(F &&compile, std::string *diagnostic = nullptr)
        {
            std::lock_guard<std::mutex> lock(compilerMutex());

            filamat::MaterialBuilder::init();
            filamat::Package package = compile();
            filamat::MaterialBuilder::shutdown();

            if (!package.isValid() || (diagnostic != nullptr && !diagnostic->empty()))
            {
                return failedPackage(diagnostic != nullptr && !diagnostic->empty()
                    ? std::string_view(*diagnostic)
                    : "Filament rejected the shader source; see Filament logs for shader diagnostics.");
            }

            PackagePayload *payload = new (std::nothrow) PackagePayload();
            if (payload == nullptr)
            {
                return nullptr;
            }
            payload->bytes.assign(package.getData(), package.getData() + package.getSize());
            return reinterpret_cast<TMaterialCompilerPackage *>(payload);
        }

        filamat::Package buildMaterial(filamat::MaterialBuilder &builder, filament::Engine *engine)
        {
#if defined(__EMSCRIPTEN__) && !defined(THERMION_WEB_MAIN_THREAD)
            // The browser caller is not the worker that created the engine.
            // A temporary NOOP engine supplies a caller-adopted job system
            // through Filament's public API; JobSystem's private headers are
            // deliberately absent from the installed artifacts.
            (void)engine;
            auto *compilerEngine = filament::Engine::create(filament::Engine::Backend::NOOP);
            if (compilerEngine == nullptr) return {};
            auto package = builder.build(compilerEngine->getJobSystem());
            filament::Engine::destroy(&compilerEngine);
            return package;
#else
            return builder.build(engine->getJobSystem());
#endif
        }

        TMaterialCompilerPackage *compileLocked(
            filament::Engine *engine, const char *name,
            const char *materialSource, TShading shading)
        {
            return buildPackageLocked(
                [&]() -> filamat::Package
                {
                    filamat::MaterialBuilder builder;
                    builder.name(name ? name : "runtime_material")
                        .material(materialSource)
                        .shading(toFilamatShading(shading))
                        .platform(platformForThisBuild())
                        .targetApi(targetApiForThisBuild())
                        .optimization(filamat::MaterialBuilder::Optimization::PERFORMANCE)
                        .compilationParameters(compilationParametersForThisBuild().c_str())
                        .materialSource(std::string_view(materialSource));
                    return buildMaterial(builder, engine);
                });
        }

        // Minimal matp::Config for in-memory compilation. Input/Output are
        // unused: the source is handed to MaterialParser::parse directly
        // and the package is read from MaterialBuilder::build.
        class RuntimePackageConfig final : public matp::Config
        {
        public:
            RuntimePackageConfig()
            {
                mPlatform = platformForThisBuild();
                mTargetApi = targetApiForThisBuild();
                mOptimizationLevel = Optimization::PERFORMANCE;
            }

            Output *getOutput() const noexcept override { return nullptr; }
            Input *getInput() const noexcept override { return nullptr; }
            std::string toString() const noexcept override { return toPIISafeString(); }
            std::string toPIISafeString() const noexcept override { return compilationParametersForThisBuild(); }
        };

        using IncludeMap = std::unordered_map<std::string, std::string>;

        // Parses `includesJson`: a strict JSON object mapping include
        // names to file contents (exactly what Dart's json.encode emits
        // for a Map<String, String>). A small recursive-descent reader
        // keeps thermion free of a JSON dependency; matp's own Jsonish
        // reader is deliberately not used because it lives in matp's
        // src/ (not shipped in the artifact headers) and accepts a looser
        // dialect than JSON. Standard JSON escapes including \u (with
        // surrogate pairs) are resolved to UTF-8.
        class IncludesJsonParser
        {
        public:
            explicit IncludesJsonParser(const char *text) : mCursor(text) {}

            bool parse(IncludeMap &out)
            {
                skipWhitespace();
                if (!consume('{'))
                {
                    return false;
                }
                skipWhitespace();
                if (consume('}'))
                {
                    skipWhitespace();
                    return *mCursor == '\0';
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
                    if (!consume(':'))
                    {
                        return false;
                    }
                    skipWhitespace();
                    std::string value;
                    if (!parseString(value))
                    {
                        return false;
                    }
                    out[std::move(key)] = std::move(value);
                    skipWhitespace();
                    if (consume(','))
                    {
                        continue;
                    }
                    if (consume('}'))
                    {
                        skipWhitespace();
                        return *mCursor == '\0';
                    }
                    return false;
                }
            }

        private:
            const char *mCursor;

            void skipWhitespace()
            {
                while (*mCursor == ' ' || *mCursor == '\t' || *mCursor == '\n' || *mCursor == '\r')
                {
                    ++mCursor;
                }
            }

            bool consume(char c)
            {
                if (*mCursor != c)
                {
                    return false;
                }
                ++mCursor;
                return true;
            }

            bool parseHex4(uint32_t &out)
            {
                out = 0;
                for (int i = 0; i < 4; ++i)
                {
                    const char c = *mCursor;
                    uint32_t digit;
                    if (c >= '0' && c <= '9')
                    {
                        digit = uint32_t(c - '0');
                    }
                    else if (c >= 'a' && c <= 'f')
                    {
                        digit = uint32_t(c - 'a') + 10;
                    }
                    else if (c >= 'A' && c <= 'F')
                    {
                        digit = uint32_t(c - 'A') + 10;
                    }
                    else
                    {
                        return false;
                    }
                    out = (out << 4) | digit;
                    ++mCursor;
                }
                return true;
            }

            static void appendUtf8(std::string &out, uint32_t codepoint)
            {
                if (codepoint < 0x80)
                {
                    out += char(codepoint);
                }
                else if (codepoint < 0x800)
                {
                    out += char(0xC0 | (codepoint >> 6));
                    out += char(0x80 | (codepoint & 0x3F));
                }
                else if (codepoint < 0x10000)
                {
                    out += char(0xE0 | (codepoint >> 12));
                    out += char(0x80 | ((codepoint >> 6) & 0x3F));
                    out += char(0x80 | (codepoint & 0x3F));
                }
                else
                {
                    out += char(0xF0 | (codepoint >> 18));
                    out += char(0x80 | ((codepoint >> 12) & 0x3F));
                    out += char(0x80 | ((codepoint >> 6) & 0x3F));
                    out += char(0x80 | (codepoint & 0x3F));
                }
            }

            bool parseString(std::string &out)
            {
                if (!consume('"'))
                {
                    return false;
                }
                while (true)
                {
                    const char c = *mCursor;
                    if (c == '\0')
                    {
                        return false;
                    }
                    ++mCursor;
                    if (c == '"')
                    {
                        return true;
                    }
                    if (static_cast<unsigned char>(c) < 0x20)
                    {
                        // Raw control characters are invalid in JSON.
                        return false;
                    }
                    if (c != '\\')
                    {
                        out += c;
                        continue;
                    }
                    const char escape = *mCursor;
                    if (escape == '\0')
                    {
                        return false;
                    }
                    ++mCursor;
                    switch (escape)
                    {
                    case '"': out += '"'; break;
                    case '\\': out += '\\'; break;
                    case '/': out += '/'; break;
                    case 'b': out += '\b'; break;
                    case 'f': out += '\f'; break;
                    case 'n': out += '\n'; break;
                    case 'r': out += '\r'; break;
                    case 't': out += '\t'; break;
                    case 'u':
                    {
                        uint32_t codepoint;
                        if (!parseHex4(codepoint))
                        {
                            return false;
                        }
                        if (codepoint >= 0xD800 && codepoint <= 0xDBFF)
                        {
                            // High surrogate: must be followed by \uDC00-\uDFFF.
                            if (!consume('\\') || !consume('u'))
                            {
                                return false;
                            }
                            uint32_t low;
                            if (!parseHex4(low) || low < 0xDC00 || low > 0xDFFF)
                            {
                                return false;
                            }
                            codepoint = 0x10000 + ((codepoint - 0xD800) << 10) + (low - 0xDC00);
                        }
                        else if (codepoint >= 0xDC00 && codepoint <= 0xDFFF)
                        {
                            return false;
                        }
                        appendUtf8(out, codepoint);
                        break;
                    }
                    default:
                        return false;
                    }
                }
            }
        };

        bool parseIncludesJson(const char *includesJson, IncludeMap &out)
        {
            return IncludesJsonParser(includesJson).parse(out);
        }

        TMaterialCompilerPackage *compilePackageLocked(
            filament::Engine *engine, const char *name,
            const char *matSource, const char *includesJson)
        {
            // Resolve #include directives against the in-memory map before
            // parsing; matp requires fully resolved source. Keys are
            // matched verbatim against the #include "..." name, so nested
            // includes work with the same flat map.
            IncludeMap includes;
            if (includesJson != nullptr && includesJson[0] != '\0' &&
                !parseIncludesJson(includesJson, includes))
            {
                return failedPackage("Invalid includes JSON: expected an object mapping names to source strings.");
            }

            const std::string materialName = name ? name : "runtime_material";
            matp::IncludeResult root{
                .includeName = utils::CString(materialName.c_str()),
                .text = utils::CString(matSource),
                .name = utils::CString(""),
            };
            matp::IncludeCallback includer =
                [&includes](const utils::CString &includedBy, matp::IncludeResult &result)
            {
                (void)includedBy;
                auto it = includes.find(std::string(result.includeName.c_str()));
                if (it == includes.end())
                {
                    return false;
                }
                result.text = utils::CString(it->second.c_str());
                result.name = utils::CString(it->first.c_str());
                return true;
            };
            matp::ResolveOptions options;
            options.insertLineDirectives = true;
            options.insertLineDirectiveCheck = true;
            const auto includeStatus = matp::resolveIncludesRecursively(root, includer, options);
            if (!includeStatus.isOk())
            {
                return failedPackage(includeStatus.getMessage());
            }

            std::string diagnostic;
            return buildPackageLocked(
                [&]() -> filamat::Package
                {
                    ssize_t size = static_cast<ssize_t>(root.text.size());
                    std::unique_ptr<char[]> buffer(new (std::nothrow) char[size + 1]);
                    if (buffer == nullptr)
                    {
                        return {};
                    }
                    std::memcpy(buffer.get(), root.text.c_str(), size);
                    buffer[size] = '\0';
                    std::unique_ptr<const char[]> source = std::move(buffer);

                    RuntimePackageConfig config;
                    filamat::MaterialBuilder builder;
                    builder.name(materialName.c_str());
                    matp::MaterialParser parser;
                    const auto parseStatus = parser.parse(builder, config, size, source);
                    if (!parseStatus.isOk())
                    {
                        diagnostic = parseStatus.getMessage();
                        return {};
                    }
                    builder.compilationParameters(config.toPIISafeString().c_str())
                        .materialSource(std::string_view(source.get(), size));
                    return buildMaterial(builder, engine);
                }, &diagnostic);
        }

        // Dispatches `compile` to the thread that owns the engine.
        //
        // Web must compile inline, never via the JobThread. Emscripten
        // builds run FEngine single-threaded (threading disabled), so the
        // JobThread queue is only drained when the main thread returns to
        // the JS event loop — but the future.get() used by the packaged-
        // task path (non-web, below) busy-spins the main thread waiting
        // for the queued job, which therefore can never start: the first
        // compile deadlocks the page at 100% CPU. buildMaterial owns a
        // caller-adopted compilation job system when the engine belongs to
        // the render worker. Main-thread engines use their existing adopted
        // job system. The UI blocks for the duration of compilation (~1s).
        //
        // Elsewhere the CPU-bound compile runs on the job thread that
        // created the engine. MaterialBuilder::build drives the engine's
        // JobSystem, whose calling thread must have been adopted — true
        // of the engine-creating job thread, but not of an arbitrary
        // Dart/native caller thread. The packaged-task future blocks the
        // submitting thread until the job thread finishes, matching the
        // other *JobThread entry points.
        template <typename F>
        TMaterialCompilerPackage *dispatchCompile(TJobThread *tJobThread, filament::Engine *engine, F compile)
        {
#if defined(__EMSCRIPTEN__)
            (void)tJobThread;
            (void)engine;
            return compile();
#else
            (void)engine;
            auto *jobThread = reinterpret_cast<JobThread *>(tJobThread);
            std::packaged_task<TMaterialCompilerPackage *()> task(std::move(compile));
            return jobThread->addTask(task).get();
#endif
        }

    } // namespace

    extern "C"
    {

        EMSCRIPTEN_KEEPALIVE uint8_t MaterialCompiler_isSupported() { return 1; }

        EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialSourceWithDiagnostics(
            TJobThread *tJobThread, TEngine *tEngine, const char *name, const char *materialSource, TShading shading)
        {
            if (tJobThread == nullptr || tEngine == nullptr || materialSource == nullptr)
            {
                return nullptr;
            }
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            return dispatchCompile(tJobThread, engine,
                [engine, name, materialSource, shading]
                {
                    return compileLocked(engine, name, materialSource, shading);
                });
        }

        EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialPackageWithDiagnostics(
            TJobThread *tJobThread, TEngine *tEngine, const char *name, const char *matSource, const char *includesJson)
        {
            if (tJobThread == nullptr || tEngine == nullptr || matSource == nullptr)
            {
                return nullptr;
            }
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            return dispatchCompile(tJobThread, engine,
                [engine, name, matSource, includesJson]
                {
                    return compilePackageLocked(engine, name, matSource, includesJson);
                });
        }

        EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialSource(
            TJobThread *thread, TEngine *engine, const char *name, const char *source, TShading shading)
        {
            return successfulPackageOnly(MaterialCompiler_compileMaterialSourceWithDiagnostics(
                thread, engine, name, source, shading));
        }

        EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialPackage(
            TJobThread *thread, TEngine *engine, const char *name, const char *source, const char *includes)
        {
            return successfulPackageOnly(MaterialCompiler_compileMaterialPackageWithDiagnostics(
                thread, engine, name, source, includes));
        }

        EMSCRIPTEN_KEEPALIVE const char *MaterialCompiler_getPackageError(TMaterialCompilerPackage *package)
        {
            auto *payload = reinterpret_cast<PackagePayload *>(package);
            return payload == nullptr || payload->error.empty() ? nullptr : payload->error.c_str();
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

        // Web has no way to hand a JS-side buffer to native code as an output
        // pointer: every typed-data borrow ffigen_js provides is copy-in, so
        // MaterialCompiler_getPackageBytes can only ever write into a native
        // scratch allocation the caller cannot read back. Web callers instead
        // read the package straight out of the wasm heap through this pointer
        // (plus MaterialCompiler_getPackageSize), the same pattern the
        // readPixels/readString paths use for bulk data. The pointer is valid
        // until MaterialCompiler_destroyPackage.
        EMSCRIPTEN_KEEPALIVE const uint8_t *MaterialCompiler_getPackagePtr(
            TMaterialCompilerPackage *package)
        {
            auto *payload = reinterpret_cast<PackagePayload *>(package);
            return payload == nullptr ? nullptr : payload->bytes.data();
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

    EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialPackage(
        TJobThread *tJobThread, TEngine *tEngine, const char *name, const char *matSource, const char *includesJson)
    {
        (void)tJobThread;
        (void)tEngine;
        (void)name;
        (void)matSource;
        (void)includesJson;
        return nullptr;
    }

    EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialSourceWithDiagnostics(
        TJobThread *thread, TEngine *engine, const char *name, const char *source, TShading shading)
    {
        return MaterialCompiler_compileMaterialSource(thread, engine, name, source, shading);
    }

    EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialPackageWithDiagnostics(
        TJobThread *thread, TEngine *engine, const char *name, const char *source, const char *includes)
    {
        return MaterialCompiler_compileMaterialPackage(thread, engine, name, source, includes);
    }

    EMSCRIPTEN_KEEPALIVE const char *MaterialCompiler_getPackageError(TMaterialCompilerPackage *package)
    {
        (void)package;
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

    EMSCRIPTEN_KEEPALIVE const uint8_t *MaterialCompiler_getPackagePtr(TMaterialCompilerPackage *package)
    {
        (void)package;
        return nullptr;
    }

    EMSCRIPTEN_KEEPALIVE void MaterialCompiler_destroyPackage(TMaterialCompilerPackage *package)
    {
        (void)package;
    }

}

#endif // THERMION_ENABLE_RUNTIME_MATERIALS
