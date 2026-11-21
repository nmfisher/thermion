import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_dart/thermion_dart.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_manager.dart';
import 'package:thermion_flutter/src/options.dart';
import 'package:thermion_flutter/src/platform/src/native_rendering_lifecycle_controller.dart';
import 'package:thermion_flutter/src/platform/src/native_texture_surface_manager.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor_registry_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('shouldDeferNativeTextureBinding', () {
    test('prefers an immediately available Linux hardware handle', () {
      expect(
        shouldDeferNativeTextureBinding(
          managesFilamentSurface: false,
          hardwareId: 0x1234,
          supportsDeferredBinding: true,
        ),
        isFalse,
      );
    });

    test('defers only when no hardware handle is available', () {
      expect(
        shouldDeferNativeTextureBinding(
          managesFilamentSurface: false,
          hardwareId: 0,
          supportsDeferredBinding: true,
        ),
        isTrue,
      );
    });

    test('does not defer descriptor-managed surfaces', () {
      expect(
        shouldDeferNativeTextureBinding(
          managesFilamentSurface: true,
          hardwareId: 0,
          supportsDeferredBinding: true,
        ),
        isFalse,
      );
    });
  });

  group('destroyRenderTargetResourcesInOrder', () {
    test('destroys the target before its attachment textures', () async {
      final events = <String>[];

      await destroyRenderTargetResourcesInOrder(
        destroyRenderTarget: () async => events.add('render-target'),
        destroyColorTexture: () async => events.add('color'),
        destroyDepthTexture: () async => events.add('depth'),
      );

      expect(events, ['render-target', 'color', 'depth']);
    });

    test(
      'keeps attachment textures alive when target destruction fails',
      () async {
        final events = <String>[];

        await expectLater(
          destroyRenderTargetResourcesInOrder(
            destroyRenderTarget: () async {
              events.add('render-target');
              throw StateError('expected');
            },
            destroyColorTexture: () async => events.add('color'),
            destroyDepthTexture: () async => events.add('depth'),
          ),
          throwsStateError,
        );

        expect(events, ['render-target']);
      },
    );
  });

  group('NativeTextureSurfaceManager renderOrder and target lifecycle', () {
    test(
      'createAndBind attaches view at order 0 and sets presentation target',
      () async {
        final harness = _createTestHarness();
        final view = _FakeView(1);

        final descriptor = await harness.manager.createAndBind(view, 400, 300);

        expect(
          harness.app.renderManager.getViewAttachments(harness.swapChain),
          [ViewAttachment(view: view, order: 0, renderable: true)],
        );
        expect(harness.app.renderManager.attachCalls, [
          (view, harness.swapChain, 0),
        ]);
        expect(view.viewportCalls, [(400, 300)]);
        expect(view.presentationTargets, [
          same(harness.app.createdRenderTargets.single),
        ]);
        expect(harness.app.createdRenderTargets.single.width, 400);
        expect(harness.app.createdRenderTargets.single.height, 300);
        if (Platform.isWindows) {
          expect(
            harness.app.createdRenderTargets.single.color.importedTextureHandle,
            -1,
          );
          expect(harness.app.externalImageCalls, hasLength(1));
          expect(
            harness.app.externalImageCalls.single.$2,
            descriptor.hardwareId,
          );
        } else {
          expect(
            harness.app.createdRenderTargets.single.color.importedTextureHandle,
            descriptor.hardwareId,
          );
          expect(harness.app.externalImageCalls, isEmpty);
        }
      },
    );

    test(
      'resizing via _createFilamentResources preserves multi-pass renderOrder',
      () async {
        final harness = _createTestHarness();
        final prePass = _FakeView(1);
        final view = _FakeView(2);
        final postPass = _FakeView(3);

        final initial = await harness.manager.createAndBind(view, 400, 300);
        await _attachMultiPassPipeline(
          harness.app.renderManager,
          harness.swapChain,
          prePass: prePass,
          view: view,
          postPass: postPass,
        );
        final attachCountBeforeResize =
            harness.app.renderManager.attachCalls.length;

        await harness.manager.resize(initial, view, 800, 600);

        expect(
          harness.app.renderManager.getViewAttachments(harness.swapChain),
          [
            ViewAttachment(view: prePass, order: 0, renderable: true),
            ViewAttachment(view: view, order: 1, renderable: true),
            ViewAttachment(view: postPass, order: 2, renderable: true),
          ],
        );
        expect(
          harness.app.renderManager.attachCalls.length,
          attachCountBeforeResize,
        );
        expect(harness.app.createdRenderTargets, hasLength(2));
        final oldTarget = harness.app.createdRenderTargets.first;
        final newTarget = harness.app.createdRenderTargets.last;
        expect(newTarget.width, 800);
        expect(newTarget.height, 600);
        expect(view.presentationTargets.last, same(newTarget));
        expect(oldTarget.destroyed, isTrue);
        expect(oldTarget.color.destroyed, isTrue);
        expect(oldTarget.depth.destroyed, isTrue);
      },
      skip: Platform.isWindows ? 'Non-Windows resize path' : false,
    );

    test(
      'resizing via _resizeWindows preserves multi-pass renderOrder',
      () async {
        const resizedHardwareId = 0x9999;
        _mockWindowsChannel(resizedHardwareId: resizedHardwareId);
        final harness = _createTestHarness();
        final prePass = _FakeView(1);
        final view = _FakeView(2);
        final postPass = _FakeView(3);

        final initial = await harness.manager.createAndBind(view, 400, 300);
        final initialTarget = harness.app.createdRenderTargets.single;
        expect(initialTarget.color.importedTextureHandle, -1);
        expect(harness.app.externalImageCalls, hasLength(1));
        expect(
          harness.app.externalImageCalls.single.$1,
          same(initialTarget.color),
        );
        expect(harness.app.externalImageCalls.single.$2, initial.hardwareId);

        await _attachMultiPassPipeline(
          harness.app.renderManager,
          harness.swapChain,
          prePass: prePass,
          view: view,
          postPass: postPass,
        );
        final attachCountBeforeResize =
            harness.app.renderManager.attachCalls.length;

        final resized = await harness.manager.resize(initial, view, 800, 600);

        expect(resized, same(initial));
        expect(resized.hardwareId, resizedHardwareId);
        expect(resized.width, 800);
        expect(resized.height, 600);
        expect(
          harness.app.renderManager.getViewAttachments(harness.swapChain),
          [
            ViewAttachment(view: prePass, order: 0, renderable: true),
            ViewAttachment(view: view, order: 1, renderable: true),
            ViewAttachment(view: postPass, order: 2, renderable: true),
          ],
        );
        expect(
          harness.app.renderManager.attachCalls.length,
          attachCountBeforeResize,
        );
        expect(view.viewportCalls.last, (800, 600));
        expect(harness.app.createdRenderTargets, hasLength(2));
        final newTarget = harness.app.createdRenderTargets.last;
        expect(newTarget.width, 800);
        expect(newTarget.height, 600);
        expect(newTarget.color.importedTextureHandle, -1);
        expect(harness.app.externalImageCalls, hasLength(2));
        expect(harness.app.externalImageCalls.last.$1, same(newTarget.color));
        expect(harness.app.externalImageCalls.last.$2, resizedHardwareId);
        expect(view.presentationTargets.last, same(newTarget));
        expect(initialTarget.destroyed, isFalse);
      },
      skip: !Platform.isWindows ? 'Windows-only resize path' : false,
    );

    test(
      'Vulkan standard path binds external image via setExternalImage',
      () async {
        final harness = _createTestHarness(
          options: const NativeOptions(backend: Backend.VULKAN),
        );
        final view = _FakeView(1);

        final descriptor = await harness.manager.createAndBind(view, 400, 300);

        final target = harness.app.createdRenderTargets.single;
        expect(target.color.importedTextureHandle, -1);
        expect(harness.app.externalImageCalls, hasLength(1));
        expect(harness.app.externalImageCalls.single.$1, same(target.color));
        expect(harness.app.externalImageCalls.single.$2, descriptor.hardwareId);
      },
    );

    test(
      'cancelStagedResize preserves multi-pass renderOrder',
      () async {
        final harness = _createTestHarness();
      final prePass = _FakeView(1);
      final view = _FakeView(2);
      final postPass = _FakeView(3);

      final initial = await harness.manager.createAndBind(view, 400, 300);
      await _attachMultiPassPipeline(
        harness.app.renderManager,
        harness.swapChain,
        prePass: prePass,
        view: view,
        postPass: postPass,
      );
      final replacement = await harness.manager.resize(initial, view, 800, 600);
      final attachCountBeforeCancel =
          harness.app.renderManager.attachCalls.length;

      await harness.manager.cancelStagedResize(replacement, initial, view);

      expect(harness.app.renderManager.getViewAttachments(harness.swapChain), [
        ViewAttachment(view: prePass, order: 0, renderable: true),
        ViewAttachment(view: view, order: 1, renderable: true),
        ViewAttachment(view: postPass, order: 2, renderable: true),
      ]);
      expect(
        harness.app.renderManager.attachCalls.length,
        attachCountBeforeCancel,
      );
      expect(harness.app.createdRenderTargets.last.width, 400);
      expect(harness.app.createdRenderTargets.last.height, 300);
      expect(
        view.presentationTargets.last,
        same(harness.app.createdRenderTargets.last),
      );
      expect(replacement.destroyed, isTrue);
    }, skip: Platform.isWindows ? 'Non-Windows staged resize path' : false);

    test(
      '_createFilamentResources throws rollback failure when cleanup fails',
      () async {
        final harness = _createTestHarness();
        final view = _FakeView(1)
          ..presentationError = StateError('bind failed');
        harness.app.nextRenderTargetThrowOnDestroy = true;

        await expectLater(
          harness.manager.createAndBind(view, 400, 300),
          throwsA(
            predicate(
              (error) => error.toString().contains(
                'Could not safely roll back partially-created Filament resources',
              ),
            ),
          ),
        );

        final descriptor = harness.allocated.single;
        expect(descriptor.destroyed, isFalse);
        expect(descriptor.boundView, isNull);
        expect(harness.manager.registry.contains(descriptor), isTrue);
      },
    );

    test(
      '_resizeWindows cancels native resize and rethrows original error',
      () async {
        final cancelledTextureIds = <int>[];
        _mockWindowsChannel(
          resizedHardwareId: 0x9999,
          onCancelResize: cancelledTextureIds.add,
        );
        final harness = _createTestHarness();
        final view = _FakeView(1);

        final initial = await harness.manager.createAndBind(view, 400, 300);
        final initialHardwareId = initial.hardwareId;

        view.presentationError = StateError('windows bind failed');
        harness.app.nextRenderTargetThrowOnDestroy = true;

        await expectLater(
          harness.manager.resize(initial, view, 800, 600),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'windows bind failed',
            ),
          ),
        );

        expect(cancelledTextureIds, [initial.flutterTextureId]);
        expect(initial.hardwareId, initialHardwareId);
        expect(initial.width, 400);
        expect(initial.height, 300);
      },
      skip: !Platform.isWindows ? 'Windows-only resize path' : false,
    );

    test(
      '_resizeWindows destroys newly created resources when resize fails',
      () async {
        final cancelledTextureIds = <int>[];
        _mockWindowsChannel(
          resizedHardwareId: 0x9999,
          onCancelResize: cancelledTextureIds.add,
        );
        final harness = _createTestHarness();
        final view = _FakeView(1);

        final initial = await harness.manager.createAndBind(view, 400, 300);
        final initialTarget = harness.app.createdRenderTargets.single;

        view.presentationError = StateError('windows bind failed');

        await expectLater(
          harness.manager.resize(initial, view, 800, 600),
          throwsStateError,
        );

        expect(cancelledTextureIds, [initial.flutterTextureId]);
        expect(harness.app.createdRenderTargets, hasLength(2));
        final failedTarget = harness.app.createdRenderTargets.last;
        expect(initialTarget.destroyed, isFalse);
        expect(failedTarget.destroyed, isTrue);
        expect(failedTarget.color.destroyed, isTrue);
        expect(failedTarget.depth.destroyed, isTrue);
      },
      skip: !Platform.isWindows ? 'Windows-only resize path' : false,
    );
  });
}

