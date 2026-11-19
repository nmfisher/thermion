"""Exercise the Linux plugin CMake with headers created during assemble."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


LINUX = Path(__file__).resolve().parents[2] / "linux"
PIN_A = "0123456789abcdef" * 4
PIN_B = "fedcba9876543210" * 4


class LinuxFilamentHeadersTest(unittest.TestCase):
    def setUp(self):
        # MSBuild's FileTracker excludes %TEMP%/%LOCALAPPDATA% from .tlog
        # dependency tracking, so pin rotation inside a tempfile.TemporaryDirectory
        # under %TEMP% leaves consumer.obj stale on Windows. Host the fixture in
        # the workspace (the job's checkout drive) instead.
        if os.name == "nt":
            base = Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir()))
            if Path(tempfile.gettempdir()) in base.parents or base == Path(tempfile.gettempdir()):
                # RUNNER_TEMP is D:\a\_temp on GitHub runners; fall back to the
                # repo dir if we somehow still resolve under %TEMP%.
                base = Path(__file__).resolve().parents[4]
            self.root = Path(base) / f"thermion-linux-headers-{os.urandom(6).hex()}"
            self.root.mkdir(parents=True)
            self.temporary = None
        else:
            self.temporary = tempfile.TemporaryDirectory(prefix="thermion-linux-headers-")
            self.root = Path(self.temporary.name)
        root = self.root
        if self.temporary is not None:
            self.addCleanup(self.temporary.cleanup)
        else:
            self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.app = root / "app"
        self.package = root / "packages" / "thermion_dart"
        self.build = self.app / "build"
        (self.package / "lib").mkdir(parents=True)
        (self.app / "cmake").mkdir(parents=True)
        config_dir = self.app / ".dart_tool"
        config_dir.mkdir(parents=True)
        self.write_package_config(self.package.as_uri())

        # Stub PkgConfig::GTK so the real linux/CMakeLists.txt can run on
        # macOS, Windows, and Linux without requiring host GTK headers.
        (self.app / "cmake/FindPkgConfig.cmake").write_text(r'''
set(PkgConfig_FOUND TRUE)
macro(pkg_check_modules _prefix)
  if(NOT TARGET PkgConfig::${_prefix})
    add_library(PkgConfig::${_prefix} INTERFACE IMPORTED)
  endif()
endmacro()
''')
        (self.app / "CMakeLists.txt").write_text(r'''
cmake_minimum_required(VERSION 3.19)
project(LinuxHeaderBootstrap LANGUAGES C CXX)
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
add_library(flutter INTERFACE)
add_custom_target(flutter_assemble
  COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_SOURCE_DIR}/assemble.cmake")
add_subdirectory("${PLUGIN_ROOT}" plugin)
set_property(TARGET thermion_flutter_plugin PROPERTY SOURCES "${CMAKE_SOURCE_DIR}/plugin.cpp")
set_property(TARGET thermion_flutter_plugin PROPERTY COMPILE_OPTIONS "")
set_property(TARGET thermion_flutter_plugin PROPERTY LINK_OPTIONS "")
set_property(TARGET thermion_flutter_plugin PROPERTY LINK_LIBRARIES "")
set_property(TARGET thermion_flutter_plugin PROPERTY LINK_DIRECTORIES "")
add_executable(consumer consumer.cpp)
target_link_libraries(consumer PRIVATE thermion_flutter_plugin)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${PROJECT_BINARY_DIR}/bundle" CACHE PATH "" FORCE)
endif()
''')
        (self.app / "plugin.cpp").write_text(r'''
#include <bluevk/BlueVK.h>
#include "expectation.h"
static_assert(FILAMENT_MARKER == EXPECTED_MARKER, "wrong artifact headers");
extern "C"
#ifdef _WIN32
__declspec(dllexport)
#else
__attribute__((visibility("default")))
#endif
int fixture_value() { return FILAMENT_MARKER; }
''')
        (self.app / "consumer.cpp").write_text(r'''
#include "expectation.h"
extern "C" int fixture_value();
int main() { return fixture_value() == EXPECTED_MARKER ? 0 : 1; }
''')
        self.version = "vtest"
        self.write_version()

    def write_package_config(self, uri):
        (self.app / ".dart_tool/package_config.json").write_text(json.dumps({
            "configVersion": 2,
            "packages": [{"name": "thermion_dart", "rootUri": uri}],
        }))

    def run_command(self, *command, success=True):
        environment = dict(os.environ)
        environment.pop("CMAKE_INSTALL_PREFIX", None)
        result = subprocess.run(command, capture_output=True, text=True, env=environment)
        if success:
            self.assertEqual(result.returncode, 0, (result.stdout + result.stderr)[-10000:])
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def write_version(self):
        (self.package / "lib/filament_version.dart").write_text(
            f"const String filamentVersion = '{self.version}';\n"
        )

    def write_pin(self, pin):
        (self.package / "filament.libs.json").write_text(json.dumps(pin))

    def assemble_into(self, mode="release", digest=None, arm64=False, marker=101):
        suffix = "-" + digest[:16].lower() if digest else ""
        base = self.package / ".dart_tool/thermion_dart/lib" / self.version / "linux"
        include = (base / mode / ("arm64" + suffix) / "include") if arm64 else (base / (mode + suffix) / "include")
        self.assertFalse(include.exists(), "fixture must start without its selected artifact")
        (self.app / "expectation.h").write_text(f"#define EXPECTED_MARKER {marker}\n")
        (self.app / "assemble.cmake").write_text(
            f'file(MAKE_DIRECTORY "{include.as_posix()}/bluevk")\n'
            f'file(WRITE "{include.as_posix()}/bluevk/BlueVK.h" "#define FILAMENT_MARKER {marker}\\n")\n'
        )
        return include

    def configure(self, mode="Debug", target_platform="linux-x64", *extra, success=True):
        self.mode = mode
        return self.run_command(
            "cmake", "-S", str(self.app), "-B", str(self.build),
            f"-DPLUGIN_ROOT={LINUX.as_posix()}",
            f"-DCMAKE_BUILD_TYPE={mode}",
            f"-DFLUTTER_TARGET_PLATFORM={target_platform}",
            *extra, success=success,
        )

    def build_and_run(self):
        self.run_command("cmake", "--build", str(self.build), "--config", self.mode, "--parallel", "4")
        name = "consumer.exe" if os.name == "nt" else "consumer"
        executable = next(path for path in (self.build / "bin").rglob(name) if path.is_file())
        self.run_command(str(executable))

    def install_prefix(self):
        return next(line.split("=", 1)[1] for line in (self.build / "CMakeCache.txt").read_text().splitlines()
                    if line.startswith("CMAKE_INSTALL_PREFIX:PATH="))

    def test_cold_x64_pinned_release_in_flutter_debug(self):
        self.write_pin({"linux/release": PIN_A, "linux/debug": PIN_B})
        include = self.assemble_into(digest=PIN_A)
        self.configure()
        self.assertFalse(include.exists(), "configure must not download the artifact")
        self.build_and_run()
        self.assertEqual(Path(self.install_prefix()), self.build / "bundle")

    def test_cold_x64_pinned_debug_in_flutter_release(self):
        self.write_pin({"linux/release": PIN_A, "linux/debug": PIN_B.upper()})
        self.assemble_into(mode="debug", digest=PIN_B)
        self.configure("Release")
        self.build_and_run()

    def test_cold_arm64_pinned_nested_cache_layout(self):
        self.write_pin({"linux/release": PIN_A, "linux-arm64/release": PIN_B})
        self.assemble_into(digest=PIN_B, arm64=True, marker=303)
        self.configure("Debug", "linux-arm64")
        self.build_and_run()

    def test_cold_arm64_legacy_without_pin_file(self):
        self.assemble_into(arm64=True, marker=404)
        self.configure("Debug", "linux-arm64")
        self.build_and_run()

    def test_malformed_pin_uses_legacy_fallback(self):
        (self.package / "filament.libs.json").write_text("{broken JSON")
        self.assemble_into()
        self.configure()
        self.build_and_run()

    def test_pin_rotation_reconfigures_without_using_old_headers(self):
        self.mode = "Debug"
        self.write_pin({"linux/release": PIN_A})
        old = self.assemble_into(digest=PIN_A)
        self.configure()
        self.build_and_run()
        time.sleep(1.1)
        self.write_pin({"linux/release": PIN_B})
        self.assemble_into(digest=PIN_B, marker=202)
        self.build_and_run()
        self.assertTrue(old.exists())

    def test_percent_encoded_file_uri_with_spaces(self):
        spaced = self.root / "Linux User (Dev)" / "dir%20lit" / "thermion_dart"
        (spaced / "lib").mkdir(parents=True)
        self.package = spaced
        self.write_version()
        self.mode = "Debug"
        self.write_pin({"linux/release": PIN_A})
        self.write_package_config(spaced.as_uri() + "/")
        self.assemble_into(digest=PIN_A)
        self.configure()
        self.build_and_run()

    def test_custom_install_prefix_is_preserved(self):
        self.assemble_into()
        custom = self.app / "custom-install"
        self.configure("Debug", "linux-x64", f"-DCMAKE_INSTALL_PREFIX:PATH={custom.as_posix()}")
        self.build_and_run()
        self.assertEqual(Path(self.install_prefix()), custom)

    def test_symlinked_plugin_with_existing_generated_headers_ninja_recompact(self):
        ninja = shutil.which("ninja") or shutil.which("ninja-build")
        if not ninja:
            self.skipTest("ninja is not installed")
        real_pkg = self.root / "real_thermion_flutter"
        shutil.copytree(LINUX.parent / "linux", real_pkg / "linux")
        shutil.copytree(LINUX.parent / "cmake", real_pkg / "cmake")
        (real_pkg / ".dart_tool").mkdir()
        (real_pkg / ".dart_tool/generated_headers.cmake").write_text(
            'set(DART_PKG_HEADERS "/nonexistent/stale/include")\n'
        )
        symlinks_dir = self.app / "flutter/ephemeral/.plugin_symlinks"
        symlinks_dir.mkdir(parents=True)
        symlink_pkg = symlinks_dir / "thermion_flutter"
        try:
            symlink_pkg.symlink_to(real_pkg, target_is_directory=True)
        except OSError as exc:
            self.skipTest(f"symlinks unavailable: {exc}")

        self.mode = "Debug"
        self.write_pin({"linux/release": PIN_A})
        expected_include = self.assemble_into(digest=PIN_A)
        (real_pkg / ".dart_tool/generated_headers.cmake").write_text(
            f'set(DART_PKG_HEADERS "{expected_include.as_posix()}" "/nonexistent/stale/include")\n'
        )
        cfg = self.run_command(
            "cmake", "-G", "Ninja", f"-DCMAKE_MAKE_PROGRAM={ninja}",
            "-S", str(self.app), "-B", str(self.build),
            f"-DPLUGIN_ROOT={(symlink_pkg / 'linux').as_posix()}",
            "-DCMAKE_BUILD_TYPE=Debug", "-DFLUTTER_TARGET_PLATFORM=linux-x64",
        )
        cfg_out = cfg.stdout + cfg.stderr
        self.assertIn("stale hook output?): /nonexistent/stale/include", cfg_out)
        self.assertNotIn(f"stale hook output?): {expected_include.as_posix()}", cfg_out)
        self.run_command(ninja, "-C", str(self.build), "-t", "recompact")
        self.build_and_run()

    def test_partial_clean_generated_headers_does_not_warn_for_expected_path(self):
        isolated = self.root / "isolated_thermion_flutter"
        shutil.copytree(LINUX.parent / "linux", isolated / "linux")
        shutil.copytree(LINUX.parent / "cmake", isolated / "cmake")
        (isolated / ".dart_tool").mkdir()
        self.mode = "Debug"
        self.write_pin({"linux/release": PIN_A})
        expected_include = self.assemble_into(digest=PIN_A)
        (isolated / ".dart_tool/generated_headers.cmake").write_text(
            f'set(DART_PKG_HEADERS "{expected_include.resolve(strict=False).as_posix()}")\n'
        )
        cfg = self.run_command(
            "cmake", "-S", str(self.app), "-B", str(self.build),
            f"-DPLUGIN_ROOT={(isolated / 'linux').as_posix()}",
            "-DCMAKE_BUILD_TYPE=Debug", "-DFLUTTER_TARGET_PLATFORM=linux-x64",
        )
        self.assertNotIn("stale hook output?", cfg.stdout + cfg.stderr)
        self.build_and_run()

    def test_missing_version_remains_a_configure_error(self):
        (self.package / "lib/filament_version.dart").unlink()
        self.assemble_into()
        result = self.configure(success=False)
        self.assertIn("missing Filament version", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
