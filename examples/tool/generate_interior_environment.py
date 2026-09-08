"""Generate the demo's linear RGBA8 outdoor cubemap (KTX1), using only stdlib.

Run from any directory: python3 examples/tool/generate_interior_environment.py
The sky, clouds and distant buildings are procedural; no external image assets.
"""

import math
from pathlib import Path
import struct


def mix(a, b, t):
    return tuple(x * (1 - t) + y * t for x, y in zip(a, b))


def environment(x, y, z):
    elevation = math.atan2(y, math.hypot(x, z))
    azimuth = math.atan2(z, x) % math.tau
    sky = mix((0.58, 0.72, 0.86), (0.07, 0.22, 0.49),
              min(1, max(0, elevation / 1.2)))
    clouds = math.sin(azimuth * 3 + elevation * 8) + math.sin(azimuth * 7 - elevation * 5)
    cloud = min(1, max(0, (clouds - 0.7) * 2)) * min(1, max(0, elevation * 3))
    sky = mix(sky, (0.95, 0.95, 0.91), cloud)

    # Angular silhouettes of a distant city, with window rows that make the
    # reflection's motion and orientation easy to distinguish from a tint.
    sector = azimuth / math.tau * 24
    building = math.floor(sector)
    variation = (math.sin(building * 127.1 + 17.3) * 43758.5453) % 1
    roof = 0.08 + variation * 0.40
    if elevation < -0.30:
        return (0.09, 0.095, 0.10)
    if elevation < roof:
        facade = mix((0.035, 0.055, 0.07), (0.16, 0.14, 0.115), variation)
        horizontal = (sector * 3) % 1
        vertical = ((elevation + 0.30) / 0.055) % 1
        if 0.20 < horizontal < 0.75 and 0.22 < vertical < 0.76:
            return mix((0.10, 0.24, 0.36), sky, 0.35)
        return facade
    return sky


def main():
    size = 256
    result = bytearray(b'\xabKTX 11\xbb\r\n\x1a\n')
    result += struct.pack('<13I', 0x04030201, 0x1401, 1, 0x1908,
                          0x8058, 0x1908, size, size, 0, 0, 6, 1, 0)
    result += struct.pack('<I', size * size * 4)
    for face in range(6):
        for row in range(size):
            t = 2 * (row + 0.5) / size - 1
            for col in range(size):
                s = 2 * (col + 0.5) / size - 1
                direction = ((1, -t, -s), (-1, -t, s), (s, 1, t),
                             (s, -1, -t), (s, -t, 1), (-s, -t, -1))[face]
                color = environment(*direction)
                result.extend(round(max(0, min(1, channel)) * 255) for channel in color)
                result.append(255)
    output = Path(__file__).resolve().parents[1] / 'assets/interior_environment.ktx'
    output.write_bytes(result)
    print(f'Wrote {output} ({len(result)} bytes)')


if __name__ == '__main__':
    main()
