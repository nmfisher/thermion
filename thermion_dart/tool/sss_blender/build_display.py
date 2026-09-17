"""Build the shared Filament ACES display helper (macOS/Linux).

Run sss_local.py first to stage the matching engine, then:
python3 build_display.py /path/to/filament
"""
import argparse
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('filament', type=Path)
parser.add_argument('--compiler', default='clang++')
args = parser.parse_args()
root = Path(__file__).resolve().parent
engine = args.filament.resolve()
stage = engine / 'stage'
output = root / ('display.dylib' if sys.platform == 'darwin' else 'display.so')
subprocess.run([args.compiler, '-std=c++17', '-O2', '-shared', '-fPIC',
                str(root / 'display.cpp'), '-I' + str(stage / 'include'),
                '-I' + str(engine / 'filament/src'), str(stage / 'libfilament.a'),
                str(stage / 'libutils.a'), '-o', str(output)], check=True)
print(output)
