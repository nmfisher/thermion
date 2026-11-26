"""filament-artifact-url.py must mirror resolveFilamentArtifact (Dart hook)."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parent / 'filament-artifact-url.py'
BASE = 'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev'
SHA = 'ab' * 32


class FilamentArtifactUrlTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.pin = Path(self.temporary.name) / 'pin.json'

    def resolve(self, platform, variant='release', pin=None):
        self.pin.write_text(json.dumps(pin or {}))
        result = subprocess.run(
            [sys.executable, str(SCRIPT), platform, variant,
             '--version', 'v1.2.3', '--pin', str(self.pin)],
            text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def test_unpinned_legacy_key(self):
        self.assertEqual(self.resolve('web'), f'{BASE}/filament-v1.2.3-web-release.zip')

    def test_pinned_hash_key(self):
        self.assertEqual(self.resolve('web', pin={'web/release': SHA}),
                         f'{BASE}/filament-v1.2.3-web-release-{SHA[:16]}.zip')

    def test_webgpu_unpinned_legacy_key(self):
        self.assertEqual(self.resolve('web-webgpu'),
                         f'{BASE}/filament-v1.2.3-web-release-webgpu.zip')

    def test_webgpu_pinned_hash_key(self):
        self.assertEqual(self.resolve('linux-webgpu', pin={'linux-webgpu/release': SHA}),
                         f'{BASE}/filament-v1.2.3-linux-release-webgpu-{SHA[:16]}.zip')

    def test_webgpu_pin_does_not_fall_back_to_canonical(self):
        # A canonical web pin must not rename the -webgpu artifact.
        self.assertEqual(self.resolve('web-webgpu', pin={'web/release': SHA}),
                         f'{BASE}/filament-v1.2.3-web-release-webgpu.zip')


if __name__ == '__main__':
    unittest.main()
