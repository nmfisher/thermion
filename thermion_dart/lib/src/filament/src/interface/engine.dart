export 'backend.g.dart';

enum FeatureLevel {
  FeatureLevel0(0),
  FeatureLevel1(1),
  FeatureLevel2(2),
  FeatureLevel3(3);

  final int value;
  const FeatureLevel(this.value);
}
