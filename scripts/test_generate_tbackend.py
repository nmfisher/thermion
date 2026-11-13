"""Regression tests for Clang extraction and generator-owned backend files."""
import contextlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import generate_tbackend as generator

CONSTANTS = [(name, value, "") for value, name in enumerate(
    ["DEFAULT", "OPENGL", "VULKAN", "METAL", "WEBGPU", "NOOP"])]
ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("clang"), "Clang is required for real AST fixtures")
class ClangExtractionTests(unittest.TestCase):
    def extract(self, body, extra=""):
        with tempfile.TemporaryDirectory() as directory:
            header = Path(directory) / "backend/DriverEnums.h"
            header.parent.mkdir()
            header.write_text("namespace filament::backend { enum class Backend {" + body + "}; " + extra + " }\n")
            return generator.dump_backend_enum([directory], "clang")[1]

    def test_explicit_values(self):
        self.assertEqual(self.extract("DEFAULT=0, OPENGL=1, VULKAN=2, METAL=3, WEBGPU=4, NOOP=5"), CONSTANTS)

    def test_implicit_values(self):
        self.assertEqual(self.extract("DEFAULT, OPENGL, VULKAN, METAL, WEBGPU, NOOP"), CONSTANTS)

    def test_explicit_expression_followed_by_implicit_values(self):
        self.assertEqual(self.extract("DEFAULT=2, OPENGL, VULKAN=1 << 3, METAL"),
                         [("DEFAULT", 2, ""), ("OPENGL", 3, ""), ("VULKAN", 8, ""), ("METAL", 9, "")])

    def test_unrelated_prefixed_declarations_and_forward_declaration(self):
        self.assertEqual(self.extract("DEFAULT, OPENGL", "struct BackendCapabilities {}; enum class Backend;") ,
                         [("DEFAULT", 0, ""), ("OPENGL", 1, "")])

    def test_exact_qualified_enum_is_selected_over_a_substring_match(self):
        with tempfile.TemporaryDirectory() as directory:
            header = Path(directory) / "backend/DriverEnums.h"
            header.parent.mkdir()
            header.write_text("namespace other::filament::backend { enum class Backend { WRONG=99 }; }\n"
                              "namespace filament::backend { enum class Backend { DEFAULT, OPENGL }; }")
            self.assertEqual(generator.dump_backend_enum([directory], "clang")[1],
                             [("DEFAULT", 0, ""), ("OPENGL", 1, "")])

    def test_json_document_stream(self):
        declarations = [{"kind": "EnumDecl"}, {"kind": "CXXRecordDecl"}]
        self.assertEqual(list(generator.json_documents("\n".join(map(json.dumps, declarations)))), declarations)

    def test_native_assertions_pass_and_reject_value_drift(self):
        cpp = (ROOT / "thermion_dart/native/src/c_api/TEngine.cpp").read_text()
        assertions = cpp[cpp.index("static_assert("):cpp.index("#ifdef __cplusplus")]
        upstream = "namespace filament::backend { enum class Backend { DEFAULT, OPENGL, VULKAN, METAL, WEBGPU, NOOP }; }\n"
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "contract.cpp"
            for changed in [False, True]:
                enum = generator.emit_c_backend(CONSTANTS)
                if changed:
                    enum = enum.replace("BACKEND_NOOP = 5", "BACKEND_NOOP = 4")
                (Path(directory) / "TBackend.h").write_text(enum)
                source.write_text(upstream + '#include "TBackend.h"\n' + assertions)
                result = subprocess.run(["clang", "-x", "c++", "-std=c++17", "-fsyntax-only", str(source)], capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, not changed, result.stderr)


class GeneratedOutputTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.header = root / "TBackend.h"
        self.dart = root / "backend.g.dart"
        for name, value in [("TBACKEND_H", self.header), ("DART_BACKEND", self.dart)]:
            context = patch.object(generator, name, value)
            context.start()
            self.addCleanup(context.stop)
        self.write_outputs(CONSTANTS)

    def write_outputs(self, constants):
        for path, output in generator.generated_outputs(constants).items():
            path.write_text(output)

    def test_generated_files_match(self):
        self.assertEqual(generator.check_generated(CONSTANTS), [])

    def test_missing_file_fails(self):
        self.dart.unlink()
        self.assertTrue(generator.check_generated(CONSTANTS))

    def test_reshuffle_changes_c_values_and_dart_retains_constant_references(self):
        changed = [(name, 5 if name == "WEBGPU" else 4 if name == "NOOP" else value, comment)
                   for name, value, comment in CONSTANTS]
        self.assertTrue(generator.check_generated(changed))
        self.write_outputs(changed)
        self.assertEqual(generator.check_generated(changed), [])
        self.assertIn("BACKEND_NOOP = 4", self.header.read_text())
        self.assertIn("NOOP(bindings.TBackend.BACKEND_NOOP)", self.dart.read_text())
        self.assertNotIn("NOOP(5)", self.dart.read_text())

    def test_added_member_updates_both_outputs(self):
        added = CONSTANTS + [("EXTRA", 6, "")]
        differences = "\n".join(generator.check_generated(added))
        self.assertIn("TBackend.h", differences)
        self.assertIn("backend.g.dart", differences)
        self.write_outputs(added)
        self.assertEqual(generator.check_generated(added), [])
        self.assertIn("EXTRA(bindings.TBackend.BACKEND_EXTRA)", self.dart.read_text())

    def test_handwritten_public_value_is_rejected(self):
        self.dart.write_text(self.dart.read_text().replace("NOOP(bindings.TBackend.BACKEND_NOOP)", "NOOP(5)"))
        self.assertTrue(generator.check_generated(CONSTANTS))

    @unittest.skipUnless(shutil.which("clang"), "Clang is required for the CLI fixture")
    def test_check_and_write_cli_for_manual_edits(self):
        root = Path(self.temp.name)
        header = root / "backend/DriverEnums.h"
        header.parent.mkdir()
        header.write_text("namespace filament::backend { enum class Backend { DEFAULT, OPENGL, VULKAN, METAL, WEBGPU, NOOP }; }")
        original = generator.emit_c_backend(CONSTANTS)
        cases = [
            ("unchanged", original, 0),
            ("expression", original.replace("BACKEND_NOOP = 5,", "BACKEND_NOOP = 5 - 1,"), 1),
            ("commented member", original.replace("BACKEND_NOOP = 5,", "// BACKEND_NOOP = 5,"), 1),
            ("implicit addition", original.replace("\n};", "\nBACKEND_EXTRA,\n};"), 1),
            ("comment only", original.replace("BACKEND_NOOP = 5,", "BACKEND_NOOP = 5, // previous = 4"), 1),
            ("format only", original.replace("    BACKEND_NOOP", "  BACKEND_NOOP"), 1),
        ]
        for name, altered, expected in cases:
            with self.subTest(case=name):
                self.header.write_text(altered)
                self.assertEqual(self.run_cli("--check", root), expected)
                self.assertEqual(self.run_cli("--write", root), 0)
                self.assertEqual(self.header.read_text(), original)
                self.assertEqual(self.run_cli("--check", root), 0)

    def run_cli(self, mode, include):
        output = io.StringIO()
        with patch("sys.argv", ["generate_tbackend.py", mode, "--filament-include", str(include)]), contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            try:
                generator.main()
                return 0
            except SystemExit as error:
                return error.code if isinstance(error.code, int) else 1


if __name__ == "__main__":
    unittest.main()
