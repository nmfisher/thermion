import 'dart:async';

import 'package:flutter/widgets.dart';
// ignore: implementation_imports
import 'package:thermion_flutter/src/thermion_flutter_plugin.dart';

typedef ContextBootstrapAllocator = Future<int?> Function();
typedef ContextBootstrapWaiter = Future<void> Function(int textureId);
typedef ContextBootstrapDestroyer = Future<void> Function(int textureId);

/// Sequences [initialize] after the texture handshake some platforms require
/// before the native viewer can be created.
///
/// Linux OpenGL cannot create Filament's shared GL context until Flutter has
/// composited an external texture at least once. Until then there is nothing
/// on the Flutter side for Filament's context to share with. So this widget
/// renders a 1x1 [Texture], waits for the engine to populate it, runs
/// [initialize], and only then removes the layer and destroys the texture.
///
/// When the allocator returns null (every platform without the prerequisite,
/// and any viewer created after the first one), the handshake is skipped and
/// [initialize] runs immediately.
///
/// The lifecycle hooks come from [ThermionFlutterPlugin] by default; tests may
/// inject their own.
class ThermionTextureBootstrap extends StatefulWidget {
  const ThermionTextureBootstrap({
    super.key,
    required this.initialize,
    required this.child,
    this.createContextBootstrap,
    this.awaitContextBootstrap,
    this.destroyContextBootstrap,
  });

  final Future<void> Function() initialize;
  final Widget child;
  final ContextBootstrapAllocator? createContextBootstrap;
  final ContextBootstrapWaiter? awaitContextBootstrap;
  final ContextBootstrapDestroyer? destroyContextBootstrap;

  @override
  State<ThermionTextureBootstrap> createState() =>
      _ThermionTextureBootstrapState();
}

class _ThermionTextureBootstrapState extends State<ThermionTextureBootstrap> {
  int? _textureId;
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
    final textureId = await _allocate();
    _textureId = textureId;

    try {
      if (_disposing) return;

      if (textureId != null) {
        if (mounted) {
          setState(() {});
        }
        try {
          await _awaitReady(textureId);
        } catch (_) {
          // Destroying the texture is how dispose() cancels a pending
          // native populate handshake.
          if (_disposing) return;
          rethrow;
        }
      }

      if (_disposing) return;
      await widget.initialize();
    } finally {
      if (_textureId == textureId) {
        _textureId = null;
      }
      if (textureId != null && mounted && !_disposing) {
        // Remove the Texture layer before unregistering its native texture.
        setState(() {});
        await WidgetsBinding.instance.endOfFrame;
      }
      if (textureId != null) {
        await _destroy(textureId);
      }
    }
  }

  Future<int?> _allocate() {
    final create = widget.createContextBootstrap;
    if (create != null) {
      return create();
    }
    return ThermionFlutterPlugin.instance.createContextBootstrap();
  }

  Future<void> _awaitReady(int textureId) {
    final wait = widget.awaitContextBootstrap;
    if (wait != null) {
      return wait(textureId);
    }
    return ThermionFlutterPlugin.instance.awaitContextBootstrap(textureId);
  }

  Future<void> _destroy(int textureId) {
    return _destroyFuture ??= () {
      final destroy = widget.destroyContextBootstrap;
      if (destroy != null) {
        return destroy(textureId);
      }
      return ThermionFlutterPlugin.instance.destroyContextBootstrap(textureId);
    }();
  }

  @override
  void dispose() {
    _disposing = true;
    final textureId = _textureId;
    if (textureId != null) {
      unawaited(
        _destroy(textureId).catchError((Object error, StackTrace stack) {
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
    final textureId = _textureId;
    if (textureId == null) {
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
              textureId: textureId,
              filterQuality: FilterQuality.none,
              freeze: false,
            ),
          ),
        ),
      ],
    );
  }
}
