#!/usr/bin/env python3
"""Generates glTF fixtures used by thermion_dart/test/rebuild_vertices_morph_tests.dart.

Both fixtures are plain (non-skinned, default lit material) indexed cube meshes
with morph targets, authored so that "load with rebuildVertices: true" must
produce the same rendered poses as a normal load:

  cube_with_morph_targets_sparse.glb
      Single primitive, one target ("Key 1"). The POSITION delta accessor is
      sparse (no bufferView base, overrides on even vertices only); the NORMAL
      delta accessor is dense. Exercises cgltf_accessor_unpack_floats' sparse
      handling on both load paths.

  cube_with_morph_targets_two_prims.glb
      One mesh, two primitives (two cubes side by side), two targets
      ("Grow", "Shift"). Prim 1 omits the "Shift" POSITION delta entirely
      (zero-delta path) and neither primitive has NORMAL deltas. Exercises
      per-primitive morph buffer offsets and missing-attribute handling.

Run from the repository root:
    python3 scripts/generate_morph_fixtures.py
"""

import json
import struct
from pathlib import Path

ASSETS_DIR = Path(__file__).resolve().parent.parent / "examples" / "assets"

# ---------------------------------------------------------------------------
# GLB writing


def build_glb(gltf: dict, blob: bytes) -> bytes:
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    bin_bytes = blob + b"\x00" * ((4 - len(blob) % 4) % 4)
    assert len(json_bytes) % 4 == 0 and len(bin_bytes) % 4 == 0

    total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    out = struct.pack("<III", 0x46546C67, 2, total)  # magic, version, length
    out += struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes
    out += struct.pack("<II", len(bin_bytes), 0x004E4942) + bin_bytes
    return out


class BufferBuilder:
    """Accumulates buffer views over one growing binary blob."""

    def __init__(self):
        self.blob = bytearray()
        self.views = []

    def add_view(self, data: bytes) -> int:
        # Keep every view 4-byte aligned.
        self.blob += b"\x00" * ((4 - len(self.blob) % 4) % 4)
        offset = len(self.blob)
        self.blob += data
        self.views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(data)})
        return len(self.views) - 1


def floats(values):
    return struct.pack("<%df" % len(values), *values)


def uint16s(values):
    return struct.pack("<%dH" % len(values), *values)


# ---------------------------------------------------------------------------
# Cube geometry: 24 vertices (4 per face), 36 indices, per-face normals/uv.