Future<void> _attachMultiPassPipeline(
  RenderManager renderManager,
  SwapChain swapChain, {
  required View prePass,
  required View view,
  required View postPass,
}) async {
  await renderManager.detach(view, swapChain: swapChain);
  await renderManager.attach(prePass, swapChain, renderOrder: 0);
  await renderManager.attach(view, swapChain, renderOrder: 1);
  await renderManager.attach(postPass, swapChain, renderOrder: 2);
}

void _mockWindowsChannel({
  required int resizedHardwareId,
  void Function(int textureId)? onCancelResize,
}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    NativePlatformTextureDescriptorRegistry.channel,
    (call) async {
      switch (call.method) {
        case 'resizeTexture':
          return <Object?>[resizedHardwareId];
        case 'cancelResizeTexture':
          onCancelResize?.call(call.arguments as int);
          return null;
        default:
          throw MissingPluginException('Unexpected method ${call.method}');
      }
    },
  );
  addTearDown(() {
    messenger.setMockMethodCallHandler(
      NativePlatformTextureDescriptorRegistry.channel,
      null,
    );
  });
}

({
  NativeTextureSurfaceManager manager,
  _FakeFilamentApp app,
  _FakeSwapChain swapChain,
  List<_FakeDescriptor> allocated,
})
_createTestHarness({
  NativeOptions options = const NativeOptions(),
}) {
  final swapChain = _FakeSwapChain(1);
  final app = _FakeFilamentApp(swapChains: [swapChain]);
  final previousApp = FilamentApp.instance;
  FilamentApp.instance = app;
  addTearDown(() => FilamentApp.instance = previousApp);

  var nextTextureId = 1;
  var nextHardwareId = 0x1000;
  final allocated = <_FakeDescriptor>[];
  late final NativeTextureSurfaceManager manager;
  final lifecycle = NativeRenderingLifecycleController(
    hasUnavailableSurfaces: () => manager.hasUnavailableSurfaces,
    onFrameRendered: () async {},
  );
  manager = NativeTextureSurfaceManager(
    lifecycle: lifecycle,
    options: () => options,
    allocator: (width, height) {
      final descriptor = _FakeDescriptor(
        flutterTextureId: nextTextureId++,
        hardwareId: nextHardwareId++,
        width: width,
        height: height,
      );
      allocated.add(descriptor);
      return descriptor;
    },
  );
  return (
    manager: manager,
    app: app,
    swapChain: swapChain,
    allocated: allocated,
  );
}

