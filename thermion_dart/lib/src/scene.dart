import 'dart:convert';
import 'package:vector_math/vector_math_64.dart';

import '../thermion_dart.dart';

class SceneV2 {
  final Map<String, AssetInfo> assets;
  final List<LightInfo> lights;
  List<CameraInfo> cameras;
  final List<EntityInfo> entities;
  EnvironmentInfo? environment;

  SceneV2({
    Map<String, AssetInfo>? assets,
    List<LightInfo>? lights,
    List<CameraInfo>? cameras,
    List<EntityInfo>? entities,
    this.environment,
  })  : assets = assets ?? {},
        lights = lights ?? [],
        cameras = cameras ?? [],
        entities = entities ?? [];

  void addAsset(String uri, AssetType type) {
    assets[uri] = AssetInfo(uri: uri, type: type);
  }

  void addLight(LightInfo light) {
    lights.add(light);
  }

  void clearAssets() {
    assets.clear();
  }

  void clearLights() {
    lights.clear();
  }

  void setCamera(Matrix4 modelMatrix, Matrix4 projectionMatrix) {
    var camera = cameras.firstWhere((cam) => cam.isActive);
    camera.modelMatrix = modelMatrix;
    camera.projectionMatrix = projectionMatrix;
  }

  void addEntity(String assetUri, Matrix4 transform) {
    if (assets.containsKey(assetUri)) {
      entities.add(EntityInfo(assetUri: assetUri, transform: transform));
    } else {
      throw Exception('Asset not found: $assetUri');
    }
  }

  void setEnvironment(String? skyboxUri, String? iblUri) {
    environment = EnvironmentInfo(skyboxUri: skyboxUri, iblUri: iblUri);
  }

  Map<String, dynamic> toJson() => {
        'assets': assets.map((key, value) => MapEntry(key, value.toJson())),
        'lights': lights.map((light) => light.toJson()).toList(),
        'cameras': cameras.map((camera) => camera.toJson()),
        'entities': entities.map((entity) => entity.toJson()).toList(),
        'environment': environment?.toJson(),
      };

  String toJsonString() => jsonEncode(toJson());

  static SceneV2 fromJson(Map<String, dynamic> json) {
    return SceneV2(
      assets: (json['assets'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, AssetInfo.fromJson(value)),
      ),
      lights: (json['lights'] as List)
          .map((light) => LightInfo.fromJson(light))
          .toList(),
      cameras: json['cameras'].map((camera) => CameraInfo.fromJson),
      entities: (json['entities'] as List)
          .map((entity) => EntityInfo.fromJson(entity))
          .toList(),
      environment: json['environment'] != null
          ? EnvironmentInfo.fromJson(json['environment'])
          : null,
    );
  }

  static SceneV2 fromJsonString(String jsonString) =>
      fromJson(jsonDecode(jsonString));
}

class AssetInfo {
  final String uri;
  final AssetType type;

  AssetInfo({required this.uri, required this.type});

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'type': type.toString().split('.').last,
      };

  static AssetInfo fromJson(Map<String, dynamic> json) {
    return AssetInfo(
      uri: json['uri'],
      type: AssetType.values.firstWhere(
          (e) => e.toString().split('.').last == json['type'],
          orElse: () => AssetType.glb),
    );
  }
}

enum AssetType { glb, gltf, geometryPrimitive }

class LightInfo {
  final LightType type;
  final Vector3 position;
  final Vector3 direction;
  final Color color;
  final double intensity;

  LightInfo({
    required this.type,
    required this.position,
    required this.direction,
    required this.color,
    required this.intensity,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toString().split('.').last,
        'position': [position.x, position.y, position.z],
        'direction': [direction.x, direction.y, direction.z],
        'color': color.toJson(),
        'intensity': intensity,
      };

  static LightInfo fromJson(Map<String, dynamic> json) {
    return LightInfo(
      type: LightType.values.firstWhere((e) => e.name == json['type']),
      position: Vector3.array(json['position'].cast<double>()),
      direction: Vector3.array(json['direction'].cast<double>()),
      color: Color.fromJson(json['color']),
      intensity: json['intensity'],
    );
  }
}

class CameraInfo {
  final bool isActive;
  Matrix4 modelMatrix;
  Matrix4 projectionMatrix;

  CameraInfo(
      {required this.isActive,
      required this.modelMatrix,
      required this.projectionMatrix});

  Map<String, dynamic> toJson() => {
        'modelMatrix': modelMatrix.storage,
        'projectionMatrix': projectionMatrix.storage,
        'isActive': isActive,
      };

  static CameraInfo fromJson(Map<String, dynamic> json) {
    return CameraInfo(
        modelMatrix:
            Matrix4.fromFloat64List(json['modelMatrix'].cast<double>()),
        projectionMatrix:
            Matrix4.fromFloat64List(json['modelMatrix'].cast<double>()),
        isActive: json["isActive"]);
  }
}

class EntityInfo {
  final String assetUri;
  final Matrix4 transform;

  EntityInfo({required this.assetUri, required this.transform});

  Map<String, dynamic> toJson() => {
        'assetUri': assetUri,
        'transform': transform.storage,
      };

  static EntityInfo fromJson(Map<String, dynamic> json) {
    return EntityInfo(
      assetUri: json['assetUri'],
      transform: Matrix4.fromList(List<double>.from(json['transform'])),
    );
  }
}

class EnvironmentInfo {
  final String? skyboxUri;
  final String? iblUri;

  EnvironmentInfo({this.skyboxUri, this.iblUri});

  Map<String, dynamic> toJson() => {
        'skyboxUri': skyboxUri,
        'iblUri': iblUri,
      };

  static EnvironmentInfo fromJson(Map<String, dynamic> json) {
    return EnvironmentInfo(
      skyboxUri: json['skyboxUri'],
      iblUri: json['iblUri'],
    );
  }
}

class Color {
  final double r;
  final double g;
  final double b;
  final double a;

  Color({required this.r, required this.g, required this.b, this.a = 1.0});

  Map<String, dynamic> toJson() => {
        'r': r,
        'g': g,
        'b': b,
        'a': a,
      };

  static Color fromJson(Map<String, dynamic> json) {
    return Color(
      r: json['r'],
      g: json['g'],
      b: json['b'],
      a: json['a'],
    );
  }
}
