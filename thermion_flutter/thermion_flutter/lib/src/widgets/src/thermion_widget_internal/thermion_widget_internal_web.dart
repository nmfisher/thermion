// import 'dart:async';
// import 'dart:ui' as ui;
// import 'dart:ui_web' as ui_web;
// import 'package:flutter/material.dart' hide View;
// import 'package:logging/logging.dart';
// import 'package:thermion_flutter/thermion_flutter.dart' hide BlendMode;
// import 'package:web/web.dart' as web;
// import '../../../platform/platform.dart';
// import '../../../platform/src/platform_texture_descriptor.dart';
// import '../../../platform/src/web_platform_texture_descriptor.dart';

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox.expand(child: CustomPaint(painter: TransparencyPainter()));
//     return ThermionFlutterPlugin
//             .instance.options.webOptions.importCanvasAsWidget
//         ? _ImageCopyingWidget(
//             view: widget.view,
//           )
//         : SizedBox.expand(child: CustomPaint(painter: TransparencyPainter()));
//   }
// }

// class TransparencyPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     canvas.drawRect(
//       Rect.fromLTWH(0, 0, size.width, size.height),
//       Paint()
//         ..blendMode = BlendMode.clear
//         ..color = const Color(0x00000000),
//     );
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }

// class _PlatformView extends StatefulWidget {
//   final ThermionViewer viewer;

//   const _PlatformView({super.key, required this.viewer});
//   @override
//   State<StatefulWidget> createState() => _PlatformViewState();
// }

// class _PlatformViewState extends State<_PlatformView> {
//   @override
//   void initState() {
//     super.initState();
//     ui_web.platformViewRegistry.registerViewFactory(
//       'imported-canvas',
//       (int viewId, {Object? params}) {
//         var canvas = web.document.getElementById("thermion_canvas");
//         return canvas! as Object;
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return HtmlElementView(
//       viewType: 'imported-canvas',
//       onPlatformViewCreated: (i) {},
//       creationParams: <String, Object?>{
//         'key': 'someValue',
//       },
//     );
//   }
// }

// class _ImageCopyingWidget extends StatefulWidget {
//   final View view;

//   const _ImageCopyingWidget({
//     super.key,
//     required this.view,
//   });
//   @override
//   State<StatefulWidget> createState() {
//     return _ImageCopyingWidgetState();
//   }
// }

// class _ImageCopyingWidgetState extends State<_ImageCopyingWidget> {
//   static const _debounceDuration = Duration(milliseconds: 100);

//   late final _logger = Logger(runtimeType.toString());
//   late web.HTMLCanvasElement canvas;
//   ui.Image? _img;
//   double width = 0;
//   double height = 0;

//   // Track current and pending dimensions for debouncing
//   int _currentWidth = 0;
//   int _currentHeight = 0;
//   int? _pendingWidth;
//   int? _pendingHeight;
//   Timer? _debounceTimer;

//   @override
//   void initState() {
//     super.initState();
//     canvas =
//         web.document.getElementById("thermion_canvas") as web.HTMLCanvasElement;
//     WidgetsBinding.instance.addPostFrameCallback((t) {
//       _refresh(Duration.zero);
//     });
//   }

//   @override
//   void dispose() {
//     _debounceTimer?.cancel();
//     super.dispose();
//   }

//   void _refresh(Duration _) async {
//     try {
//       final rb = context.findRenderObject() as RenderBox?;

//       if (rb == null) {
//         setState(() {});
//         return;
//       }

//       if (rb.size.isEmpty) {
//         setState(() {});
//         return;
//       }

//       // Calculate desired dimensions based on widget size and DPR
//       final dpr = web.window.devicePixelRatio;
//       final desiredWidth = (rb.size.width * dpr).ceil();
//       final desiredHeight = (rb.size.height * dpr).ceil();

//       // Check if canvas size needs updating
//       if (canvas.width != desiredWidth || canvas.height != desiredHeight) {
//         _scheduleResize(desiredWidth, desiredHeight);
//       }

//       width = canvas.width * dpr;
//       height = canvas.height * dpr;
//       _img = await ui_web.createImageFromTextureSource(canvas,
//           width: width.ceil(), height: height.ceil(), transferOwnership: true);

//       _request++;
//     } catch (err) {
//       _logger.severe(err);
//     } finally {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         setState(() {});
//       });
//       WidgetsBinding.instance.scheduleFrameCallback(_refresh);
//     }
//   }

//   int _request = 0;

//   void _scheduleResize(int width, int height) {
//     _pendingWidth = width;
//     _pendingHeight = height;

//     _debounceTimer?.cancel();
//     _debounceTimer = Timer(_debounceDuration, () {
//       if (_pendingWidth != null && _pendingHeight != null) {
//         _performResize(_pendingWidth!, _pendingHeight!);
//       }
//     });
//   }

//   void _performResize(int width, int height) async {
//     if (_currentWidth == width && _currentHeight == height) {
//       return;
//     }

//     _logger.info("Resizing canvas to ${width}x$height");

//     try {
//       final plugin =
//           ThermionFlutterPlugin.instance as ThermionFlutterPluginImpl;
//       plugin.resizeCanvas(width / web.window.devicePixelRatio,
//           height / web.window.devicePixelRatio);

//       await widget.view
//           .setViewport(width, height)
//           .timeout(Duration(seconds: 1));

//       _currentWidth = width;
//       _currentHeight = height;

//     } catch (err) {
//       _logger.severe("Failed to resize: $err");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_img == null) {
//       return Container();
//     }

//     return RawImage(
//       key: Key(_request.toString()),
//       width: width,
//       height: height,
//       image: _img!,
//       filterQuality: FilterQuality.high,
//       isAntiAlias: false,
//     );
//   }
// }

// import 'package:flutter/material.dart';

// class TransparencyPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     canvas.drawRect(
//       Rect.fromLTWH(0, 0, size.width, size.height),
//       Paint()
//         ..blendMode = BlendMode.clear
//         ..color = const Color(0x00000000),
//     );
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }
