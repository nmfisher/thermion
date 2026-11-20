"""Generate the Dart and native built-in material IDs and package lookup."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / 'materials/built_in_materials.json').read_text())
if len(set(catalog.values())) != len(catalog):
    raise ValueError('Built-in material IDs must be unique')

generated = '// Generated from materials/built_in_materials.json by make bindings.\n'
dart = [generated, '/// Helper materials that can be embedded by the build.', 'enum BuiltInMaterial {']
ids = [generated, '#pragma once', '', 'typedef enum TBuiltInMaterial {']
includes = []
cases = []
for key, native_id in catalog.items():
    first, *rest = key.split('_')
    name = first + ''.join(part.title() for part in rest)
    symbol = key.upper()
    dart.append(f"  {name}({native_id}, '{key}'),")
    ids.append(f'    BUILT_IN_{symbol} = {native_id},')
    includes.extend([f'#ifdef {symbol}_ENABLED', f'#include "material/{key}.h"', '#endif'])
    cases.extend([
        f'#ifdef {symbol}_ENABLED',
        f'        case BUILT_IN_{symbol}: return {{id, {symbol}_{symbol}_DATA, {symbol}_{symbol}_SIZE}};',
        '#endif',
    ])

dart[-1] = dart[-1].removesuffix(',') + ';'
dart.extend(['', '  const BuiltInMaterial(this.nativeId, this.key);', '',
             '  /// Stable FFI value, independent of enum order.', '  final int nativeId;', '',
             '  /// Key under hooks.user_defines.thermion_dart.materials.', '  final String key;', '}'])
ids.append('} TBuiltInMaterial;')
lookup = [generated, '#pragma once', '#include "c_api/APIBoundaryTypes.h"', '#include "c_api/TBuiltInMaterial.h"',
          *includes, '', 'namespace thermion {', 'struct BuiltInMaterialPackage {',
          '    TBuiltInMaterial id;', '    const uint8_t* data;', '    size_t size;', '};', '',
          'inline BuiltInMaterialPackage builtInMaterialPackage(TBuiltInMaterial id) {', '    switch (id) {',
          *cases, '        default: return {id, nullptr, 0};', '    }', '}', '',
          'TMaterial* buildBuiltInMaterial(TEngine* engine, BuiltInMaterialPackage package);',
          '} // namespace thermion']

for destination, lines in [
    ('lib/src/filament/src/interface/built_in_material.dart', dart),
    ('native/include/c_api/TBuiltInMaterial.h', ids),
    ('native/include/material/BuiltInMaterialPackage.hpp', lookup),
]:
    (root / 'thermion_dart' / destination).write_text('\n'.join(lines) + '\n')
