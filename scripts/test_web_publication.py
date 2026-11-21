import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[1] / '.github/workflows/regenerate-bindings-and-materials.yml'
BUILD_DIRS = ['build', 'build-main-thread', 'build-runtime-materials', 'build-main-thread-runtime-materials']


def step_script(name):
    section = WORKFLOW.read_text().split(f'      - name: {name}\n', 1)[1]
    body = section.split('        run: |\n', 1)[1]
    lines = []
    for line in body.splitlines():
        if line.strip() and not line.startswith('          '):
            break
        lines.append(line[10:])
    return '\n'.join(lines) + '\n'


class WebPublicationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.workspace = Path(self.temporary.name)
        self.web = self.workspace / 'thermion_dart/native/web'
        self.bin = self.workspace / 'bin'
        self.bin.mkdir()
        (self.workspace / 'scripts').mkdir()
        (self.workspace / 'scripts/filament-artifact-url.py').write_text(
            "print('https://example.invalid/filament.zip')\n")
        (self.web / 'lib/release').mkdir(parents=True)
        for directory in BUILD_DIRS:
            output = self.web / directory / 'build/out'
            output.mkdir(parents=True)
            for name in ['thermion_dart.js', 'thermion_dart.wasm']:
                (output / name).write_bytes(b'engine')
        self.version = self.web / 'web.version'
        self.version.write_text('old-sha\n')
        self.count = self.workspace / 'uploads'
        self.env = dict(os.environ, GITHUB_WORKSPACE=str(self.workspace),
                        R2_ENDPOINT='https://example.invalid', UPLOAD_COUNT=str(self.count),
                        PATH=str(self.bin) + os.pathsep + os.environ['PATH'])
        self.command('git', 'echo deadbee\n')
        self.command('zip', 'touch "$1"\n')
        self.command('aws', '''
            count=0
            if [ -f "$UPLOAD_COUNT" ]; then count=$(cat "$UPLOAD_COUNT"); fi
            count=$((count + 1))
            echo "$count" > "$UPLOAD_COUNT"
            [ "$count" -ne "${FAIL_UPLOAD:-0}" ]
        ''')

    def command(self, name, script):
        path = self.bin / name
        path.write_text('#!/bin/sh\nset -eu\n' + textwrap.dedent(script))
        path.chmod(0o755)

    def run_step(self, name='Package and upload web artifacts to R2'):
        return subprocess.run(['bash', '-e', '-c', step_script(name)], cwd=self.workspace,
                              env=self.env, text=True, capture_output=True)

    def assert_pointer_unchanged(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.version.read_text(), 'old-sha\n')

    def test_missing_output_refuses_all_uploads_and_pointer_change(self):
        for directory in BUILD_DIRS:
            for name in ['thermion_dart.js', 'thermion_dart.wasm']:
                with self.subTest(directory=directory, name=name):
                    output = self.web / directory / 'build/out' / name
                    output.unlink()
                    self.assert_pointer_unchanged(self.run_step())
                    self.assertFalse(self.count.exists())
                    output.write_bytes(b'engine')

    def test_empty_output_refuses_publication(self):
        (self.web / 'build-main-thread-runtime-materials/build/out/thermion_dart.wasm').write_bytes(b'')
        self.assert_pointer_unchanged(self.run_step())
        self.assertFalse(self.count.exists())

    def test_failed_upload_leaves_existing_pointer(self):
        for failure in range(1, 5):
            with self.subTest(failure=failure):
                self.count.unlink(missing_ok=True)
                self.env['FAIL_UPLOAD'] = str(failure)
                self.assert_pointer_unchanged(self.run_step())
                self.assertEqual(int(self.count.read_text()), failure)

    def test_success_advances_pointer_only_after_four_uploads(self):
        result = self.run_step()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.count.read_text().strip(), '4')
        self.assertEqual(self.version.read_text(), 'deadbee\n')

    def test_missing_compiler_prerequisite_fails_both_runtime_builds(self):
        self.command('curl', 'exit 1\n')
        for name in ['Compile web (runtime-materials)', 'Compile web (main-thread runtime-materials)']:
            with self.subTest(name=name):
                result = self.run_step(name)
                self.assert_pointer_unchanged(result)
                self.assertIn('::error::', result.stdout)

    def test_version_commit_requires_successful_publication_step(self):
        step = WORKFLOW.read_text().split('      - name: Commit web.version\n', 1)[1]
        self.assertIn("steps.publish_web.outcome == 'success'", step.split('        env:', 1)[0])


if __name__ == '__main__':
    unittest.main()
