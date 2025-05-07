const double kNear = 0.05;
const double kFar = 1000.0;
const double kFocalLength = 28.0;

enum VisibilityLayers {
  DEFAULT_ASSET(0),
  LAYER_1(1),
  LAYER_2(2),
  LAYER_3(3),
  LAYER_4(4),
  LAYER_5(5),
  BACKGROUND(6),
  OVERLAY(7);

  final int value;
  const VisibilityLayers(this.value);
}

