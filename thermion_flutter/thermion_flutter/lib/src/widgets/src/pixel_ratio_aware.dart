import 'package:flutter/widgets.dart';

class PixelRatioAware extends StatelessWidget {
  final Widget Function(BuildContext context, double pixelRatio) builder;

  const PixelRatioAware({Key? key, required this.builder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return builder(context, MediaQuery.of(context).devicePixelRatio);
  }
}