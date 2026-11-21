"""Preprocess the production target selection with each platform's macros."""

from pathlib import Path
import re
import subprocess
import unittest


SOURCE = Path(__file__).resolve().parents[1] / 'thermion_dart/native/src/c_api/TMaterialCompiler.cpp'


class RuntimeMaterialPlatformTests(unittest.TestCase):
    def test_shader_model(self):
        source = SOURCE.read_text()
        selection = source.split('filamat::MaterialBuilder::Platform platformForThisBuild()', 1)[1]
        selection = selection.split('filamat::MaterialBuilder::TargetApi targetApiForThisBuild()', 1)[0]
        targets = [
            ('Android arm64', ['__ANDROID__', '__linux__', '__aarch64__'], 'MOBILE'),
            ('Android x64', ['__ANDROID__', '__linux__', '__x86_64__'], 'MOBILE'),
            ('Web', ['__EMSCRIPTEN__'], 'MOBILE'),
            ('iOS device', ['__APPLE__', 'TARGET_OS_IPHONE=1', '__aarch64__'], 'MOBILE'),
            ('iOS simulator', ['__APPLE__', 'TARGET_OS_IPHONE=1', 'TARGET_OS_SIMULATOR=1'], 'MOBILE'),
            ('macOS arm64', ['__APPLE__', 'TARGET_OS_IPHONE=0', '__aarch64__'], 'DESKTOP'),
            ('Linux arm64', ['__linux__', '__aarch64__'], 'DESKTOP'),
            ('Linux x64', ['__linux__', '__x86_64__'], 'DESKTOP'),
            ('Windows', ['_WIN32'], 'DESKTOP'),
        ]
        for name, defines, expected in targets:
            with self.subTest(target=name):
                result = subprocess.run(
                    ['c++', '-E', '-P', '-x', 'c++', '-undef', *['-D' + value for value in defines], '-'],
                    input=selection, text=True, capture_output=True, check=True)
                returned = re.findall(r'return filamat::MaterialBuilder::Platform::(\w+);', result.stdout)
                self.assertEqual(returned, [expected])


if __name__ == '__main__':
    unittest.main()
