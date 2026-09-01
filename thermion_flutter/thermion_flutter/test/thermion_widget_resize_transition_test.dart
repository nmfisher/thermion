import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/widgets/src/thermion_widget.dart';
import 'package:thermion_flutter/src/widgets/src/thermion_widget_internal/texture_widget_builder.dart';

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

  testWidgets('flagged platform texture is vertically flipped', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: buildTextureWidget(_TextureDescriptor(flipVertically: true)),
      ),
    );

    final transform = tester.widget<Transform>(find.byType(Transform));
    expect(transform.transform.entry(0, 0), 1);
    expect(transform.transform.entry(1, 1), -1);
    expect(find.byType(Texture), findsOneWidget);
  });

  testWidgets('unflagged platform texture is not transformed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: buildTextureWidget(_TextureDescriptor(flipVertically: false)),
      ),
    );

    expect(find.byType(Transform), findsNothing);
    expect(find.byType(Texture), findsOneWidget);
  });
}

class _TextureDescriptor extends PlatformTextureDescriptor {
  _TextureDescriptor({required bool flipVertically})
    : super(
        flutterTextureId: 1,
        hardwareId: 2,
        width: 3,
        height: 4,
        flipVertically: flipVertically,
      );

  @override
  Future<void> destroy() async {}

  @override
  Future<void> markTextureFrameAvailable() async {}
}
