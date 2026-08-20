import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/widgets/src/thermion_widget.dart';

void main() {
  testWidgets('staged replacement is mounted below the last valid frame', (
    tester,
  ) async {
    const currentKey = ValueKey('current');
    const replacementKey = ValueKey('replacement');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: buildStagedTextureSurface(
            current: const ColoredBox(key: currentKey, color: Colors.green),
            replacement: const ColoredBox(
              key: replacementKey,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );

    final stack = tester.widget<Stack>(find.byType(Stack).last);
    expect(stack.children.map((child) => child.key), [
      replacementKey,
      currentKey,
    ]);
    expect(find.byKey(replacementKey), findsOneWidget);
    expect(find.byKey(currentKey), findsOneWidget);
  });

  testWidgets('unstaged surface paints only the current frame', (tester) async {
    const currentKey = ValueKey('current');

    await tester.pumpWidget(
      MaterialApp(
        home: buildStagedTextureSurface(
          current: const ColoredBox(key: currentKey, color: Colors.green),
        ),
      ),
    );

    expect(find.byKey(currentKey), findsOneWidget);
    expect(find.byType(Stack), findsNothing);
  });
}
