import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFILightManager extends LightManager<Pointer<TLightManager>> {
  late final _logger = Logger(this.runtimeType.toString());

  final Pointer<TLightManager> lightManager;
  final FFIFilamentApp app;

  FFILightManager(this.lightManager, this.app);

  @override
  Pointer<TLightManager> getNativeHandle() => lightManager;

  @override
  ThermionEntity createLight(LightType type) {
    final tLightType = _convertLightType(type);
    final entityId = LightManager_createLight(app.engine, lightManager, tLightType);

    if (entityId == -1) {
      throw Exception("Failed to create light of type $type");
    }

    _logger.info("Created light of type $type with entity ID $entityId");
    return entityId;
  }

  @override
  void destroyLight(ThermionEntity entity) {
    LightManager_destroyLight(lightManager, entity);
    _logger.info("Destroyed light with entity ID $entity");
  }

  @override
  void setPosition(ThermionEntity light, double x, double y, double z) {
    LightManager_setPosition(lightManager, light, x, y, z);
  }

  @override
  void setDirection(ThermionEntity light, double x, double y, double z) {
    LightManager_setDirection(lightManager, light, x, y, z);
  }

  @override
  void setColor(ThermionEntity light, double r, double g, double b) {
    LightManager_setColor(lightManager, light, r, g, b);
  }

  @override
  void setColorTemperature(ThermionEntity light, double colorTemperature) {
    LightManager_setColorTemperature(lightManager, light, colorTemperature);
  }

  @override
  void setIntensity(ThermionEntity light, double intensity) {
    LightManager_setIntensity(lightManager, light, intensity);
  }

  @override
  void setFalloff(ThermionEntity light, double falloff) {
    LightManager_setFalloff(lightManager, light, falloff);
  }

  @override
  void setSpotLightCone(ThermionEntity light, double inner, double outer) {
    LightManager_setSpotLightCone(lightManager, light, inner, outer);
  }

  @override
  Future<void> setShadowCaster(ThermionEntity light, bool enabled) async {
    await withVoidCallback(
      (requestId, cb) => LightManager_setShadowCasterRenderThread(lightManager, light, enabled, requestId, cb),
    );
  }

  @override
  bool hasComponent(ThermionEntity entity) {
    return LightManager_hasComponent(lightManager, entity);
  }

  @override
  LightType getType(ThermionEntity entity) {
    final typeInt = LightManager_getType(lightManager, entity);
    return _convertFromCLightType(typeInt);
  }

  @override
  bool isDirectional(ThermionEntity entity) {
    return LightManager_isDirectional(lightManager, entity);
  }

  @override
  bool isPointLight(ThermionEntity entity) {
    return LightManager_isPointLight(lightManager, entity);
  }

  @override
  bool isSpotLight(ThermionEntity entity) {
    return LightManager_isSpotLight(lightManager, entity);
  }

  @override
  List<double> getPosition(ThermionEntity light) {
    final result = LightManager_getPosition(lightManager, light);
    return [result.x, result.y, result.z];
  }

  @override
  List<double> getDirection(ThermionEntity light) {
    final result = LightManager_getDirection(lightManager, light);
    return [result.x, result.y, result.z];
  }

  @override
  List<double> getColor(ThermionEntity light) {
    final result = LightManager_getColor(lightManager, light);
    return [result.x, result.y, result.z];
  }

  @override
  void setIntensityCandela(ThermionEntity light, double intensity) {
    LightManager_setIntensityCandela(lightManager, light, intensity);
  }

  @override
  void setIntensityWatts(ThermionEntity light, double watts, double efficiency) {
    LightManager_setIntensityWatts(lightManager, light, watts, efficiency);
  }

  @override
  double getIntensity(ThermionEntity light) {
    return LightManager_getIntensity(lightManager, light);
  }

  @override
  double getFalloff(ThermionEntity light) {
    return LightManager_getFalloff(lightManager, light);
  }

  @override
  double getSpotLightOuterCone(ThermionEntity light) {
    return LightManager_getSpotLightOuterCone(lightManager, light);
  }

  @override
  double getSpotLightInnerCone(ThermionEntity light) {
    return LightManager_getSpotLightInnerCone(lightManager, light);
  }

  @override
  void setSunAngularRadius(ThermionEntity light, double angularRadius) {
    LightManager_setSunAngularRadius(lightManager, light, angularRadius);
  }

  @override
  double getSunAngularRadius(ThermionEntity light) {
    return LightManager_getSunAngularRadius(lightManager, light);
  }

  @override
  void setSunHaloSize(ThermionEntity light, double haloSize) {
    LightManager_setSunHaloSize(lightManager, light, haloSize);
  }

  @override
  double getSunHaloSize(ThermionEntity light) {
    return LightManager_getSunHaloSize(lightManager, light);
  }

  @override
  void setSunHaloFalloff(ThermionEntity light, double haloFalloff) {
    LightManager_setSunHaloFalloff(lightManager, light, haloFalloff);
  }

  @override
  double getSunHaloFalloff(ThermionEntity light) {
    return LightManager_getSunHaloFalloff(lightManager, light);
  }

  @override
  bool isShadowCaster(ThermionEntity light) {
    return LightManager_isShadowCaster(lightManager, light);
  }

  @override
  Future<void> setShadowOptions(ThermionEntity light, ShadowOptions options) async {
    final tShadowOptions = StructAllocator.create<TShadowOptions>();
    tShadowOptions.mapSize = options.mapSize;
    tShadowOptions.shadowCascades = options.shadowCascades;

    // For N cascades, N-1 split positions are used
    final requiredSplits = tShadowOptions.shadowCascades - 1;
    if (requiredSplits > 0) {
      if (options.cascadeSplitPositions.length < requiredSplits) {
        throw ArgumentError(
          'cascadeSplitPositions must have at least $requiredSplits elements for ${tShadowOptions.shadowCascades} cascades',
        );
      }
      // Copy the required split positions, ensuring we don't exceed array bounds
      for (int i = 0; i < requiredSplits; i++) {
        tShadowOptions.cascadeSplitPositions[i] = options.cascadeSplitPositions[i];
      }
    }
    tShadowOptions.constantBias = options.constantBias;
    tShadowOptions.normalBias = options.normalBias;
    tShadowOptions.shadowFar = options.shadowFar;
    tShadowOptions.shadowNearHint = options.shadowNearHint;
    tShadowOptions.shadowFarHint = options.shadowFarHint;
    tShadowOptions.stable = options.stable;
    tShadowOptions.lispsm = options.lispsm;
    tShadowOptions.polygonOffsetConstant = options.polygonOffsetConstant;
    tShadowOptions.polygonOffsetSlope = options.polygonOffsetSlope;
    tShadowOptions.screenSpaceContactShadows = options.screenSpaceContactShadows;
    tShadowOptions.stepCount = options.stepCount;
    tShadowOptions.maxShadowDistance = options.maxShadowDistance;
    tShadowOptions.vsmElvsm = options.vsmElvsm;
    tShadowOptions.vsmBlurWidth = options.vsmBlurWidth;
    tShadowOptions.shadowBulbRadius = options.shadowBulbRadius;
    tShadowOptions.penumbraScale = options.penumbraScale;
    tShadowOptions.penumbraRatioScale = options.penumbraRatioScale;
    tShadowOptions.maxPenumbraRatio = options.maxPenumbraRatio;
    tShadowOptions.maxSearchRadius = options.maxSearchRadius;
    tShadowOptions.transformW = options.transform.w;
    tShadowOptions.transformX = options.transform.x;
    tShadowOptions.transformY = options.transform.y;
    tShadowOptions.transformZ = options.transform.z;

    await withVoidCallback(
      (requestId, cb) => LightManager_setShadowOptionsRenderThread(lightManager, light, tShadowOptions, requestId, cb),
    );
  }

  @override
  ShadowOptions getShadowOptions(ThermionEntity light) {
    final tShadowOptions = LightManager_getShadowOptions(lightManager, light);

    // For N cascades, N-1 split positions are used
    final splits = tShadowOptions.shadowCascades - 1;
    final positions = <double>[];
    for (int i = 0; i < splits && i < 3; i++) {
      positions.add(tShadowOptions.cascadeSplitPositions[i]);
    }

    return ShadowOptions(
      mapSize: tShadowOptions.mapSize,
      shadowCascades: tShadowOptions.shadowCascades,
      cascadeSplitPositions: positions,
      constantBias: tShadowOptions.constantBias,
      normalBias: tShadowOptions.normalBias,
      shadowFar: tShadowOptions.shadowFar,
      shadowNearHint: tShadowOptions.shadowNearHint,
      shadowFarHint: tShadowOptions.shadowFarHint,
      stable: tShadowOptions.stable,
      lispsm: tShadowOptions.lispsm,
      polygonOffsetConstant: tShadowOptions.polygonOffsetConstant,
      polygonOffsetSlope: tShadowOptions.polygonOffsetSlope,
      screenSpaceContactShadows: tShadowOptions.screenSpaceContactShadows,
      stepCount: tShadowOptions.stepCount,
      maxShadowDistance: tShadowOptions.maxShadowDistance,
      vsmElvsm: tShadowOptions.vsmElvsm,
      vsmBlurWidth: tShadowOptions.vsmBlurWidth,
      shadowBulbRadius: tShadowOptions.shadowBulbRadius,
      penumbraScale: tShadowOptions.penumbraScale,
      penumbraRatioScale: tShadowOptions.penumbraRatioScale,
      maxPenumbraRatio: tShadowOptions.maxPenumbraRatio,
      maxSearchRadius: tShadowOptions.maxSearchRadius,
      transform: Quaternion(
        tShadowOptions.transformX,
        tShadowOptions.transformY,
        tShadowOptions.transformZ,
        tShadowOptions.transformW,
      ),
    );
  }

  @override
  void setLightChannel(ThermionEntity light, int channel, bool enable) {
    LightManager_setLightChannel(lightManager, light, channel, enable);
  }

  @override
  bool getLightChannel(ThermionEntity light, int channel) {
    return LightManager_getLightChannel(lightManager, light, channel);
  }

  @override
  List<double> computeUniformSplits(int cascades) {
    if (cascades < 2 || cascades > 4) {
      throw ArgumentError("Cascades must be between 2 and 4");
    }

    final requiredSplits = cascades - 1;

    // Allocate native memory for the float array
    final pointer = makeFloat32List(requiredSplits);

    // Call the native method
    LightManager_computeUniformSplits(pointer.address, cascades);
    return pointer;
  }

  @override
  List<double> computeLogSplits(int cascades, double near, double far) {
    if (cascades < 2 || cascades > 4) {
      throw ArgumentError("Cascades must be between 2 and 4");
    }

    final requiredSplits = cascades - 1;

    // Allocate native memory for the float array
    final pointer = makeFloat32List(requiredSplits);

    // Call the native method
    LightManager_computeLogSplits(pointer.address, cascades, near, far);
    return pointer;
  }

  @override
  List<double> computePracticalSplits(int cascades, double near, double far, double lambda) {
    if (cascades < 2 || cascades > 4) {
      throw ArgumentError("Cascades must be between 2 and 4");
    }

    if (lambda < 0.0 || lambda > 1.0) {
      throw ArgumentError("Lambda must be between 0.0 and 1.0");
    }

    final requiredSplits = cascades - 1;

    // Allocate native memory for the float array
    final pointer = makeFloat32List(requiredSplits);

    // Call the native method
    LightManager_computePracticalSplits(pointer.address, cascades, near, far, lambda);
    return pointer;
  }

  @override
  double rgbToColorTemperature(double r, double g, double b) {
    return LightManager_rgbToColorTemperature(r, g, b);
  }

  int _convertLightType(LightType type) {
    switch (type) {
      case LightType.SUN:
        return TLightType.LIGHT_TYPE_SUN;
      case LightType.DIRECTIONAL:
        return TLightType.LIGHT_TYPE_DIRECTIONAL;
      case LightType.POINT:
        return TLightType.LIGHT_TYPE_POINT;
      case LightType.FOCUSED_SPOT:
        return TLightType.LIGHT_TYPE_FOCUSED_SPOT;
      case LightType.SPOT:
        return TLightType.LIGHT_TYPE_SPOT;
    }
  }

  LightType _convertFromCLightType(int type) {
    switch (type) {
      case TLightType.LIGHT_TYPE_SUN:
        return LightType.SUN;
      case TLightType.LIGHT_TYPE_DIRECTIONAL:
        return LightType.DIRECTIONAL;
      case TLightType.LIGHT_TYPE_POINT:
        return LightType.POINT;
      case TLightType.LIGHT_TYPE_FOCUSED_SPOT:
        return LightType.FOCUSED_SPOT;
      case TLightType.LIGHT_TYPE_SPOT:
        return LightType.SPOT;
      default:
        throw Exception("Unknown light type: $type");
    }
  }
}
