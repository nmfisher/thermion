import 'dart:math';

import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

class GridOverlay {
  final List<FFIAsset> assets;

  GridOverlay(this.assets);

  static GridOverlay? _instance;
  static Material? _gridMaterial;

  Future addToScene(Scene scene) async {
    for (final asset in assets) {
      await scene.add(asset);
    }
  }

  Future removeFromScene(Scene scene) async {
    for (final asset in assets) {
      await scene.remove(asset);
    }
  }

  Future destroy() async {
    for (final asset in assets) {
      await FilamentApp.instance!.destroyAsset(asset);
    }
  }

  static Future<GridOverlay> create(
      FFIFilamentApp app, Pointer<TAnimationManager> animationManager) async {
    if (_instance == null) {
      _gridMaterial ??=
          FFIMaterial(Material_createGridMaterial(app.engine), app);

      final assets = <FFIAsset>[];

      final intervals = [1.0, 10.0, 100.0];
      final fadeInStart = [0.001, 5.0, 50.0];
      final fadeInEnd = [0.001, 50.0, 500.0];
      final fadeOutStart = [10.0, 500.0, 5000.0];
      final fadeOutEnd = [200.0, 2000.0, 20000.0];
      

      for (int i = 0; i < 3; i++) {
        final assetPtr = await withPointerCallback<TSceneAsset>((cb) =>
            SceneAsset_createGridRenderThread(
                app.engine, _gridMaterial!.getNativeHandle(), cb));
        final ffiAsset = FFIAsset(assetPtr, app, animationManager);
        var materialInstance = await ffiAsset.getMaterialInstanceAt();
        if(i == 2) {
          await materialInstance.setParameterBool("showAxes", true);  
        }
        await materialInstance.setParameterFloat3("gridColor", 0.3, 0.35, 0.3);
        await materialInstance.setParameterFloat("distance", 10000.0);
        await materialInstance.setParameterFloat("interval", intervals[i]);
        await materialInstance.setParameterFloat(
            "fadeInStart", fadeInStart[i]);
        await materialInstance.setParameterFloat(
            "fadeInEnd", fadeInEnd[i]);
        await materialInstance.setParameterFloat(
            "fadeOutStart", fadeOutStart[i]);
        await materialInstance.setParameterFloat(
            "fadeOutEnd", fadeOutEnd[i]);

        await FilamentApp.instance!.setPriority(ffiAsset.entity, 0);
        for (final child in await ffiAsset.getChildEntities()) {
          await FilamentApp.instance!.setPriority(child, 7);
        }
        assets.add(ffiAsset);
      }
      _instance = GridOverlay(assets);
    }
    return _instance!;
  }

  ///
  ///
  ///
  @override
  Future<FFIAsset> createInstance(
      {List<MaterialInstance>? materialInstances = null}) async {
    throw Exception(
        "Only a single instance of the grid overlay can be created");
  }
}
