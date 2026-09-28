"""Run with: python3 -m unittest discover -s scripts -p 'test_ios_device_libraries.py'."""

from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import ios_device_libraries as packaging


class ExtractionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.framework = self.root / "libprobe.xcframework"
        self.framework.mkdir()
        self.destination = self.root / "output"
        self.device = self.entry("arbitrary-device-directory", b"device")
        self.simulator = self.entry("arbitrary-other-directory", b"simulator", "simulator")

    def entry(self, identifier, content, variant=None):
        directory = self.framework / identifier
        directory.mkdir()
        (directory / "actual-library-name.a").write_bytes(content)
        entry = {
            "LibraryIdentifier": identifier,
            "LibraryPath": "actual-library-name.a",
            "SupportedPlatform": "ios",
            "SupportedArchitectures": ["arm64"],
        }
        if variant is not None:
            entry["SupportedPlatformVariant"] = variant
        return entry

    def metadata(self, entries, fmt=plistlib.FMT_XML):
        (self.framework / "Info.plist").write_bytes(
            plistlib.dumps({"AvailableLibraries": entries}, fmt=fmt)
        )

    def test_device_selection_ignores_order_and_directory_names(self):
        catalyst = self.entry("another-directory", b"catalyst", "maccatalyst")
        for entries in ([self.simulator, catalyst, self.device],
                        [self.device, catalyst, self.simulator]):
            for fmt in (plistlib.FMT_XML, plistlib.FMT_BINARY):
                with self.subTest(entries=entries, fmt=fmt):
                    self.metadata(entries, fmt)
                    packaging.extract(self.root, self.destination)
                    self.assertEqual((self.destination / "libprobe.a").read_bytes(), b"device")

    def test_missing_device_or_wrong_platform_or_architecture_fails(self):
        for candidate in (self.simulator,
                          dict(self.device, SupportedPlatform="macos"),
                          dict(self.device, SupportedArchitectures=["x86_64"])):
            with self.subTest(candidate=candidate):
                self.metadata([candidate])
                with self.assertRaisesRegex(ValueError, "found 0"):
                    packaging.extract(self.root, self.destination)

    def test_ambiguous_device_fails(self):
        duplicate = self.entry("second-device", b"other device")
        self.metadata([self.device, duplicate])
        with self.assertRaisesRegex(ValueError, "found 2"):
            packaging.extract(self.root, self.destination)

    def test_missing_library_fails(self):
        self.metadata([dict(self.device, LibraryPath="missing.a")])
        with self.assertRaises(FileNotFoundError):
            packaging.extract(self.root, self.destination)

    def test_missing_metadata_exits_unsuccessfully(self):
        result = subprocess.run(
            [sys.executable, packaging.__file__, "extract", str(self.root), str(self.destination)],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Info.plist", result.stderr)

    def test_empty_input_fails(self):
        empty = self.root / "empty"
        empty.mkdir()
        with self.assertRaisesRegex(ValueError, "No XCFrameworks"):
            packaging.extract(empty, self.destination)
        with self.assertRaisesRegex(ValueError, "No static libraries"):
            packaging.validate(empty)


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        (self.directory / "libprobe.a").touch()

    def test_inspection_failure_is_fatal(self):
        failure = subprocess.CalledProcessError(1, "inspection")
        for results in ([failure], ["arm64", failure]):
            with self.subTest(results=results):
                with patch.object(packaging.subprocess, "check_output", side_effect=results):
                    with self.assertRaises(subprocess.CalledProcessError):
                        packaging.validate(self.directory)

    def test_missing_arm64_fails(self):
        with patch.object(packaging.subprocess, "check_output", return_value="x86_64"):
            with self.assertRaisesRegex(ValueError, "missing arm64"):
                packaging.validate(self.directory)

    def test_missing_or_incomplete_build_records_fail(self):
        for output in ("", "      cmd LC_BUILD_VERSION\n"):
            with self.subTest(output=output):
                with patch.object(packaging.subprocess, "check_output", side_effect=["arm64", output]):
                    with self.assertRaisesRegex(ValueError, "not an iOS device"):
                        packaging.validate(self.directory)


@unittest.skipUnless(sys.platform == "darwin", "Requires Xcode Mach-O tools")
class MachOTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temp.cleanup)
        cls.root = Path(cls.temp.name)
        source = cls.root / "probe.c"
        source.write_text("int probe(void) { return 42; }\n")
        for name, target, sdk in (
            ("device", "arm64-apple-ios14.0", "iphoneos"),
            ("legacy", "arm64-apple-ios11.0", "iphoneos"),
            ("simulator", "arm64-apple-ios14.0-simulator", "iphonesimulator"),
            ("mac", "arm64-apple-macos11", "macosx"),
        ):
            directory = cls.root / name
            directory.mkdir()
            sdk_path = subprocess.check_output(
                ["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True
            ).strip()
            subprocess.run(
                ["xcrun", "clang", "-target", target, "-isysroot", sdk_path,
                 "-c", str(source), "-o", str(directory / "probe.o")], check=True
            )
            subprocess.run(
                ["xcrun", "ar", "rcs", str(directory / "libprobe.a"), str(directory / "probe.o")],
                check=True,
            )

    def test_modern_and_legacy_device_libraries_pass(self):
        for name in ("device", "legacy"):
            with self.subTest(name=name):
                packaging.validate(self.root / name)

    def test_simulator_and_mac_libraries_fail(self):
        for name in ("simulator", "mac"):
            with self.subTest(name=name):
                with self.assertRaisesRegex(ValueError, "not an iOS device"):
                    packaging.validate(self.root / name)

    def test_mixed_archive_members_fail(self):
        mixed = self.root / "mixed"
        mixed.mkdir()
        subprocess.run(
            ["xcrun", "ar", "rcs", str(mixed / "libmixed.a"),
             str(self.root / "device/probe.o"), str(self.root / "simulator/probe.o")], check=True
        )
        with self.assertRaisesRegex(ValueError, "not an iOS device"):
            packaging.validate(mixed)

    def test_xcode_generated_xcframework_extracts_device(self):
        frameworks = self.root / "frameworks"
        frameworks.mkdir()
        subprocess.run(
            ["xcodebuild", "-create-xcframework",
             "-library", str(self.root / "simulator/libprobe.a"),
             "-library", str(self.root / "device/libprobe.a"),
             "-output", str(frameworks / "libprobe.xcframework")],
            check=True, capture_output=True,
        )
        output = self.root / "extracted"
        packaging.extract(frameworks, output)
        self.assertEqual((output / "libprobe.a").read_bytes(),
                         (self.root / "device/libprobe.a").read_bytes())
        packaging.validate(output)
        # A separately copied third-party library must also be checked.
        (output / "libthirdparty.a").write_bytes((self.root / "simulator/libprobe.a").read_bytes())
        with self.assertRaisesRegex(ValueError, "libthirdparty.a"):
            packaging.validate(output)


if __name__ == "__main__":
    unittest.main()
