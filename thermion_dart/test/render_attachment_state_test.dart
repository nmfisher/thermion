import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_manager.dart';

class _TestView implements View<Pointer<TView>> {
  _TestView(int address) : _handle = Pointer<TView>.fromAddress(address);

  final Pointer<TView> _handle;

  @override
  Pointer<TView> getNativeHandle() => _handle;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Pointer<TSwapChain> _swapChain(int address) => Pointer<TSwapChain>.fromAddress(address);

void main() {
  group('RenderAttachmentState', () {
    test('accepts an enabled view before its first attachment', () {
      final state = RenderAttachmentState();
      final view = _TestView(1);
      final swapChain = _swapChain(1);

      state.setRenderable(view, true);

      expect(state.getAttachedSwapChains(view), isEmpty);
      expect(state.renderableSnapshot(), isEmpty);

      state.attach(view, swapChain);
      expect(state.renderableSnapshot()[swapChain], [(0, view)]);
    });

    test('remembers a paused view before its first attachment', () {
      final state = RenderAttachmentState();
      final view = _TestView(1);
      final swapChain = _swapChain(1);

      state.setRenderable(view, false);
      state.attach(view, swapChain);

      expect(state.getAttachedSwapChains(view), [swapChain]);
      expect(state.renderableSnapshot()[swapChain], isEmpty);
    });

    test('resumes the view on its existing swapchain', () {
      final state = RenderAttachmentState();
      final view = _TestView(1);
      final swapChain = _swapChain(1);

      state.attach(view, swapChain);
      state.setRenderable(view, false);
      state.setRenderable(view, true);

      expect(state.renderableSnapshot()[swapChain], [(0, view)]);
    });

    test('preserves pause state while replacing a swapchain', () {
      final state = RenderAttachmentState();
      final view = _TestView(1);
      final oldSwapChain = _swapChain(1);
      final replacementSwapChain = _swapChain(2);

      state.attach(view, oldSwapChain);
      state.setRenderable(view, false);
      state.attach(view, replacementSwapChain);
      state.detachAll(oldSwapChain);

      expect(state.getAttachedSwapChains(view), [replacementSwapChain]);
      expect(state.renderableSnapshot()[replacementSwapChain], isEmpty);
    });

    test('a fully detached view defaults to rendering when reused', () {
      final state = RenderAttachmentState();
      final view = _TestView(1);
      final oldSwapChain = _swapChain(1);
      final newSwapChain = _swapChain(2);

      state.setRenderable(view, false);
      state.attach(view, oldSwapChain);
      state.detach(view);
      state.attach(view, newSwapChain);

      expect(state.renderableSnapshot()[newSwapChain], [(0, view)]);
    });

    test('view attachments preserve order and non-renderable entries', () {
      final state = RenderAttachmentState();
      final mainView = _TestView(1);
      final overlayView = _TestView(2);
      final swapChain = _swapChain(1);

      state.attach(overlayView, swapChain, renderOrder: 2);
      state.attach(mainView, swapChain, renderOrder: 1);
      state.setRenderable(overlayView, false);

      final attachments = state.getViewAttachments(swapChain);
      expect(attachments.map((attachment) => attachment.view), [mainView, overlayView]);
      expect(attachments.map((attachment) => attachment.order), [1, 2]);
      expect(attachments.map((attachment) => attachment.renderable), [true, false]);
      expect(attachments.where((attachment) => attachment.renderable).map((attachment) => attachment.view), [mainView]);
      expect(() => attachments.add(attachments.first), throwsUnsupportedError);
    });

    test('updates grouped view state before returning attachments', () {
      final state = RenderAttachmentState();
      final silhouetteView = _TestView(1);
      final overlayView = _TestView(2);
      final swapChain = _swapChain(1);

      state.attach(silhouetteView, swapChain, renderOrder: 0);
      state.attach(overlayView, swapChain, renderOrder: 2);
      state.setRenderables({silhouetteView: false, overlayView: false});

      expect(state.getViewAttachments(swapChain).where((attachment) => attachment.renderable), isEmpty);
    });
  });
}
