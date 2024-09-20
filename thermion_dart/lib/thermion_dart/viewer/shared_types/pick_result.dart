// "picking" means clicking/tapping on the viewport, and unprojecting the X/Y coordinate to determine whether any renderable entities were present at those coordinates.
import 'package:thermion_dart/thermion_dart/viewer/shared_types/shared_types.dart';

typedef FilamentPickResult = ({ThermionEntity entity, double x, double y});
typedef ThermionPickResult = FilamentPickResult;
