"""Exercise the verifier's real macOS CLI plumbing before a long artifact build."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile


@unittest.skipUnless(sys.platform == 'darwin', 'requires macOS universal executables')
class HostToolsVerificationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='host-tools-verifier-')
        cls.root = Path(cls.temporary.name)
        source = cls.root / 'tool.c'
        # Fixtures exercise lipo invocation, process status and emitted-file
        # checks. Actual WGSL compilation is checked against the built archive.
        source.write_text(r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static void write_file(const char *name) {
    FILE *f = fopen(name, "w");
    if (!f) exit(2);
    fputs("fixture output", f);
    fclose(f);
}
int main(int argc, char **argv) {
    const char *name = strrchr(argv[0], '/');
    name = name ? name + 1 : argv[0];
    if (strcmp(name, "matc") == 0) {
        if (getenv("TEST_MATC_FAIL")) return 3;
        for (int i = 1; i + 1 < argc; i++) {
            if (strcmp(argv[i], "-o") == 0) write_file(argv[i + 1]);
        }
    } else {
        const char *directory = NULL;
        const char *prefix = NULL;
        for (int i = 1; i + 1 < argc; i++) {
            if (strcmp(argv[i], "-x") == 0) directory = argv[i + 1];
            if (strcmp(argv[i], "-p") == 0) prefix = argv[i + 1];
        }
        if (!directory || !prefix) return 4;
        char path[4096];
        snprintf(path, sizeof(path), "%s%s.c", directory, prefix);
        write_file(path);
        if (!getenv("TEST_RESGEN_MISSING_HEADER")) {
            snprintf(path, sizeof(path), "%s%s.h", directory, prefix);
            write_file(path);
        }
    }
    return 0;
}
''')
        cls.binary = cls.root / 'universal-tool'
        subprocess.run(['xcrun', 'clang', '-arch', 'arm64', '-arch', 'x86_64',
                        str(source), '-o', str(cls.binary)], check=True)
        cls.archive = cls.root / 'tools.zip'
        with zipfile.ZipFile(cls.archive, 'w') as archive:
            for name in ['matc', 'resgen']:
                archive.write(cls.binary, f'bin/{name}')

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def verify(self, archive=None, **environment):
        return subprocess.run([sys.executable, str(Path(__file__).with_name('verify-material-host-tools.py')),
                               str(archive or self.archive)], capture_output=True, text=True,
                              env={**os.environ, **environment})

    def test_universal_tools_and_emitted_files_pass(self):
        result = self.verify()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_thin_tool_is_rejected(self):
        thin = self.root / 'thin-tool'
        subprocess.run(['lipo', str(self.binary), '-thin', 'arm64', '-output', str(thin)], check=True)
        archive_path = self.root / 'thin.zip'
        with zipfile.ZipFile(archive_path, 'w') as archive:
            archive.write(thin, 'bin/matc')
            archive.write(self.binary, 'bin/resgen')
        self.assertNotEqual(self.verify(archive_path).returncode, 0)

    def test_compiler_failure_is_rejected(self):
        self.assertNotEqual(self.verify(TEST_MATC_FAIL='1').returncode, 0)

    def test_missing_generated_header_is_rejected(self):
        self.assertNotEqual(self.verify(TEST_RESGEN_MISSING_HEADER='1').returncode, 0)


if __name__ == '__main__':
    unittest.main()