def cube_geometry(offset=(0.0, 0.0, 0.0)):
    faces = [
        # (normal, right, up) with right x up == normal (CCW from outside)
        ((0.0, 0.0, 1.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)),
        ((0.0, 0.0, -1.0), (-1.0, 0.0, 0.0), (0.0, 1.0, 0.0)),
        ((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)),
        ((-1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)),
        ((0.0, 1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, -1.0)),
        ((0.0, -1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
    ]
    positions, normals, uvs, indices = [], [], [], []
    for n, r, u in faces:
        base = len(positions)
        for corner, uv in zip(
            [(-1, -1), (1, -1), (1, 1), (-1, 1)],
            [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)],
        ):
            sx, sy = corner
            positions.append(
                [
                    offset[0] + 0.5 * (n[0] + sx * r[0] + sy * u[0]),
                    offset[1] + 0.5 * (n[1] + sx * r[1] + sy * u[1]),
                    offset[2] + 0.5 * (n[2] + sx * r[2] + sy * u[2]),
                ]
            )
            normals.append(list(n))
            uvs.append(list(uv))
        indices += [base + 0, base + 1, base + 2, base + 0, base + 2, base + 3]
    return positions, normals, uvs, indices


def component_min_max(values, components):
    cols = list(zip(*[values[i : i + components] for i in range(0, len(values), components)]))
    return [min(c) for c in cols], [max(c) for c in cols]


# ---------------------------------------------------------------------------
# Fixture 1: single primitive, sparse POSITION delta + dense zero NORMAL delta.


def build_sparse_fixture() -> bytes:
    positions, normals, uvs, indices = cube_geometry()
    vertex_count = len(positions)

    buffer = BufferBuilder()

    pos_view = buffer.add_view(floats([c for p in positions for c in p]))
    nrm_view = buffer.add_view(floats([c for n in normals for c in n]))
    uv_view = buffer.add_view(floats([c for uv in uvs for c in uv]))
    idx_view = buffer.add_view(uint16s(indices))

    # Dense zero NORMAL deltas.
    zero_normals = [0.0] * (vertex_count * 3)
    nrm_delta_view = buffer.add_view(floats(zero_normals))

    # Sparse POSITION deltas: no bufferView (zero base); even vertices get
    # pushed up and sideways, odd vertices keep the zero-base delta.
    sparse_indices = list(range(0, vertex_count, 2))
    sparse_values = []
    for _ in sparse_indices:
        sparse_values += [0.25, 0.4, 0.0]

    sparse_idx_view = buffer.add_view(uint16s(sparse_indices))
    sparse_val_view = buffer.add_view(floats(sparse_values))

    pos_flat = [c for p in positions for c in p]
    pos_min, pos_max = component_min_max(pos_flat, 3)

    gltf = {
        "asset": {"version": "2.0", "generator": "thermion fixture generator"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "Cube", "mesh": 0}],
        "meshes": [
            {
                "name": "Cube",
                "weights": [0.0],
                "extras": {"targetNames": ["Key 1"]},
                "primitives": [
                    {
                        "attributes": {
                            "POSITION": 0,
                            "NORMAL": 1,
                            "TEXCOORD_0": 2,
                        },
                        "indices": 3,
                        "targets": [
                            {
                                "POSITION": 4,
                                "NORMAL": 5,
                            }
                        ],
                    }
                ],
            }
        ],
        "bufferViews": buffer.views,
        "accessors": [
            {
                "bufferView": pos_view,
                "componentType": 5126,
                "count": vertex_count,
                "type": "VEC3",
                "min": pos_min,
                "max": pos_max,
            },
            {"bufferView": nrm_view, "componentType": 5126, "count": vertex_count, "type": "VEC3"},
            {"bufferView": uv_view, "componentType": 5126, "count": vertex_count, "type": "VEC2"},
            {
                "bufferView": idx_view,
                "componentType": 5123,
                "count": len(indices),
                "type": "SCALAR",
            },
            # 4: sparse POSITION deltas (no bufferView -> zero base).
            {
                "componentType": 5126,
                "count": vertex_count,
                "type": "VEC3",
                "sparse": {
                    "count": len(sparse_indices),
                    "indices": {"bufferView": sparse_idx_view, "componentType": 5123},
                    "values": {"bufferView": sparse_val_view},
                },
            },
            # 5: dense zero NORMAL deltas.
            {"bufferView": nrm_delta_view, "componentType": 5126, "count": vertex_count, "type": "VEC3"},
        ],
        "buffers": [{"byteLength": len(buffer.blob)}],
    }
    return build_glb(gltf, bytes(buffer.blob))


# ---------------------------------------------------------------------------
# Fixture 2: one mesh, two primitives, two targets; prim 1 target "Shift"
# has no accessors at all (zero delta).


