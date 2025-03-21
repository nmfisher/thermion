import 'dart:typed_data';
import 'package:thermion_dart/src/filament/src/light_options.dart';
import 'package:thermion_dart/thermion_dart.dart';

class ThermionViewerStub extends ThermionViewer {
  @override
  Future<ThermionEntity> addDirectLight(DirectLight light) {
    // TODO: implement addDirectLight
    throw UnimplementedError();
  }

  @override
  Future addToScene(covariant ThermionAsset asset) {
    // TODO: implement addToScene
    throw UnimplementedError();
  }

  @override
  Future clearBackgroundImage() {
    // TODO: implement clearBackgroundImage
    throw UnimplementedError();
  }

  @override
  Future<Camera> createCamera() {
    // TODO: implement createCamera
    throw UnimplementedError();
  }

  @override
  Future<GizmoAsset> createGizmo(covariant View view, GizmoType type) {
    // TODO: implement createGizmo
    throw UnimplementedError();
  }

  @override
  Future destroyAsset(ThermionAsset asset) {
    // TODO: implement destroyAsset
    throw UnimplementedError();
  }

  @override
  Future destroyAssets() {
    // TODO: implement destroyAssets
    throw UnimplementedError();
  }

  @override
  Future destroyCamera(covariant Camera camera) {
    // TODO: implement destroyCamera
    throw UnimplementedError();
  }

  @override
  Future destroyLights() {
    // TODO: implement destroyLights
    throw UnimplementedError();
  }

  @override
  Future dispose() {
    // TODO: implement dispose
    throw UnimplementedError();
  }

  @override
  Future<Camera> getActiveCamera() {
    // TODO: implement getActiveCamera
    throw UnimplementedError();
  }

  @override
  int getCameraCount() {
    // TODO: implement getCameraCount
    throw UnimplementedError();
  }

  @override
  Future<Aabb3> getRenderableBoundingBox(ThermionEntity entity) {
    // TODO: implement getRenderableBoundingBox
    throw UnimplementedError();
  }

  @override
  Future<Aabb2> getViewportBoundingBox(ThermionEntity entity) {
    // TODO: implement getViewportBoundingBox
    throw UnimplementedError();
  }

  @override
  // TODO: implement initialized
  Future<bool> get initialized => throw UnimplementedError();

  @override
  Future<ThermionAsset> loadGltf(String path, {int numInstances = 1, bool keepData = false, String? relativeResourcePath}) {
    // TODO: implement loadGltf
    throw UnimplementedError();
  }

  @override
  Future<ThermionAsset> loadGltfFromBuffer(Uint8List data, {int numInstances = 1, bool keepData = false, int priority = 4, int layer = 0, bool loadResourcesAsync = false, String? relativeResourcePath}) {
    // TODO: implement loadGltfFromBuffer
    throw UnimplementedError();
  }

  @override
  Future loadIbl(String lightingPath, {double intensity = 30000}) {
    // TODO: implement loadIbl
    throw UnimplementedError();
  }

  @override
  Future loadSkybox(String skyboxPath) {
    // TODO: implement loadSkybox
    throw UnimplementedError();
  }

  @override
  // TODO: implement msPerFrame
  double get msPerFrame => throw UnimplementedError();

  @override
  void onDispose(Future Function() callback) {
    // TODO: implement onDispose
  }

  @override
  Future pick(int x, int y, void Function(PickResult p1) resultHandler) {
    // TODO: implement pick
    throw UnimplementedError();
  }

  @override
  Future removeFromScene(covariant ThermionAsset asset) {
    // TODO: implement removeFromScene
    throw UnimplementedError();
  }

  @override
  Future removeGridOverlay() {
    // TODO: implement removeGridOverlay
    throw UnimplementedError();
  }

  @override
  Future removeIbl() {
    // TODO: implement removeIbl
    throw UnimplementedError();
  }

  @override
  Future removeLight(ThermionEntity light) {
    // TODO: implement removeLight
    throw UnimplementedError();
  }

  @override
  Future removeSkybox() {
    // TODO: implement removeSkybox
    throw UnimplementedError();
  }

  @override
  Future render() {
    // TODO: implement render
    throw UnimplementedError();
  }

  @override
  // TODO: implement rendering
  bool get rendering => throw UnimplementedError();

  @override
  Future rotateIbl(Matrix3 rotation) {
    // TODO: implement rotateIbl
    throw UnimplementedError();
  }

  @override
  Future setActiveCamera(covariant Camera camera) {
    // TODO: implement setActiveCamera
    throw UnimplementedError();
  }

  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) {
    // TODO: implement setAntiAliasing
    throw UnimplementedError();
  }

  @override
  Future setBackgroundColor(double r, double g, double b, double alpha) {
    // TODO: implement setBackgroundColor
    throw UnimplementedError();
  }

  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) {
    // TODO: implement setBackgroundImage
    throw UnimplementedError();
  }

  @override
  Future setBackgroundImagePosition(double x, double y, {bool clamp = false}) {
    // TODO: implement setBackgroundImagePosition
    throw UnimplementedError();
  }

  @override
  Future setBloom(bool enabled, double strength) {
    // TODO: implement setBloom
    throw UnimplementedError();
  }

  @override
  Future setFrameRate(int framerate) {
    // TODO: implement setFrameRate
    throw UnimplementedError();
  }

  @override
  Future setLightDirection(ThermionEntity lightEntity, Vector3 direction) {
    // TODO: implement setLightDirection
    throw UnimplementedError();
  }

  @override
  Future setLightPosition(ThermionEntity lightEntity, double x, double y, double z) {
    // TODO: implement setLightPosition
    throw UnimplementedError();
  }

  @override
  Future setPostProcessing(bool enabled) {
    // TODO: implement setPostProcessing
    throw UnimplementedError();
  }

  @override
  Future setPriority(ThermionEntity entityId, int priority) {
    // TODO: implement setPriority
    throw UnimplementedError();
  }

  @override
  Future setRendering(bool render) {
    // TODO: implement setRendering
    throw UnimplementedError();
  }

  @override
  Future setShadowType(ShadowType shadowType) {
    // TODO: implement setShadowType
    throw UnimplementedError();
  }

  @override
  Future setShadowsEnabled(bool enabled) {
    // TODO: implement setShadowsEnabled
    throw UnimplementedError();
  }

  @override
  Future setSoftShadowOptions(double penumbraScale, double penumbraRatioScale) {
    // TODO: implement setSoftShadowOptions
    throw UnimplementedError();
  }

  @override
  Future setToneMapping(ToneMapper mapper) {
    // TODO: implement setToneMapping
    throw UnimplementedError();
  }

  @override
  Future setViewFrustumCulling(bool enabled) {
    // TODO: implement setViewFrustumCulling
    throw UnimplementedError();
  }

  @override
  Future showGridOverlay() {
    // TODO: implement showGridOverlay
    throw UnimplementedError();
  }

  @override
  // TODO: implement view
  View get view => throw UnimplementedError();
    
}
