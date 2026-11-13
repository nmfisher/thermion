"""Regression tests for the Filament -> C -> bindings -> public Dart contract."""
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


class CommittedEnumTests(unittest.TestCase):
    def setUp(self):
        self.block = generator.emit_enum_block(CONSTANTS)

    def test_expression_is_rejected_instead_of_matching_a_numeric_prefix(self):
        with self.assertRaisesRegex(ValueError, "unsupported TBackend enumerator"):
            generator.normalize(self.block.replace("BACKEND_NOOP = 5,", "BACKEND_NOOP = 5 - 1,"))

    def test_commented_out_member_is_missing(self):
        for comment in ["// BACKEND_NOOP = 5,", "/* BACKEND_NOOP = 5, */"]:
            with self.subTest(comment=comment):
                self.assertNotEqual(generator.normalize(self.block), generator.normalize(
                    self.block.replace("BACKEND_NOOP = 5,", comment)))

    def test_additional_implicit_member_is_detected(self):
        actual = generator.normalize(self.block.replace("\n};", "\n    BACKEND_EXTRA,\n};"))
        self.assertEqual(actual[-1], "BACKEND_EXTRA=6")
        self.assertNotEqual(actual, generator.normalize(self.block))

    def test_comment_with_assignment_does_not_change_values(self):
        altered = self.block.replace("BACKEND_NOOP = 5,", "BACKEND_NOOP = 5, // previous = 4")
        self.assertEqual(generator.normalize(self.block), generator.normalize(altered))

    def test_implicit_numbering_matches_explicit_values(self):
        implicit = "enum TBackend {" + ",".join("BACKEND_" + name for name, _, _ in CONSTANTS) + "};"
        self.assertEqual(generator.normalize(implicit), generator.normalize(self.block))

    def test_duplicate_members_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            generator.normalize("enum TBackend { BACKEND_DEFAULT, BACKEND_DEFAULT };")

    def test_commented_enum_is_not_the_committed_definition(self):
        source = "/* enum TBackend { BACKEND_FAKE = 12 }; */\n" + self.block
        match = generator.enum_match(source)
        self.assertEqual(source[match.start():match.end()], self.block)


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
                enum = generator.emit_enum_block(CONSTANTS)
                if changed:
                    enum = enum.replace("BACKEND_NOOP = 5", "BACKEND_NOOP = 4")
                source.write_text(upstream + enum + "\n" + assertions)
                result = subprocess.run(["clang", "-x", "c++", "-std=c++17", "-fsyntax-only", str(source)], capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, not changed, result.stderr)


class MirrorChainTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.header = root / "TEngine.h"
        self.dart = root / "backend.g.dart"
        self.bindings = [root / "ffi.dart", root / "js.dart"]
        for name, value in [("TENGINE_H", str(self.header)), ("DART_BACKEND", self.dart), ("BINDINGS", self.bindings)]:
            context = patch.object(generator, name, value)
            context.start()
            self.addCleanup(context.stop)
        self.write_all(CONSTANTS)

    def write_all(self, constants):
        self.header.write_text(generator.emit_enum_block(constants))
        self.dart.write_text(generator.emit_dart_backend(constants))
        for path in self.bindings:
            path.write_text("sealed class TBackend {\n" + "\n".join(
                "static const BACKEND_%s = %d;" % (name, value) for name, value, _ in constants) + "\n}")

    def test_complete_chain_matches(self):
        self.assertEqual(generator.check_mirrors(CONSTANTS), [])

    def test_reshuffle_requires_both_binding_layers_to_be_regenerated(self):
        changed = [(name, 5 if name == "WEBGPU" else 4 if name == "NOOP" else value, comment)
                   for name, value, comment in CONSTANTS]
        self.header.write_text(generator.emit_enum_block(changed))
        self.dart.write_text(generator.emit_dart_backend(changed))
        self.assertEqual(len(generator.check_mirrors(changed)), 2)
        self.write_all(changed)
        self.assertEqual(generator.check_mirrors(changed), [])
        self.assertIn("NOOP(bindings.TBackend.BACKEND_NOOP)", self.dart.read_text())
        self.assertNotIn("NOOP(5)", self.dart.read_text())

    def test_added_member_requires_public_enum_and_both_binding_layers(self):
        added = CONSTANTS + [("EXTRA", 6, "")]
        self.header.write_text(generator.emit_enum_block(added))
        self.assertEqual(len(generator.check_mirrors(added)), 3)
        self.write_all(added)
        self.assertEqual(generator.check_mirrors(added), [])
        self.assertIn("EXTRA(bindings.TBackend.BACKEND_EXTRA)", self.dart.read_text())

    def test_handwritten_public_value_is_rejected(self):
        self.dart.write_text(self.dart.read_text().replace("NOOP(bindings.TBackend.BACKEND_NOOP)", "NOOP(5)"))
        self.assertEqual(len(generator.check_mirrors(CONSTANTS)), 1)

    @unittest.skipUnless(shutil.which("clang"), "Clang is required for the CLI fixture")
    def test_check_cli_status_for_each_reviewed_text_mutation(self):
        root = Path(self.temp.name)
        header = root / "backend/DriverEnums.h"
        header.parent.mkdir()
        header.write_text("namespace filament::backend { enum class Backend { DEFAULT, OPENGL, VULKAN, METAL, WEBGPU, NOOP }; }")
        block = generator.emit_enum_block(CONSTANTS)
        cases = [
            ("expression", block.replace("BACKEND_NOOP = 5,", "BACKEND_NOOP = 5 - 1,"), 1),
            ("commented member", block.replace("BACKEND_NOOP = 5,", "// BACKEND_NOOP = 5,"), 1),
            ("implicit addition", block.replace("\n};", "\nBACKEND_EXTRA,\n};"), 1),
            ("comment only", block.replace("BACKEND_NOOP = 5,", "BACKEND_NOOP = 5, // previous = 4"), 0),
        ]
        for name, altered, expected in cases:
            with self.subTest(case=name):
                self.header.write_text(altered)
                output = io.StringIO()
                with patch("sys.argv", ["generate_tbackend.py", "--check", "--filament-include", str(root)]), contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                    try:
                        generator.main()
                        actual = 0
                    except SystemExit as error:
                        actual = error.code if isinstance(error.code, int) else 1
                self.assertEqual(actual, expected, output.getvalue())

    def test_checker_rejects_committed_expression(self):
        self.header.write_text(self.header.read_text().replace("BACKEND_NOOP = 5,", "BACKEND_NOOP = 5 - 1,"))
        with self.assertRaisesRegex(ValueError, "unsupported"):
            generator.check_mirrors(CONSTANTS)


if __name__ == "__main__":
    unittest.main()
