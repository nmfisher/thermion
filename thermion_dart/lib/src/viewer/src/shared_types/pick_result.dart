// "picking" means clicking/tapping on the viewport, and unprojecting the X/Y coordinate to determine whether any renderable entities were present at those coordinates.
import '../../viewer.dart';

typedef FilamentPickResult = ({ThermionEntity entity, int x, int y});
typedef PickResult = FilamentPickResult;
