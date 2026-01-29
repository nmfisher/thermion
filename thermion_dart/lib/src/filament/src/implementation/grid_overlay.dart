import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/interface/defaults.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

class GridOverlay {
  final List<FFIAsset> assets;

  GridOverlay(this.assets);

  static GridOverlay? _instance;
  static Material? _gridMaterial;
  static List<LinearColor> _currentAxisColors = kDefaultAxisColors;

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
      {List<LinearColor> axisColors = kDefaultAxisColors, LinearColor gridColor = kDefaultGridColor } ) async {
    if (_instance == null) {
      _gridMaterial ??=
          FFIMaterial(Material_createGridMaterial(FilamentApp.instance!.engine));

      final assets = <FFIAsset>[];

      final intervals = [1.0, 10.0, 100.0];
      final fadeInStart = [0.001, 5.0, 50.0];
      final fadeInEnd = [0.001, 50.0, 500.0];
      final fadeOutStart = [10.0, 500.0, 5000.0];
      final fadeOutEnd = [200.0, 2000.0, 20000.0];
      

      for (int i = 0; i < 3; i++) {
        final assetPtr = await withPointerCallback<TSceneAsset>((cb) =>
            SceneAsset_createGridRenderThread(
                FilamentApp.instance!.engine, _gridMaterial!.getNativeHandle(), cb));
        final ffiAsset = FFIAsset(assetPtr);
        var materialInstance = await ffiAsset.getMaterialInstanceAt();
        if(i == 2) {
          await materialInstance.setParameterBool("showAxisX", true);  
          await materialInstance.setParameterBool("showAxisZ", true);  
        }
        await materialInstance.setParameterFloat3("gridColor", gridColor.r, gridColor.g, gridColor.b);
        await materialInstance.setParameterFloat3("axisColorX", axisColors[0].r, axisColors[0].g, axisColors[0].b);
        await materialInstance.setParameterFloat3("axisColorY", axisColors[1].r, axisColors[1].g, axisColors[1].b);
        await materialInstance.setParameterFloat3("axisColorZ", axisColors[2].r, axisColors[2].g, axisColors[2].b);
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
      _currentAxisColors = axisColors;
      _instance = GridOverlay(assets);
    }
    return _instance!;
  }

  ///
  /// Sets the axis colors for the grid overlay.
  /// [axisColors] should be a list of exactly 3 LinearColor objects: [X-axis, Y-axis, Z-axis]
  ///
  Future<void> setAxisColor(List<LinearColor> axisColors) async {
    if (axisColors.length != 3) {
      throw ArgumentError("axisColors must contain exactly 3 colors for X, Y, and Z axes");
    }

    _currentAxisColors = axisColors;

    // Update existing assets' material instances
    for (final asset in assets) {
      var materialInstance = await asset.getMaterialInstanceAt();
      await materialInstance.setParameterFloat3("axisColorX", axisColors[0].r, axisColors[0].g, axisColors[0].b);
      await materialInstance.setParameterFloat3("axisColorY", axisColors[1].r, axisColors[1].g, axisColors[1].b);
      await materialInstance.setParameterFloat3("axisColorZ", axisColors[2].r, axisColors[2].g, axisColors[2].b);
    }
  }

  ///
  ///
  ///
  Future<FFIAsset> createInstance(
      {List<MaterialInstance>? materialInstances = null}) async {
    throw Exception(
        "Only a single instance of the grid overlay can be created");
  }
}
