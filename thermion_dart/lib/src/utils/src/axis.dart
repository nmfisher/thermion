import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../../viewer/viewer.dart';

class Axis {
  final ThermionViewer _viewer;
  final ThermionEntity xAxis;
  final ThermionEntity yAxis;
  final ThermionEntity zAxis;

  Axis._(this.xAxis, this.yAxis, this.zAxis, this._viewer);

  static Future<Axis> create(ThermionViewer viewer) async {
    final xAxis = await viewer!.createGeometry(
        Geometry(Float32List.fromList([0, 0, 0, 10, 0, 0]), [0, 1],
            primitiveType: PrimitiveType.LINES),
        materialInstance: await viewer!.createUnlitMaterialInstance());
    final yAxis = await viewer!.createGeometry(
        Geometry(Float32List.fromList([0, 0, 0, 0, 10, 0]), [0, 1],
            primitiveType: PrimitiveType.LINES),
        materialInstance: await viewer!.createUnlitMaterialInstance());
    final zAxis = await viewer!.createGeometry(
        Geometry(Float32List.fromList([0, 0, 0, 0, 0, 10]), [0, 1],
            primitiveType: PrimitiveType.LINES),
        materialInstance: await viewer!.createUnlitMaterialInstance());

    await viewer!.setMaterialPropertyFloat4(
        xAxis, "baseColorFactor", 0, 1.0, 0.0, 0.0, 1.0);
    await viewer!.setMaterialPropertyFloat4(
        yAxis, "baseColorFactor", 0, 0.0, 1.0, 0.0, 1.0);
    await viewer!.setMaterialPropertyFloat4(
        zAxis, "baseColorFactor", 0, 0.0, 0.0, 1.0, 1.0);
    return Axis._(xAxis, yAxis, zAxis, viewer);
  }

  Future setTransform(Matrix4 transform) async {
    await _viewer.setTransform(xAxis, transform);
    await _viewer.setTransform(yAxis, transform);
    await _viewer.setTransform(zAxis, transform);
    
  }
}
