"""Generate a disposable Flutter integration harness for the shared Dart suite."""

import argparse
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['android', 'ios'], required=True)
    parser.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    app = args.destination.resolve()
    subprocess.run(['flutter', 'create', '--no-pub', '--platforms', args.platform,
                    '--project-name', 'runtime_materials_ci', str(app)], check=True)
    (app / 'pubspec.yaml').write_text(f'''name: runtime_materials_ci
publish_to: none
version: 0.0.1+1
environment:
  sdk: '>=3.10.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  thermion_dart:
    path: {root / 'thermion_dart'}
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  test: any
hooks:
  user_defines:
    thermion_dart:
      mode: release
      runtime_materials: true
flutter:
  uses-material-design: true
''')
    tests = app / 'integration_test'
    tests.mkdir()
    suite = (root / 'thermion_dart/test/runtime_material_test.dart').as_uri()
    (tests / 'runtime_materials_test.dart').write_text(f'''import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import '{suite}' as runtime;

Future<void> main() async {{
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await runtime.runRuntimeMaterialTests(
    expectedSupport: true,
    registerTest: (name, body) {{
      testWidgets(name, (tester) async {{
        await tester.runAsync(body);
      }});
    }},
  );
}}
''')


if __name__ == '__main__':
    main()
