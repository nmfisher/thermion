import '../../../viewer/viewer.dart';

/// The result of a picking operation (see [ThermionViewer.pick] for more details).
/// [x] and [y] refer to the original screen coordinates used to call [pick]; this should
/// match the values of [fragX] and [fragY]. [fragZ] is the depth value in screen coordinates, 
/// [depth] is the value in the depth buffer (i.e. fragZ = 1.0 - depth).
/// 
typedef FilamentPickResult = ({
  ThermionEntity entity,
  int x,
  int y,
  double depth,
  double fragX,
  double fragY,
  double fragZ
});
typedef PickResult = FilamentPickResult;
