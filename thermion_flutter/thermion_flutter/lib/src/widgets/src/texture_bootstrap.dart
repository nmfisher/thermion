import 'dart:async';

import 'package:flutter/widgets.dart';
// ignore: implementation_imports
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
// ignore: implementation_imports
import 'package:thermion_flutter/src/thermion_flutter_plugin.dart';

typedef ContextBootstrapAllocator =
    Future<PlatformTextureDescriptor?> Function();
typedef ContextBootstrapDestroyer = Future<void> Function(
  PlatformTextureDescriptor descriptor,
);

/// Sequences [initialize] after the texture handshake some platforms require
/// before the native viewer can be created.
///
/// Linux OpenGL cannot create Filament's shared GL context until Flutter has
/// composited an external texture at least once. Until then there is nothing
/// on the Flutter side for Filament's context to share with. So this widget
/// renders a 1x1 [Texture] backed by a bootstrap descriptor, waits for the
/// engine to populate it ([PlatformTextureDescriptor.awaitTextureReady]),
/// runs [initialize], and only then removes the layer and destroys the
/// descriptor.
///
/// When the allocator returns null (every platform without the prerequisite,
/// and any viewer created after the first one), the handshake is skipped and
/// [initialize] runs immediately.
///
/// The allocator pair comes from [ThermionFlutterPlugin] by default; tests
/// may inject their own. If a create hook is injected, destruction stays
/// within the injected pair (falling back to the descriptor itself) and the
/// plugin is never consulted.
class ThermionTextureBootstrap extends StatefulWidget {
  const ThermionTextureBootstrap({
    super.key,
    required this.initialize,
    required this.child,
    this.createContextBootstrap,
    this.destroyContextBootstrap,
  });

  final Future<void> Function() initialize;
  final Widget child;
  final ContextBootstrapAllocator? createContextBootstrap;
  final ContextBootstrapDestroyer? destroyContextBootstrap;

  @override
  State<ThermionTextureBootstrap> createState() =>
      _ThermionTextureBootstrapState();
}

class _ThermionTextureBootstrapState extends State<ThermionTextureBootstrap> {
  PlatformTextureDescriptor? _descriptor;
  Future<void>? _destroyFuture;
  bool _disposing = false;

  bool get _injected => widget.createContextBootstrap != null;

  @override
  void initState() {
    super.initState();
    unawaited(
      _bootstrap().catchError((Object error, StackTrace stack) {
        if (_disposing) return;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'thermion_flutter',
            context: ErrorDescription(
              'while initializing a Thermion Flutter widget',
            ),
          ),
        );
      }),
    );
  }

  Future<void> _bootstrap() async {
    final descriptor = await _allocate();
    _descriptor = descriptor;

    try {
      if (_disposing) return;

      if (descriptor != null) {
        if (mounted) {
          setState(() {});
        }
        try {
          descriptor.hardwareId = await descriptor.awaitTextureReady();
        } catch (_) {
          // Destroying the descriptor is how dispose() cancels a pending
          // native populate handshake.
          if (_disposing) return;
          rethrow;
        }
      }

      if (_disposing) return;
      await widget.initialize();
    } finally {
      if (identical(_descriptor, descriptor)) {
        _descriptor = null;
      }
      if (descriptor != null && mounted && !_disposing) {
        // Remove the Texture layer before unregistering its native texture.
        setState(() {});
        await WidgetsBinding.instance.endOfFrame;
      }
      if (descriptor != null) {
        await _destroy(descriptor);
      }
    }
  }

  Future<PlatformTextureDescriptor?> _allocate() {
    final create = widget.createContextBootstrap;
    if (create != null) {
      return create();
    }
    return ThermionFlutterPlugin.instance.createContextBootstrap();
  }

  Future<void> _destroy(PlatformTextureDescriptor descriptor) {
    return _destroyFuture ??= () {
      final destroy = widget.destroyContextBootstrap;
      if (destroy != null) {
        return destroy(descriptor);
      }
      if (_injected) {
        return descriptor.destroy();
      }
      return ThermionFlutterPlugin.instance.destroyContextBootstrap(descriptor);
    }();
  }

  @override
  void dispose() {
    _disposing = true;
    final descriptor = _descriptor;
    if (descriptor != null) {
      unawaited(
        _destroy(descriptor).catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'thermion_flutter',
              context: ErrorDescription(
                'while cancelling Flutter context initialization',
              ),
            ),
          );
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final descriptor = _descriptor;
    if (descriptor == null) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox.square(
            dimension: 1,
            child: Texture(
              textureId: descriptor.flutterTextureId,
              filterQuality: FilterQuality.none,
              freeze: false,
            ),
          ),
        ),
      ],
    );
  }
}
