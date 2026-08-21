import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quickstart/main.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'adds, initializes, renders, and removes a viewer',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      expect(find.text('No viewers mounted'), findsOneWidget);

      // Exercise the real quickstart interaction instead of mounting a
      // ViewerWidget directly in the test.
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(find.byType(ViewerWidget), findsOneWidget);

      await _pumpUntil(tester, find.byKey(const ValueKey('viewer-ready-1')));

      // Keep the native render loop alive for several frames after the viewer
      // callback. Startup-only success is not enough: the EGL transport must
      // remain usable once Flutter begins consuming frames.
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Remove'));
      await _pumpUntil(tester, find.byType(ViewerWidget), present: false);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  bool present = true,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final stopwatch = Stopwatch()..start();
  while ((finder.evaluate().isNotEmpty != present) &&
      stopwatch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (finder.evaluate().isNotEmpty != present) {
    throw TimeoutException(
      'Timed out waiting for ${finder.describeMatch(Plurality.one)} to be '
      '${present ? 'present' : 'absent'}',
      timeout,
    );
  }
}
