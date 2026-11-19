"""Exercise the Windows plugin CMake with headers created during assemble."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


WINDOWS = Path(__file__).resolve().parents[2] / "windows"
PIN_A = "0123456789abcdef" * 4
PIN_B = "fedcba9876543210" * 4


class WindowsFilamentHeadersTest(unittest.TestCase):
    def setUp(self):
        # MSBuild's FileTracker excludes %TEMP%/%LOCALAPPDATA% from .tlog
        # dependency tracking, so pin rotation inside a tempfile.TemporaryDirectory
        # under %TEMP% leaves consumer.obj stale on Windows. Host the fixture in
        # the workspace (the job's checkout drive) instead.
        if os.name == "nt":
            base = Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir()))
            if base == Path(tempfile.gettempdir()) or Path(tempfile.gettempdir()) in base.parents:
                base = Path(__file__).resolve().parents[4]
            self.root = base / f"thermion-headers-{os.urandom(6).hex()}"
            self.root.mkdir(parents=True)
            self.temporary = None
        else:
            self.temporary = tempfile.TemporaryDirectory(prefix="thermion-headers-")
            self.root = Path(self.temporary.name)
        if self.temporary is not None:
            self.addCleanup(self.temporary.cleanup)
        else:
            self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        root = self.root
        self.app = root / "app"
        self.package = root / "packages" / "thermion_dart"
        self.build = self.app / "build"
        (self.package / "lib").mkdir(parents=True)
        config_dir = self.app / ".dart_tool"
        config_dir.mkdir(parents=True)
        # Windows exercises the absolute file:///C:/... URI used by pub. The
        # relative form also lets this Windows-specific CMake run on macOS.
        uri = self.package.as_uri() if os.name == "nt" else "../../packages/thermion_dart"
        (config_dir / "package_config.json").write_text(json.dumps({
            "configVersion": 2,
            "packages": [{"name": "thermion_dart", "rootUri": uri}],
        }))
        (self.app / "CMakeLists.txt").write_text(r'''
cmake_minimum_required(VERSION 3.19)
project(WindowsHeaderBootstrap LANGUAGES C CXX)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(runner_BINARY_DIR "${CMAKE_BINARY_DIR}/runner")
add_library(flutter INTERFACE)
add_library(flutter_wrapper_plugin INTERFACE)
add_custom_target(flutter_assemble
  COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_SOURCE_DIR}/assemble.cmake")
add_subdirectory("${PLUGIN_ROOT}" plugin)
# Keep the production target's includes and dependency graph, but compile a
# tiny consumer instead of Windows/Flutter implementation files on this host.
set_property(TARGET thermion_flutter_plugin PROPERTY SOURCES "${CMAKE_SOURCE_DIR}/plugin.cpp")
set_property(TARGET thermion_flutter_plugin PROPERTY LINK_LIBRARIES "")
set_property(TARGET thermion_flutter_plugin PROPERTY LINK_DIRECTORIES "")
add_executable(consumer consumer.cpp)
target_link_libraries(consumer PRIVATE thermion_flutter_plugin)
# Flutter sets the bundle destination after including plugin CMake files.
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/bundle" CACHE PATH "" FORCE)
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
#include <bluevk/BlueVK.h>
#include "expectation.h"
static_assert(FILAMENT_MARKER == EXPECTED_MARKER, "public includes use wrong headers");
extern "C" int fixture_value();
int main() { return fixture_value() == EXPECTED_MARKER ? 0 : 1; }
''')
        self.version = "vtest"
        self.write_version()

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

    def assemble_into(self, mode="release", digest=None, marker=101):
        suffix = "-" + digest[:16].lower() if digest else ""
        include = self.package / ".dart_tool/thermion_dart/lib" / self.version / "windows" / (mode + suffix) / "include"
        self.assertFalse(include.exists(), "fixture must start without its selected artifact")
        (self.app / "expectation.h").write_text(f"#define EXPECTED_MARKER {marker}\n")
        (self.app / "assemble.cmake").write_text(
            f'file(MAKE_DIRECTORY "{include.as_posix()}/bluevk")\n'
            f'file(WRITE "{include.as_posix()}/bluevk/BlueVK.h" "#define FILAMENT_MARKER {marker}\\n")\n'
        )
        return include

    def configure(self, mode="Debug", *extra, success=True):
        self.mode = mode
        return self.run_command(
            "cmake", "-S", str(self.app), "-B", str(self.build),
            f"-DPLUGIN_ROOT={WINDOWS.as_posix()}", f"-DCMAKE_BUILD_TYPE={mode}",
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

    def test_cold_pinned_release_in_flutter_debug(self):
        self.write_pin({"windows/release": PIN_A, "windows/debug": PIN_B})
        include = self.assemble_into(digest=PIN_A)
        self.configure()
        self.assertFalse(include.exists(), "configure must not download the artifact")
        self.build_and_run()
        self.assertEqual(Path(self.install_prefix()), self.build / "bundle")

    def test_cold_pinned_debug_in_flutter_release(self):
        self.write_pin({"windows/release": PIN_A, "windows/debug": PIN_B.upper()})
        self.assemble_into(mode="debug", digest=PIN_B)
        self.configure("Release")
        self.build_and_run()

    def test_cold_legacy_artifact_without_pin_file(self):
        self.assemble_into()
        self.configure()
        self.build_and_run()

    def test_malformed_pin_uses_the_hooks_legacy_fallback(self):
        (self.package / "filament.libs.json").write_text("{broken JSON")
        self.assemble_into()
        self.configure()
        self.build_and_run()

    def test_invalid_pin_entry_uses_legacy_fallback(self):
        self.write_pin({"windows/release": 123})
        self.assemble_into()
        self.configure()
        self.build_and_run()

    def test_pin_rotation_reconfigures_without_using_old_headers(self):
        self.write_pin({"windows/release": PIN_A})
        old = self.assemble_into(digest=PIN_A)
        self.configure()
        self.build_and_run()
        time.sleep(1.1)  # Make the dependency change visible on Windows filesystems.
        self.write_pin({"windows/release": PIN_B})
        self.assemble_into(digest=PIN_B, marker=202)
        self.build_and_run()
        self.assertTrue(old.exists())

    def test_version_change_reconfigures_without_using_old_headers(self):
        self.write_pin({"windows/release": PIN_A})
        old = self.assemble_into(digest=PIN_A)
        self.configure()
        self.build_and_run()
        time.sleep(1.1)
        self.version = "vnext"
        self.write_version()
        self.assemble_into(digest=PIN_A, marker=202)
        self.build_and_run()
        self.assertTrue(old.exists())

    def test_custom_install_prefix_is_preserved(self):
        self.assemble_into()
        custom = self.app / "custom-install"
        self.configure("Debug", f"-DCMAKE_INSTALL_PREFIX:PATH={custom.as_posix()}")
        self.build_and_run()
        self.assertEqual(Path(self.install_prefix()), custom)

    def write_package_config(self, uri):
        (self.app / ".dart_tool/package_config.json").write_text(json.dumps({
            "configVersion": 2,
            "packages": [{"name": "thermion_dart", "rootUri": uri}],
        }))

    def test_percent_encoded_file_uri_with_spaces_and_escaped_percent(self):
        spaced = self.root / "Jane Doe (Local)" / "dir%20lit" / "thermion_dart"
        (spaced / "lib").mkdir(parents=True)
        self.package = spaced
        self.write_version()
        self.write_pin({"windows/release": PIN_A})
        self.write_package_config(spaced.as_uri() + "/")
        self.assemble_into(digest=PIN_A)
        self.configure()
        self.build_and_run()

    def test_percent_encoded_relative_uri_with_spaces(self):
        spaced = self.root / "my packages (1)" / "thermion_dart"
        (spaced / "lib").mkdir(parents=True)
        self.package = spaced
        self.write_version()
        self.write_pin({"windows/release": PIN_A})
        self.write_package_config("../../my%20packages%20%281%29/thermion_dart/")
        self.assemble_into(digest=PIN_A)
        self.configure()
        self.build_and_run()

    def test_partial_clean_generated_headers_warns_only_for_stale_paths(self):
        isolated = self.root / "isolated_thermion_flutter"
        shutil.copytree(WINDOWS.parent / "windows", isolated / "windows")
        shutil.copytree(WINDOWS.parent / "cmake", isolated / "cmake")
        (isolated / ".dart_tool").mkdir()
        self.write_pin({"windows/release": PIN_A})
        expected_include = self.assemble_into(digest=PIN_A)
        (isolated / ".dart_tool/generated_headers.cmake").write_text(
            f'set(DART_PKG_HEADERS "{expected_include.resolve(strict=False).as_posix()}" "/nonexistent/stale/include")\n'
        )
        self.mode = "Debug"
        cfg = self.run_command(
            "cmake", "-S", str(self.app), "-B", str(self.build),
            f"-DPLUGIN_ROOT={(isolated / 'windows').as_posix()}",
            "-DCMAKE_BUILD_TYPE=Debug",
        )
        cfg_out = cfg.stdout + cfg.stderr
        self.assertIn("stale hook output?): /nonexistent/stale/include", cfg_out)
        self.assertNotIn("release-" + PIN_A[:16], cfg_out.split("stale hook output?):")[-1].splitlines()[0] if "stale hook output?):" in cfg_out else "")
        self.assertEqual(cfg_out.count("stale hook output?"), 1)
        self.build_and_run()

    def test_missing_version_remains_a_configure_error(self):
        (self.package / "lib/filament_version.dart").unlink()
        self.assemble_into()
        result = self.configure(success=False)
        self.assertIn("missing Filament version", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
