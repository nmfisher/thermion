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
      expect(state.activeSnapshot(), isEmpty);

      state.attach(view, swapChain);
      expect(state.activeSnapshot()[swapChain], [(0, view)]);
    });

    test('remembers a paused view before its first attachment', () {
      final state = RenderAttachmentState();
      final view = _TestView(1);
      final swapChain = _swapChain(1);

      state.setRenderable(view, false);
      state.attach(view, swapChain);

      expect(state.getAttachedSwapChains(view), [swapChain]);
      expect(state.activeSnapshot()[swapChain], isEmpty);
    });

    test('resumes the view on its existing swapchain', () {
      final state = RenderAttachmentState();
      final view = _TestView(1);
      final swapChain = _swapChain(1);

      state.attach(view, swapChain);
      state.setRenderable(view, false);
      state.setRenderable(view, true);

      expect(state.activeSnapshot()[swapChain], [(0, view)]);
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
      expect(state.activeSnapshot()[replacementSwapChain], isEmpty);
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

      expect(state.activeSnapshot()[newSwapChain], [(0, view)]);
    });

    test('render plan preserves order and inactive attachments', () {
      final state = RenderAttachmentState();
      final mainView = _TestView(1);
      final overlayView = _TestView(2);
      final swapChain = _swapChain(1);

      state.attach(overlayView, swapChain, renderOrder: 2);
      state.attach(mainView, swapChain, renderOrder: 1);
      state.setRenderable(overlayView, false);

      final plan = state.getRenderPlan(swapChain);
      expect(plan.passes.map((pass) => pass.view), [mainView, overlayView]);
      expect(plan.passes.map((pass) => pass.order), [1, 2]);
      expect(plan.passes.map((pass) => pass.active), [true, false]);
      expect(plan.activeViews, [mainView]);
    });

    test('updates grouped pass state before producing a snapshot', () {
      final state = RenderAttachmentState();
      final silhouetteView = _TestView(1);
      final overlayView = _TestView(2);
      final swapChain = _swapChain(1);

      state.attach(silhouetteView, swapChain, renderOrder: 0);
      state.attach(overlayView, swapChain, renderOrder: 2);
      state.setRenderables({silhouetteView: false, overlayView: false});

      expect(state.getRenderPlan(swapChain).activeViews, isEmpty);
    });
  });
}
