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

void _markAllSynced(RenderAttachmentState state, Map<Pointer<TSwapChain>, List<View>> dirty) {
  for (final entry in dirty.entries) {
    state.markSynced(entry.key, entry.value);
  }
}

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

    test('ViewAttachment has value semantics', () {
      final view = _TestView(1);
      final otherView = _TestView(2);

      final attachment = ViewAttachment(view: view, order: 1, renderable: true);
      expect(attachment, ViewAttachment(view: view, order: 1, renderable: true));
      expect(attachment.hashCode, ViewAttachment(view: view, order: 1, renderable: true).hashCode);
      expect(attachment, isNot(ViewAttachment(view: otherView, order: 1, renderable: true)));
      expect(attachment, isNot(ViewAttachment(view: view, order: 2, renderable: true)));
      expect(attachment, isNot(ViewAttachment(view: view, order: 1, renderable: false)));
      expect(attachment.toString(), 'ViewAttachment(view: $view, order: 1, renderable: true)');
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

    test('setAttachments preserves list order on equal renderOrder across >32 views', () {
      final state = RenderAttachmentState();
      final swapChain = _swapChain(1);
      final views = List.generate(40, (i) => _TestView(i + 1));

      state.setAttachments(swapChain, [for (final v in views) (view: v, order: 0)]);

      expect(state.getAttachedViews(swapChain).toList(), views);
    });
  });

  group('RenderAttachmentState dirty tracking and batch attachments', () {
    late RenderAttachmentState state;

    setUp(() {
      state = RenderAttachmentState();
    });

    test('attach(v, sc1) with 4 swapchains marks only sc1 dirty', () {
      final sc1 = _swapChain(1);
      final sc2 = _swapChain(2);
      final sc3 = _swapChain(3);
      final sc4 = _swapChain(4);
      final v1 = _TestView(1);
      final v2 = _TestView(2);
      final v3 = _TestView(3);
      final v4 = _TestView(4);
      final v5 = _TestView(5);

      state.attach(v1, sc1);
      state.attach(v2, sc2);
      state.attach(v3, sc3);
      state.attach(v4, sc4);
      final initial = state.dirtyRenderableSnapshot();
      expect(initial.keys, containsAll([sc1, sc2, sc3, sc4]));
      _markAllSynced(state, initial);

      state.attach(v5, sc1);
      final dirty = state.dirtyRenderableSnapshot();
      expect(dirty, {
        sc1: [v1, v5],
      });
    });

    test('transitions from non-empty to empty report [] once and do not repeat', () {
      final sc1 = _swapChain(1);
      final v1 = _TestView(1);
      final v2 = _TestView(2);

      state.attach(v1, sc1);
      var dirty = state.dirtyRenderableSnapshot();
      expect(dirty, {
        sc1: [v1],
      });
      _markAllSynced(state, dirty);

      state.detach(v1, swapChain: sc1);
      dirty = state.dirtyRenderableSnapshot();
      expect(dirty, {sc1: isEmpty});
      _markAllSynced(state, dirty);

      state.detach(v2, swapChain: sc1);
      expect(state.dirtyRenderableSnapshot(), isEmpty);

      // Re-attach and hide via setRenderable -> reports [] once, then detaching is a no-op.
      state.attach(v1, sc1);
      _markAllSynced(state, state.dirtyRenderableSnapshot());
      state.setRenderable(v1, false);
      dirty = state.dirtyRenderableSnapshot();
      expect(dirty, {sc1: isEmpty});
      _markAllSynced(state, dirty);

      state.setRenderable(v1, false);
      state.detach(v1, swapChain: sc1);
      expect(state.dirtyRenderableSnapshot(), isEmpty);
    });

    test('no-op setRenderable, setRenderables, and order-preserving reattach produce no dirty entries', () {
      final sc1 = _swapChain(1);
      final sc2 = _swapChain(2);
      final v1 = _TestView(1);
      final v2 = _TestView(2);
      final v3 = _TestView(3);

      state.attach(v1, sc1, renderOrder: 0);
      state.attach(v2, sc1, renderOrder: 1);
      state.attach(v3, sc2, renderOrder: 0);
      _markAllSynced(state, state.dirtyRenderableSnapshot());

      state.setRenderable(v1, true);
      state.setRenderables({v1: true, v2: true, v3: true});
      state.attach(v1, sc1, renderOrder: 0);
      state.attach(v2, sc1, renderOrder: 5);
      expect(state.dirtyRenderableSnapshot(), isEmpty);

      // Paused view attached to sc2 is not dirty until enabled.
      final paused = _TestView(4);
      state.setRenderable(paused, false);
      state.attach(paused, sc2);
      expect(state.dirtyRenderableSnapshot(), isEmpty);

      // Enabling paused only marks sc2 dirty (not sc1).
      state.setRenderable(paused, true);
      expect(state.dirtyRenderableSnapshot(), {
        sc2: [v3, paused],
      });
    });

    test('setRenderables marks only swapchains whose renderable list changed', () {
      final sc1 = _swapChain(1);
      final sc2 = _swapChain(2);
      final sc3 = _swapChain(3);
      final v1 = _TestView(1);
      final v2 = _TestView(2);
      final v3 = _TestView(3);

      state.attach(v1, sc1);
      state.attach(v1, sc2);
      state.attach(v2, sc2, renderOrder: 1);
      state.attach(v3, sc3);
      _markAllSynced(state, state.dirtyRenderableSnapshot());

      state.setRenderables({v1: false, v3: true});
      expect(state.dirtyRenderableSnapshot(), {
        sc1: isEmpty,
        sc2: [v2],
      });
    });

    test('detachAll and clear reset synced tracking so reattachment is dirty again', () {
      final sc1 = _swapChain(1);
      final v1 = _TestView(1);

      state.attach(v1, sc1);
      _markAllSynced(state, state.dirtyRenderableSnapshot());

      state.detachAll(sc1);
      expect(state.dirtyRenderableSnapshot(), isEmpty);

      state.attach(v1, sc1);
      final dirty = state.dirtyRenderableSnapshot();
      expect(dirty, {
        sc1: [v1],
      });
      _markAllSynced(state, dirty);

      state.clear();
      expect(state.getViewAttachments(sc1), isEmpty);

      state.attach(v1, sc1);
      expect(state.dirtyRenderableSnapshot(), {
        sc1: [v1],
      });
    });

    test('setAttachments replaces swapchain views in one dirty snapshot without disturbing sibling swapchains', () {
      final sc1 = _swapChain(1);
      final sc2 = _swapChain(2);
      final silhouette = _TestView(1);
      final mainView = _TestView(2);
      final overlay = _TestView(3);
      final otherView = _TestView(4);

      state.attach(mainView, sc1);
      state.attach(otherView, sc2);
      _markAllSynced(state, state.dirtyRenderableSnapshot());

      state.setAttachments(sc1, [(view: overlay, order: 2), (view: silhouette, order: 0), (view: mainView, order: 1)]);

      final dirty = state.dirtyRenderableSnapshot();
      expect(dirty, {
        sc1: [silhouette, mainView, overlay],
      });
      _markAllSynced(state, dirty);

      state.setAttachments(sc1, [(view: mainView, order: 0)]);
      expect(state.dirtyRenderableSnapshot(), {
        sc1: [mainView],
      });
      expect(state.getAttachedViews(sc2), [otherView]);
    });

    test('updateAttachments attaches and detaches without disturbing sibling views', () {
      final sc1 = _swapChain(1);
      final silhouette = _TestView(1);
      final mainView = _TestView(2);
      final overlay = _TestView(3);
      final hudView = _TestView(4);

      state.attach(mainView, sc1, renderOrder: 0);
      state.attach(hudView, sc1, renderOrder: 10);
      _markAllSynced(state, state.dirtyRenderableSnapshot());

      state.updateAttachments(
        sc1,
        attach: [(view: silhouette, order: 0), (view: mainView, order: 1), (view: overlay, order: 2)],
      );

      final dirty = state.dirtyRenderableSnapshot();
      expect(dirty, {
        sc1: [silhouette, mainView, overlay, hudView],
      });
      _markAllSynced(state, dirty);

      state.updateAttachments(sc1, detach: [silhouette, overlay]);
      expect(state.dirtyRenderableSnapshot(), {
        sc1: [mainView, hudView],
      });
    });
  });
}
