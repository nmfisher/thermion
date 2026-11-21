"""Prepare equivalent controls for the Windows morph-target diagnosis."""
import copy
import json
import math
from pathlib import Path
import struct

root = Path('examples/assets')
source = (root / 'cube_with_morph_targets.glb').read_bytes()
n = struct.unpack_from('<I', source, 12)[0]
doc = json.loads(source[20:20+n])
binary = source[28+n:]


def write(name, doc, data):
    chunk = json.dumps(doc, separators=(',', ':')).encode()
    chunk += b' ' * (-len(chunk) % 4)
    assert len(data) % 4 == 0
    (root / (name+'.glb')).write_bytes(
        struct.pack('<4sII', b'glTF', 2, len(data)+len(chunk)+28)
        + struct.pack('<I4s', len(chunk), b'JSON') + chunk
        + struct.pack('<I4s', len(data), b'BIN\0') + data)


explicit = copy.deepcopy(doc)
explicit['materials'] = [{}]
explicit['meshes'][0]['primitives'][0]['material'] = 0
write('probe_morph_explicit', explicit, binary)

baked = copy.deepcopy(doc)
data = bytearray(binary)
mesh = baked['meshes'][0]
primitive = mesh['primitives'][0]
target, = primitive.pop('targets')
mesh.pop('weights', None)
mesh.get('extras', {}).pop('targetNames', None)
baked.pop('animations', None)
for node in baked['nodes']:
    node.pop('weights', None)

def layout(i):
    a = baked['accessors'][i]
    v = baked['bufferViews'][a['bufferView']]
    assert a['componentType'] == 5126 and a['type'] == 'VEC3' and 'sparse' not in a
    return a['count'], v.get('byteOffset', 0)+a.get('byteOffset', 0), v.get('byteStride', 12)

for attr in ['POSITION', 'NORMAL']:
    index = primitive['attributes'][attr]
    count, start, stride = layout(index)
    cnt, tstart, tstride = layout(target[attr])
    assert cnt == count
    values = []
    for i in range(count):
        offset = start+i*stride
        v = struct.unpack_from('<3f', binary, offset)
        ds = struct.unpack_from('<3f', binary, tstart+i*tstride)
        vs = [a+b for a,b in zip(v,ds)]
        if attr=='NORMAL':
            norm = math.sqrt(sum(v*v for v in vs))
            vs = [v/norm for v in vs]
        struct.pack_into('<3f', data, offset, *vs)
        values.append(vs)
    if attr == 'POSITION':
        baked['accessors'][index].update(min=list(map(min,zip(*values))),max=list(map(max,zip(*values))))
write('probe_morph_baked', baked, data)
