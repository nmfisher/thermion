#!/usr/bin/env python3
"""Execute matc/resgen from a host archive before it can be published."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archives', nargs='+', type=Path)
args = parser.parse_args()
for archive in args.archives:
    with tempfile.TemporaryDirectory(prefix='thermion-host-tools-') as temporary:
        root = Path(temporary)
        suffix = '.exe' if os.name == 'nt' else ''
        with zipfile.ZipFile(archive) as package:
            for name in ['matc', 'resgen']:
                destination = root / f'{name}{suffix}'
                destination.write_bytes(package.read(f'bin/{name}{suffix}'))
                destination.chmod(0o755)
                if sys.platform == 'darwin':
                    subprocess.run(['lipo', str(destination), '-verify_arch', 'arm64', 'x86_64'], check=True)
        material = root / 'smoke.mat'
        material.write_text('material { name : HostToolsSmoke, shadingModel : unlit }\n')
        output = root / 'smoke.filamat'
        subprocess.run([str(root / f'matc{suffix}'), '-a', 'webgpu', '-o', str(output), str(material)], check=True)
        assert output.stat().st_size > 0, 'matc produced an empty package'
        subprocess.run([str(root / f'resgen{suffix}'), '-c', '-p', 'smoke', '-x', str(root) + os.sep, str(output)], check=True)
        for name in ['smoke.c', 'smoke.h']:
            assert (root / name).stat().st_size > 0, f'resgen did not produce {name}'
        print(f'{archive}: WebGPU matc + resgen passed', flush=True)