def build_two_prim_fixture() -> bytes:
    pos_a, nrm_a, uv_a, idx_a = cube_geometry(offset=(-0.75, 0.0, 0.0))
    pos_b, nrm_b, uv_b, idx_b = cube_geometry(offset=(0.75, 0.0, 0.0))

    buffer = BufferBuilder()

    def add_mesh_data(positions, normals, uvs, indices):
        pos_view = buffer.add_view(floats([c for p in positions for c in p]))
        nrm_view = buffer.add_view(floats([c for n in normals for c in n]))
        uv_view = buffer.add_view(floats([c for uv in uvs for c in uv]))
        idx_view = buffer.add_view(uint16s(indices))
        return pos_view, nrm_view, uv_view, idx_view

    pos_a_view, nrm_a_view, uv_a_view, idx_a_view = add_mesh_data(pos_a, nrm_a, uv_a, idx_a)
    pos_b_view, nrm_b_view, uv_b_view, idx_b_view = add_mesh_data(pos_b, nrm_b, uv_b, idx_b)

    # "Grow": push every vertex out along its face normal by 0.2.
    def grow_deltas(normals):
        return [0.2 * c for n in normals for c in n]

    grow_a_view = buffer.add_view(floats(grow_deltas(nrm_a)))
    grow_b_view = buffer.add_view(floats(grow_deltas(nrm_b)))

    # "Shift": translate prim A sideways (prim B omits the delta entirely).
    shift_a = [0.3, 0.0, 0.0] * len(pos_a)
    shift_a_view = buffer.add_view(floats(shift_a))

    accessors = []

    def add_accessor(view, component_type, count, type_, minmax=None):
        accessor = {
            "bufferView": view,
            "componentType": component_type,
            "count": count,
            "type": type_,
        }
        if minmax:
            accessor["min"], accessor["max"] = minmax
        accessors.append(accessor)
        return len(accessors) - 1

    pos_a_flat = [c for p in pos_a for c in p]
    pos_b_flat = [c for p in pos_b for c in p]

    a_pos = add_accessor(pos_a_view, 5126, len(pos_a), "VEC3", component_min_max(pos_a_flat, 3))
    a_nrm = add_accessor(nrm_a_view, 5126, len(pos_a), "VEC3")
    a_uv = add_accessor(uv_a_view, 5126, len(pos_a), "VEC2")
    a_idx = add_accessor(idx_a_view, 5123, len(idx_a), "SCALAR")
    b_pos = add_accessor(pos_b_view, 5126, len(pos_b), "VEC3", component_min_max(pos_b_flat, 3))
    b_nrm = add_accessor(nrm_b_view, 5126, len(pos_b), "VEC3")
    b_uv = add_accessor(uv_b_view, 5126, len(pos_b), "VEC2")
    b_idx = add_accessor(idx_b_view, 5123, len(idx_b), "SCALAR")
    a_grow = add_accessor(grow_a_view, 5126, len(pos_a), "VEC3")
    b_grow = add_accessor(grow_b_view, 5126, len(pos_b), "VEC3")
    a_shift = add_accessor(shift_a_view, 5126, len(pos_a), "VEC3")

    gltf = {
        "asset": {"version": "2.0", "generator": "thermion fixture generator"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "TwoCubes", "mesh": 0}],
        "meshes": [
            {
                "name": "TwoCubes",
                "weights": [0.0, 0.0],
                "extras": {"targetNames": ["Grow", "Shift"]},
                "primitives": [
                    {
                        "attributes": {"POSITION": a_pos, "NORMAL": a_nrm, "TEXCOORD_0": a_uv},
                        "indices": a_idx,
                        "targets": [{"POSITION": a_grow}, {"POSITION": a_shift}],
                    },
                    {
                        "attributes": {"POSITION": b_pos, "NORMAL": b_nrm, "TEXCOORD_0": b_uv},
                        "indices": b_idx,
                        # No "Shift" delta on this primitive: zero delta.
                        "targets": [{"POSITION": b_grow}, {}],
                    },
                ],
            }
        ],
        "bufferViews": buffer.views,
        "accessors": accessors,
        "buffers": [{"byteLength": len(buffer.blob)}],
    }
    return build_glb(gltf, bytes(buffer.blob))


def main():
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    (ASSETS_DIR / "cube_with_morph_targets_sparse.glb").write_bytes(build_sparse_fixture())
    (ASSETS_DIR / "cube_with_morph_targets_two_prims.glb").write_bytes(build_two_prim_fixture())
    print(f"wrote fixtures to {ASSETS_DIR}")


if __name__ == "__main__":
    main()