class _FakeDescriptor extends PlatformTextureDescriptor {
  _FakeDescriptor({
    required super.flutterTextureId,
    required super.hardwareId,
    required super.width,
    required super.height,
  });

  bool _destroyed = false;

  @override
  bool get destroyed => _destroyed;

  @override
  Future<void> markTextureFrameAvailable() async {}

  @override
  Future<void> destroy() async {
    _destroyed = true;
  }
}

class _FakeSwapChain extends SwapChain<Pointer<TSwapChain>> {
  _FakeSwapChain(int address)
    : _handle = Pointer<TSwapChain>.fromAddress(address);

  final Pointer<TSwapChain> _handle;

  @override
  Pointer<TSwapChain> getNativeHandle() => _handle;
}

class _FakeView extends View<Pointer<TView>> {
  _FakeView(int address) : _handle = Pointer<TView>.fromAddress(address);

  final Pointer<TView> _handle;
  final List<(int, int)> viewportCalls = [];
  final List<RenderTarget?> presentationTargets = [];
  Object? presentationError;

  @override
  Pointer<TView> getNativeHandle() => _handle;

  @override
  Future setViewport(int width, int height) async {
    viewportCalls.add((width, height));
  }

  @override
  Future setPresentationRenderTarget(
    covariant RenderTarget? renderTarget,
  ) async {
    if (presentationError != null) {
      throw presentationError!;
    }
    presentationTargets.add(renderTarget);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTexture extends Texture<Pointer<TTexture>> {
  _FakeTexture(
    int address, {
    required this.width,
    required this.height,
    required this.importedTextureHandle,
  }) : _handle = Pointer<TTexture>.fromAddress(address);

  final Pointer<TTexture> _handle;
  final int width;
  final int height;
  final int? importedTextureHandle;
  bool destroyed = false;

  @override
  Pointer<TTexture> getNativeHandle() => _handle;

  @override
  Future destroy() async {
    destroyed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRenderTarget extends RenderTarget<Pointer<TRenderTarget>> {
  _FakeRenderTarget(
    int address, {
    required this.width,
    required this.height,
    required this.color,
    required this.depth,
    this.throwOnDestroy = false,
  }) : _handle = Pointer<TRenderTarget>.fromAddress(address);

  final Pointer<TRenderTarget> _handle;
  final int width;
  final int height;
  final _FakeTexture color;
  final _FakeTexture depth;
  final bool throwOnDestroy;
  bool destroyed = false;

  @override
  Pointer<TRenderTarget> getNativeHandle() => _handle;

  @override
  Future<Texture> getColorTexture() async => color;

  @override
  Future<Texture> getDepthTexture() async => depth;

  @override
  Future destroy() async {
    if (throwOnDestroy) {
      throw StateError('render target destroy failed');
    }
    destroyed = true;
  }
}

class _FakeRenderManager extends RenderManager<Pointer<TRenderManager>> {
  _FakeRenderManager(this._handle);

  final Pointer<TRenderManager> _handle;
  final RenderAttachmentState _state = RenderAttachmentState();
  final List<(View, SwapChain, int)> attachCalls = [];

  @override
  Pointer<TRenderManager> getNativeHandle() => _handle;

  @override
  Future attach(View view, SwapChain swapChain, {int renderOrder = 0}) async {
    attachCalls.add((view, swapChain, renderOrder));
    _state.attach(view, swapChain.getNativeHandle(), renderOrder: renderOrder);
  }

  @override
  Future setAttachments(
    SwapChain swapChain,
    List<({View view, int order})> attachments,
  ) async {
    _state.setAttachments(swapChain.getNativeHandle(), attachments);
  }

  @override
  Future updateAttachments(
    SwapChain swapChain, {
    Iterable<({View view, int order})> attach = const [],
    Iterable<View> detach = const [],
  }) async {
    _state.updateAttachments(
      swapChain.getNativeHandle(),
      attach: attach,
      detach: detach,
    );
  }

  @override
  Future detach(View view, {SwapChain? swapChain}) async {
    _state.detach(view, swapChain: swapChain?.getNativeHandle());
  }

  @override
  Future detachAll(SwapChain swapChain) async {
    _state.detachAll(swapChain.getNativeHandle());
  }

  @override
  List<ViewAttachment> getViewAttachments(SwapChain swapChain) {
    return _state.getViewAttachments(swapChain.getNativeHandle());
  }

  @override
  Iterable<View> getAttachedViews(SwapChain swapChain) {
    return getViewAttachments(swapChain).map((attachment) => attachment.view);
  }

  @override
  Iterable<SwapChain> getAttachedSwapChains(View view) => const [];

  @override
  Future setRenderable(View view, bool renderable) async {
    _state.setRenderable(view, renderable);
  }

  @override
  Future setRenderables(Map<View, bool> renderability) async {
    _state.setRenderables(renderability);
  }

  @override
  Future render({int? frameTimeInNanos}) async {}

  @override
  Future<void> destroy() async {
    _state.clear();
  }
}

class _FakeFilamentApp extends FilamentApp<Pointer<Void>> {
  _FakeFilamentApp({required this.swapChains});

  final List<SwapChain> swapChains;
  @override
  final _FakeRenderManager renderManager = _FakeRenderManager(
    Pointer<TRenderManager>.fromAddress(1),
  );
  final List<_FakeTexture> createdTextures = [];
  final List<_FakeRenderTarget> createdRenderTargets = [];
  final List<(_FakeTexture, int)> externalImageCalls = [];
  bool nextRenderTargetThrowOnDestroy = false;

  int _nextHandle = 1;

  @override
  Future flush() async {}

  @override
  Future<Iterable<SwapChain>> getSwapChains() async => swapChains;

  @override
  Future<Texture> createTexture(
    int width,
    int height, {
    int depth = 1,
    int levels = 1,
    Set<TextureUsage> flags = const {TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
    TextureSamplerType textureSamplerType = TextureSamplerType.SAMPLER_2D,
    TextureFormat textureFormat = TextureFormat.RGBA32F,
    int? importedTextureHandle,
  }) async {
    final texture = _FakeTexture(
      _nextHandle++,
      width: width,
      height: height,
      importedTextureHandle: importedTextureHandle,
    );
    createdTextures.add(texture);
    return texture;
  }

  @override
  Future<void> setExternalImage(Texture texture, int externalImagePtr) async {
    externalImageCalls.add((texture as _FakeTexture, externalImagePtr));
  }

  @override
  Future<RenderTarget> createRenderTarget(
    int width,
    int height, {
    covariant Texture? color,
    covariant Texture? depth,
    bool createDepth = true,
  }) async {
    final throwOnDestroy = nextRenderTargetThrowOnDestroy;
    nextRenderTargetThrowOnDestroy = false;
    final target = _FakeRenderTarget(
      _nextHandle++,
      width: width,
      height: height,
      color: color! as _FakeTexture,
      depth: depth! as _FakeTexture,
      throwOnDestroy: throwOnDestroy,
    );
    createdRenderTargets.add(target);
    return target;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
