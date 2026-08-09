// Smoke test for the multi-viewer quickstart shell.
//
// Mounting a [ViewerWidget] kicks off real native Filament init
// (FFIFilamentApp.create) that can't run under flutter_test's fake-async,
// so this only verifies the empty shell renders with the batch stepper and
// add/remove control. Adding/viewing actual viewers is the job of a
// native/integration run.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quickstart/main.dart';

void main() {
  testWidgets('shell renders empty grid with batch stepper and add control',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('No viewers mounted'), findsOneWidget);
    // Button reads "Add − 1 + viewers"; batch defaults to 1.
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('viewers'), findsOneWidget);
    // Framerate segmented control is present.
    expect(find.text('60'), findsOneWidget);
    // No viewer tiles yet.
    expect(find.textContaining('Skybox'), findsNothing);

    // Stepper increments the batch; the count follows.
    await tester.tap(find.byKey(const ValueKey('batch-increase')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    // Decrement returns to the floor and stops there.
    await tester.tap(find.byKey(const ValueKey('batch-decrease')));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('batch-decrease')));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });
}
