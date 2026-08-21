import 'dart:async';

import 'package:flutter/widgets.dart';

import 'platform_texture_descriptor.dart';

typedef ContextBootstrapAllocator =
    Future<PlatformTextureDescriptor?> Function();
typedef ContextBootstrapDestroyer = Future<void> Function(
  PlatformTextureDescriptor descriptor,
);

/// Hosts the Flutter-side prerequisites for initializing the native plugin,
/// then runs [initialize].
///
/// Linux OpenGL needs a real [Texture] layer before Filament can initialize.
/// Other platforms skip that handshake and invoke [initialize] immediately.
/// Keeping the layer and descriptor lifecycle here prevents viewer widgets
/// from depending on EGL or deferred texture details.
class ThermionFlutterPluginInitializer extends StatefulWidget {
  const ThermionFlutterPluginInitializer({
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
  State<ThermionFlutterPluginInitializer> createState() =>
      _ThermionFlutterPluginInitializerState();
}

class _ThermionFlutterPluginInitializerState
    extends State<ThermionFlutterPluginInitializer> {
  PlatformTextureDescriptor? _descriptor;
  Future<void>? _destroyFuture;
  bool _disposing = false;

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
    final descriptor = await widget.createContextBootstrap?.call();
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

  Future<void> _destroy(PlatformTextureDescriptor descriptor) {
    return _destroyFuture ??=
        widget.destroyContextBootstrap?.call(descriptor) ??
        descriptor.destroy();
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
