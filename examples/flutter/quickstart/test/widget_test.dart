// Smoke test for the multi-viewer quickstart shell.
//
// Mounting a [ViewerWidget] kicks off real native Filament init
// (FFIFilamentApp.create) that can't run under flutter_test's fake-async,
// so this only verifies the empty shell renders with an Add-viewer control.
// Adding/viewing actual viewers is the job of a native/integration run.

import 'package:flutter_test/flutter_test.dart';

import 'package:quickstart/main.dart';

void main() {
  testWidgets('shell renders empty grid with Add viewer control',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('No viewers mounted'), findsOneWidget);
    expect(find.text('Add viewer (0)'), findsOneWidget);
    // Framerate segmented control is present.
    expect(find.text('60'), findsOneWidget);
    // No viewer tiles yet.
    expect(find.textContaining('Skybox'), findsNothing);
  });
}
