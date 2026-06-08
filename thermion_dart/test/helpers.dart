// ignore_for_file: unused_local_variable
import 'src/test_io.dart';
export 'src/test_io.dart';
import 'package:image/image.dart' as img;
import 'package:image/image.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_swapchain.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:path/path.dart' as p;

Color kGrey = ColorFloat32(4)..setRgba(0.5, 0.5, 0.5, 1.0);
Color kWhite = ColorFloat32(4)..setRgba(1.0, 1.0, 1.0, 1.0);
Color kRed = ColorFloat32(4)..setRgba(1.0, 0.0, 0.0, 1.0);
Color kGreen = ColorFloat32(4)..setRgba(0.0, 1.0, 0.0, 1.0);
Color kBlue = ColorFloat32(4)..setRgba(0.0, 0.0, 1.0, 1.0);

Future<Uint8List> savePixelBufferToBmp(
  Uint8List pixelBuffer,
  int width,
  int height,
  String outputPath, {
  bool hasAlpha = true,
  bool isFloat = true,
  int numChannels = 0,
}) async {
  var data = await pixelBufferToBmp(
    pixelBuffer,
    width,
    height,
    hasAlpha: hasAlpha,
    isFloat: isFloat,
    numChannels: numChannels,
  );
  await writeFileBytes(outputPath, data);
  Logger.root.info("Wrote bitmap to ${outputPath}");
  return data;
}

Future<Uint8List> savePixelBufferToPng(
  Uint8List pixelBuffer,
  int width,
  int height,
  String outputPath, {
  bool hasAlpha = true,
  bool isFloat = true,
  int numChannels = 0,
}) async {
  var data = await pixelBufferToPng(
    pixelBuffer,
    width,
    height,
    hasAlpha: hasAlpha,
    isFloat: isFloat,
    numChannels: numChannels,
  );
  await writeFileBytes(outputPath, data);
  Logger.root.info("Wrote bitmap to ${outputPath}");
  return data;
}

class TestHelper {
  late String outDirPath;
  late String testDir;
  late String assetsDir;
  final Backend? _backend;

  TestHelper(String? subDir, {Backend? backend}) : _backend = backend {
    final packageUri = findPackageRoot('thermion_dart').toFilePath();
    assetsDir = p.normalize(p.join(packageUri, '..', 'examples', 'assets'));
    if (subDir != null) {
      testDir = p.join(packageUri, "test");
      outDirPath = p.join(testDir, "output", subDir);
    } else {
      testDir = "/Users/nickfisher/Documents/thermion/thermion_dart/test";
      outDirPath = p.join(currentDirPath, "test_output");
    }
    createDirSync(outDirPath);
  }

  ///
  ///
  ///
  Future<Texture> createTextureFromImage(TestHelper testHelper) async {
    final image = await FilamentApp.instance!.decodeImage(
      await loadResourceBytes("${testHelper.assetsDir}/cube_texture_512x512.png"),
    );
    final texture = await FilamentApp.instance!.createTexture(await image.getWidth(), await image.getHeight());
    await texture.setLinearImage(image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
    return texture;
  }

  Future<MaterialInstance> loadViewSpaceMaterial() async {
    final material = await FilamentApp.instance!.createMaterial(
      await loadResourceBytes("${assetsDir}/viewspace.filamat"),
    );
    return material.createInstance();
  }

  Future<MaterialInstance> loadCustomAttributeMaterial() async {
    final material = await FilamentApp.instance!.createMaterial(
      await loadResourceBytes("${assetsDir}/customattributes.filamat"),
    );
    return material.createInstance();
  }

  /// Load the solidcolor material and create an instance with the given color.
  ///
  /// The solidcolor material only requires POSITION vertex attribute, making it
  /// suitable for testing custom vertex/index buffers without needing vertex colors.
  Future<MaterialInstance> loadSolidColorMaterial({
    required double r,
    required double g,
    required double b,
    double a = 1.0,
  }) async {
    final material = await FilamentApp.instance!.createMaterial(
      await loadResourceBytes("${assetsDir}/solidcolor.filamat"),
    );
    final instance = await material.createInstance();
    await instance.setParameterFloat4("color", r, g, b, a);
    return instance;
  }

  Future<ThermionAsset> createCube(ThermionViewer viewer) async {
    var materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: true);
    await materialInstance.setParameterFloat4("baseColorFactor", 1, 1, 1, 0);

    final cubeGeometry = GeometryUtils.cube(flipUvs: true);
    var asset = await viewer.createGeometry(cubeGeometry, materialInstances: [materialInstance]);
    return asset;
  }

  Future withCube(ThermionViewer viewer, Future Function(ThermionAsset cube) fn) async {
    var materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: true);
    await materialInstance.setParameterFloat4("baseColorFactor", 1, 1, 1, 0);

    final cubeGeometry = GeometryUtils.cube(flipUvs: true);
    var asset = await viewer.createGeometry(cubeGeometry, materialInstances: [materialInstance]);

    await fn(asset);
    await viewer.destroyAsset(asset);
  }

  ///
  ///
  ///
  Future<Map<View, Uint8List>> capture(
    View? view,
    String? outputFilename, {
    Future Function(View view)? beforeRender,
    SwapChain? swapChain,
    PixelDataFormat pixelDataFormat = PixelDataFormat.RGBA,
    PixelDataType pixelDataType = PixelDataType.FLOAT,
    bool captureRenderTarget = false,
    bool render = true,
  }) async {
    // WebGPU workaround: the blitter fails on format conversions involving
    // non-blendable formats (e.g. RGBA32Float), so capture() auto-downgrades
    // FLOAT to UBYTE when reading from the swapchain.  Mirror that here so
    // the PNG writer interprets the buffer correctly.
    // TODO: remove once Filament fixes the blitter (see docs/upstream.md).
    var effectivePixelDataType = pixelDataType;
    if (_backend == Backend.WEBGPU &&
        pixelDataType == PixelDataType.FLOAT &&
        !captureRenderTarget) {
      effectivePixelDataType = PixelDataType.UBYTE;
    }
    var pixelBuffers = await FilamentApp.instance!.capture(
      swapChain,
      view: view,
      beforeRender: beforeRender,
      pixelDataFormat: pixelDataFormat,
      pixelDataType: effectivePixelDataType,
      captureRenderTarget: captureRenderTarget,
      render: render,
    );
    var retval = <View, Uint8List>{};
    int i = 0;
    for (final (view, pixelBuffer) in pixelBuffers) {
      var vp = await view.getViewport();

      if (outputFilename != null) {
        var outPath = p.join(outDirPath, "${outputFilename}_view${i}.png");
        final numChannels = pixelDataFormat == PixelDataFormat.R
            ? 1
            : (pixelDataFormat == PixelDataFormat.RGBA ? 4 : 3);
        await savePixelBufferToPng(
          pixelBuffer,
          vp.width,
          vp.height,
          outPath,
          isFloat: effectivePixelDataType == PixelDataType.FLOAT,
          hasAlpha: pixelDataFormat == PixelDataFormat.RGBA,
          numChannels: numChannels,
        );
      }
      i++;
      retval[view] = pixelBuffer;
    }

    return retval;
  }

  // Future<MetalTextureWrapper> createTexture(int width, int height,
  //     {bool depth = false, bool stencil = false}) async {
  //   final object =
  //       MetalTextureWrapper.allocateWithWidth_height_isDepth_isStencil_(
  //           width, height, depth, stencil);
  //   return object;
  // }

  Future setup() async {
    Logger.root.level = Level.SEVERE;
    Logger.root.onRecord.listen((record) {
      print(record.toString());
    });

    await initTestBindings();

    await FFIFilamentApp.create(
      config: FFIFilamentConfig(
        loadResource: loadResourceBytes,
        backend: _backend ?? defaultTestBackend,
      ),
    );
  }

  Future<(ThermionViewer viewer, SwapChain swapChain)> createViewer({
    img.Color? bg,
    Vector3? cameraPosition,
    ({int width, int height}) viewportDimensions = (width: 512, height: 512),
    bool postProcessing = false,
    bool addSkybox = false,
    bool createRenderTarget = false,
    bool createStencilBuffer = false,
  }) async {
    cameraPosition ??= Vector3(0, 5, 5);

    final swapChain =
        await FilamentApp.instance!.createHeadlessSwapChain(
              viewportDimensions.width,
              viewportDimensions.height,
              hasStencilBuffer: createStencilBuffer,
            )
            as FFISwapChain;

    RenderTarget? renderTarget;
    Texture? rtColorTexture;
    Texture? rtDepthTexture;
    if (createRenderTarget) {
      Logger.root.info("Creating texture of size ${viewportDimensions}");
      rtColorTexture = await FilamentApp.instance!.createTexture(
        viewportDimensions.width,
        viewportDimensions.height,
        flags: {
          TextureUsage.TEXTURE_USAGE_BLIT_SRC,
          TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
          TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
        },
        textureFormat: TextureFormat.RGBA32F,
      );

      Logger.root.info("Created color texture for test render target");

      var width = await rtColorTexture.getWidth();
      var height = await rtColorTexture.getHeight();
      rtDepthTexture = await FilamentApp.instance!.createTexture(
        viewportDimensions.width,
        viewportDimensions.height,
        flags: {
          TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
          TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
          if (createStencilBuffer) TextureUsage.TEXTURE_USAGE_STENCIL_ATTACHMENT,
        },
        textureFormat: createStencilBuffer
            ? platformIsWindows
                  ? TextureFormat.DEPTH32F_STENCIL8
                  : TextureFormat.DEPTH24_STENCIL8
            : TextureFormat.DEPTH32F,
      );

      Logger.root.info("Created depth texture for test render target");

      renderTarget =
          await FilamentApp.instance!.createRenderTarget(
                viewportDimensions.width,
                viewportDimensions.height,
                color: rtColorTexture,
                depth: rtDepthTexture,
              )
              as FFIRenderTarget;
    }

    var viewer = ThermionViewerFFI(app: FilamentApp.instance as FFIFilamentApp);
    await viewer.initialized;
    await FilamentApp.instance!.renderManager.attach(viewer.view, swapChain);

    // Clean up all resources created by this helper when the viewer is
    // disposed. Without this, render targets / textures / cameras pile up
    // across sequential tests and blow the 10 MB WASM stack (the engine's
    // per-frame traversal scales with live object count).
    final rt = renderTarget;
    final ct = rtColorTexture;
    final dt = rtDepthTexture;
    viewer.onDispose(() async {
      if (rt != null) await (rt as FFIRenderTarget).destroy();
      if (ct != null) await ct.destroy();
      if (dt != null) await dt.destroy();
    });

    if (renderTarget != null) {
      await viewer.view.setRenderTarget(renderTarget);
    }
    await viewer.view.setViewport(viewportDimensions.width, viewportDimensions.height);

    if (createStencilBuffer) {
      await viewer.view.setStencilBufferEnabled(true);
    }

    if (addSkybox) {
      await viewer.loadSkybox("file://${assetsDir}/default_env_skybox.ktx");
    }

    if (bg != null) {
      await viewer.setBackgroundColor(bg.r.toDouble(), bg.g.toDouble(), bg.b.toDouble(), bg.a.toDouble());
    }

    final camera = await viewer.getActiveCamera();

    await camera.setLensProjection(
      near: kNear,
      far: kFar,
      aspect: viewportDimensions.width / viewportDimensions.height,
      focalLength: kFocalLength,
    );

    await camera.lookAt(cameraPosition);

    await viewer.setPostProcessing(postProcessing);

    await viewer.setToneMapper(await ToneMapper.aces(FilamentApp.instance! as FFIFilamentApp));
    return (viewer, swapChain);
  }

  Future withViewer(
    Future Function(ThermionViewer viewer) fn, {
    img.Color? bg,
    Vector3? cameraPosition,
    ({int width, int height}) viewportDimensions = (width: 512, height: 512),
    bool postProcessing = false,
    bool addSkybox = false,
    bool createRenderTarget = false,
    bool createStencilBuffer = false,
  }) async {
    final viewer = await createViewer(
      bg: bg,
      cameraPosition: cameraPosition,
      viewportDimensions: viewportDimensions,
      postProcessing: postProcessing,
      addSkybox: addSkybox,
      createRenderTarget: createRenderTarget,
      createStencilBuffer: createStencilBuffer,
    );

    await fn.call(viewer.$1);
    await viewer.$1.dispose();
    await FilamentApp.instance!.destroySwapChain(viewer.$2);
  }
}

class _CubeConfig {
  final Vector3? position;
  final Vector3? scale;
  final Quaternion? rotation;
  final bool castShadows;
  final bool receiveShadows;
  final Color? color;
  final bool createUbershader;
  final bool unlit;

  _CubeConfig({
    this.position,
    this.scale,
    this.rotation,
    this.castShadows = true,
    this.receiveShadows = true,
    this.color,
    this.createUbershader = false,
    this.unlit = false,
  });
}

class _PlaneConfig {
  final Vector3? position;
  final Vector3? scale;
  final Quaternion? rotation;
  final bool castShadows;
  final bool receiveShadows;
  final Color? color;
  final bool createUbershader;
  final bool unlit;

  _PlaneConfig({
    this.position,
    this.scale,
    this.rotation,
    this.castShadows = true,
    this.receiveShadows = true,
    this.color,
    this.createUbershader = false,
    this.unlit = false,
  });
}

/// Result class containing all components created by ViewerBuilder
class ViewerBuildResult {
  final ThermionViewer viewer;
  final List<ThermionAsset> assets;
  final ThermionEntity? sun;

  const ViewerBuildResult({required this.viewer, required this.assets, this.sun});
}

class ViewerBuilder {
  img.Color? _bg;
  Vector3? _cameraPosition;
  Vector3? _cameraLookAtPosition;
  Vector3? _cameraLookAtFocus;
  Vector3? _cameraLookAtUp;
  ({int width, int height}) _viewportDimensions = (width: 512, height: 512);
  bool _postProcessing = false;
  bool _addSkybox = false;
  bool _createRenderTarget = false;
  bool _createStencilBuffer = false;
  bool _shadowsEnabled = false;
  ShadowType? _shadowType;
  final List<DirectLight> _directLights = [];
  ToneMapper? _toneMapper;
  late TestHelper _testHelper;

  // Store cube and plane configurations
  final List<_CubeConfig> _cubes = [];
  final List<_PlaneConfig> _planes = [];

  // Store created light entities to enable finding sun lights later
  List<ThermionEntity>? _lightEntities;

  ViewerBuilder(
    this._testHelper, {
    img.Color? bg,
    Vector3? cameraPosition,
    ({int width, int height}) viewportDimensions = (width: 512, height: 512),
    bool postProcessing = false,
    bool addSkybox = false,
    bool createRenderTarget = false,
    bool createStencilBuffer = false,
  }) : _bg = bg,
       _cameraPosition = cameraPosition,
       _viewportDimensions = viewportDimensions,
       _postProcessing = postProcessing,
       _addSkybox = addSkybox,
       _createRenderTarget = createRenderTarget,
       _createStencilBuffer = createStencilBuffer;

  ViewerBuilder setBackgroundColor(img.Color color) {
    _bg = color;
    return this;
  }

  ViewerBuilder setCameraPosition(Vector3 position) {
    _cameraPosition = position;
    return this;
  }

  ViewerBuilder setCameraLookAt(Vector3 position, {Vector3? focus, Vector3? up}) {
    _cameraLookAtPosition = position;
    _cameraLookAtFocus = focus;
    _cameraLookAtUp = up;
    return this;
  }

  ViewerBuilder setViewportDimensions(int width, int height) {
    _viewportDimensions = (width: width, height: height);
    return this;
  }

  ViewerBuilder setPostProcessing(bool enabled) {
    _postProcessing = enabled;
    return this;
  }

  ViewerBuilder addSkybox({String? path}) {
    _addSkybox = true;
    if (path != null) {
      // Store custom skybox path if needed in the future
    }
    return this;
  }

  ViewerBuilder setRenderTargetEnabled(bool enabled) {
    _createRenderTarget = enabled;
    return this;
  }

  ViewerBuilder setStencilBufferEnabled(bool enabled) {
    _createStencilBuffer = enabled;
    return this;
  }

  ViewerBuilder setShadowsEnabled(bool enabled) {
    _shadowsEnabled = enabled;
    return this;
  }

  ViewerBuilder setShadowType(ShadowType type) {
    _shadowType = type;
    return this;
  }

  ViewerBuilder addDirectLight(DirectLight light) {
    _directLights.add(light);
    return this;
  }

  ViewerBuilder addSun({
    LinearColor? color,
    double? colorTemperature = 6500,
    double intensity = 100000,
    bool castShadows = true,
    Vector3? direction,
    double sunAngularRadius = 0.545,
    double sunHaloSize = 10.0,
    double sunHaloFalloff = 80.0,
  }) {
    _directLights.add(
      DirectLight.sun(
        color: color,
        colorTemperature: colorTemperature,
        intensity: intensity,
        castShadows: castShadows,
        direction: direction ?? Vector3(0.5, -0.5, -0.5).normalized(),
        sunAngularRadius: sunAngularRadius,
        sunHaloSize: sunHaloSize,
        sunHaloFalloff: sunHaloFalloff,
      ),
    );
    return this;
  }

  ViewerBuilder setToneMapping(ToneMapper mapper) {
    _toneMapper = mapper;
    return this;
  }

  ViewerBuilder addCube({
    Vector3? position,
    Vector3? scale,
    Quaternion? rotation,
    bool castShadows = true,
    bool receiveShadows = true,
    Color? color,
    bool createUbershader = false,
    bool unlit = false,
  }) {
    _cubes.add(
      _CubeConfig(
        position: position,
        scale: scale,
        rotation: rotation,
        castShadows: castShadows,
        receiveShadows: receiveShadows,
        color: color,
        createUbershader: createUbershader,
        unlit: unlit,
      ),
    );
    return this;
  }

  ViewerBuilder addPlane({
    Vector3? position,
    Vector3? scale,
    Quaternion? rotation,
    bool castShadows = true,
    bool receiveShadows = true,
    Color? color,
    bool createUbershader = false,
    bool unlit = false,
  }) {
    _planes.add(
      _PlaneConfig(
        position: position,
        scale: scale,
        rotation: rotation,
        castShadows: castShadows,
        receiveShadows: receiveShadows,
        color: color,
        createUbershader: createUbershader,
        unlit: unlit,
      ),
    );
    return this;
  }

  Future withCube(Future Function(ThermionAsset cube) fn) async {
    return await _testHelper.withViewer((viewer) async {
      var materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: true);
      await materialInstance.setParameterFloat4("baseColorFactor", 1, 1, 1, 0);

      final cubeGeometry = GeometryUtils.cube(flipUvs: true);
      var asset = await viewer.createGeometry(cubeGeometry, materialInstances: [materialInstance]);

      try {
        await fn(asset);
      } finally {
        await viewer.destroyAsset(asset);
      }
    });
  }

  Future<({ThermionViewer viewer, List<ThermionAsset> assets, SwapChain swapChain})> buildWithAssets() async {
    final viewerResult = await _testHelper.createViewer(
      bg: _bg,
      cameraPosition: _cameraPosition,
      viewportDimensions: _viewportDimensions,
      postProcessing: _postProcessing,
      addSkybox: _addSkybox,
      createRenderTarget: _createRenderTarget,
      createStencilBuffer: _createStencilBuffer,
    );
    final viewer = viewerResult.$1;

    final List<ThermionAsset> createdAssets = [];

    // Apply shadow settings
    if (_shadowsEnabled) {
      await viewer.setShadowsEnabled(true);
      if (_shadowType != null) {
        await viewer.setShadowType(_shadowType!);
      }
    }

    // Apply tone mapping if specified
    if (_toneMapper != null) {
      viewer.setToneMapper(_toneMapper!);
    }

    // Add direct lights and store their entities
    _lightEntities = [];
    for (final light in _directLights) {
      final lightEntity = await viewer.addDirectLight(light);
      _lightEntities!.add(lightEntity);
    }

    // Create and add configured planes
    for (final planeConfig in _planes) {
      final materialInstance = planeConfig.createUbershader
          ? await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: planeConfig.unlit)
          : await FilamentApp.instance!.createUnlitMaterialInstance();

      await materialInstance.setCullingMode(CullingMode.NONE);

      if (planeConfig.color != null) {
        await materialInstance.setParameterFloat4(
          "baseColorFactor",
          planeConfig.color!.r.toDouble(),
          planeConfig.color!.g.toDouble(),
          planeConfig.color!.b.toDouble(),
          planeConfig.color!.a.toDouble(),
        );
      } else {
        await materialInstance.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, 1.0);
      }

      final plane = await viewer.createGeometry(
        GeometryUtils.plane(normals: true, uvs: true, width: 10.0, height: 10.0),
        materialInstances: [materialInstance],
      );

      await plane.setCastShadows(planeConfig.castShadows);
      await plane.setReceiveShadows(planeConfig.receiveShadows);

      // Apply transform if specified
      if (planeConfig.position != null || planeConfig.scale != null || planeConfig.rotation != null) {
        final transform = Matrix4.compose(
          planeConfig.position ?? Vector3.zero(),
          planeConfig.rotation ?? Quaternion.identity(),
          planeConfig.scale ?? Vector3.all(1.0),
        );
        await FilamentApp.instance!.setTransform(plane.entity, transform);
      }

      await viewer.addToScene(plane);
      createdAssets.add(plane);
    }

    // Create and add configured cubes
    for (final cubeConfig in _cubes) {
      final materialInstance = cubeConfig.createUbershader
          ? await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: cubeConfig.unlit)
          : (cubeConfig.unlit ? await FilamentApp.instance!.createUnlitMaterialInstance() : null);

      if (materialInstance != null) {
        if (cubeConfig.color != null) {
          await materialInstance.setParameterFloat4(
            "baseColorFactor",
            cubeConfig.color!.r.toDouble(),
            cubeConfig.color!.g.toDouble(),
            cubeConfig.color!.b.toDouble(),
            cubeConfig.color!.a.toDouble(),
          );
        } else {
          await materialInstance.setParameterFloat4("baseColorFactor", 1.0, 0.0, 0.0, 1.0);
        }
      }

      final cube = await viewer.createGeometry(
        GeometryUtils.cube(flipUvs: true),
        materialInstances: materialInstance != null ? [materialInstance] : null,
      );

      await cube.setCastShadows(cubeConfig.castShadows);
      await cube.setReceiveShadows(cubeConfig.receiveShadows);

      // Apply transform if specified
      if (cubeConfig.position != null || cubeConfig.scale != null || cubeConfig.rotation != null) {
        final transform = Matrix4.compose(
          cubeConfig.position ?? Vector3.zero(),
          cubeConfig.rotation ?? Quaternion.identity(),
          cubeConfig.scale ?? Vector3.all(1.0),
        );
        await FilamentApp.instance!.setTransform(cube.entity, transform);
      }

      await viewer.addToScene(cube);
      createdAssets.add(cube);
    }

    // Apply camera lookAt if specified
    if (_cameraLookAtPosition != null) {
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(_cameraLookAtPosition!, focus: _cameraLookAtFocus, up: _cameraLookAtUp);
    }

    return (viewer: viewer, assets: createdAssets, swapChain: viewerResult.$2);
  }

  Future<ThermionViewer> build() async {
    final result = await buildWithAssets();
    return result.viewer;
  }

  Future execute(Future Function(ViewerBuildResult result) fn) async {
    final buildResult = await buildWithAssets();

    // Find the first sun light entity (if any)
    ThermionEntity? sunEntity;
    int sunLightIndex = _directLights.indexWhere(
      (light) => light.type == LightType.SUN || (light.type == LightType.DIRECTIONAL && light.sunAngularRadius > 0),
    );

    // If we found a sun light and have corresponding entities, get the matching
    // entity
    if (sunLightIndex != -1 && _lightEntities != null && sunLightIndex < _lightEntities!.length) {
      sunEntity = _lightEntities![sunLightIndex];
    }

    final viewerBuildResult = ViewerBuildResult(viewer: buildResult.viewer, assets: buildResult.assets, sun: sunEntity);

    try {
      await fn.call(viewerBuildResult);
    } finally {
      await buildResult.viewer.dispose();
      await FilamentApp.instance!.destroySwapChain(buildResult.swapChain);
    }
  }
}

Uint8List poissonBlend(List<Uint8List> textures, int width, int height) {
  final int numTextures = textures.length;
  final int size = width * height;

  // Initialize the result
  List<Vector4> result = List.generate(size, (_) => Vector4(0, 0, 0, 0));
  List<bool> validPixel = List.generate(size, (_) => false);

  // Compute gradients and perform simplified Poisson blending
  for (int y = 1; y < height - 1; y++) {
    for (int x = 1; x < width - 1; x++) {
      int index = y * width + x;
      Vector4 gradX = Vector4(0, 0, 0, 0);
      Vector4 gradY = Vector4(0, 0, 0, 0);
      bool hasValidData = false;

      for (int t = 0; t < numTextures; t++) {
        int i = index * 4;
        if (textures[t][i] == 0 && textures[t][i + 1] == 0 && textures[t][i + 2] == 0 && textures[t][i + 3] == 0) {
          continue; // Skip this texture if the pixel is empty
        }

        hasValidData = true;
        int iLeft = (y * width + x - 1) * 4;
        int iRight = (y * width + x + 1) * 4;
        int iUp = ((y - 1) * width + x) * 4;
        int iDown = ((y + 1) * width + x) * 4;

        Vector4 gx = Vector4(
          (textures[t][iRight] - textures[t][iLeft]) / 2,
          (textures[t][iRight + 1] - textures[t][iLeft + 1]) / 2,
          (textures[t][iRight + 2] - textures[t][iLeft + 2]) / 2,
          (textures[t][iRight + 3] - textures[t][iLeft + 3]) / 2,
        );

        Vector4 gy = Vector4(
          (textures[t][iDown] - textures[t][iUp]) / 2,
          (textures[t][iDown + 1] - textures[t][iUp + 1]) / 2,
          (textures[t][iDown + 2] - textures[t][iUp + 2]) / 2,
          (textures[t][iDown + 3] - textures[t][iUp + 3]) / 2,
        );

        // Select the gradient with larger magnitude
        double magX = gx.r * gx.r + gx.g * gx.g + gx.b * gx.b + gx.a * gx.a;
        double magY = gy.r * gy.r + gy.g * gy.g + gy.b * gy.b + gy.a * gy.a;

        if (magX > gradX.r * gradX.r + gradX.g * gradX.g + gradX.b * gradX.b + gradX.a * gradX.a) {
          gradX = gx;
        }
        if (magY > gradY.r * gradY.r + gradY.g * gradY.g + gradY.b * gradY.b + gradY.a * gradY.a) {
          gradY = gy;
        }
      }

      if (hasValidData) {
        validPixel[index] = true;
        // Simplified Poisson equation solver (Jacobi iteration)
        result[index].r =
            (result[index - 1].r +
                result[index + 1].r +
                result[index - width].r +
                result[index + width].r +
                gradX.r -
                gradY.r) /
            4;
        result[index].g =
            (result[index - 1].g +
                result[index + 1].g +
                result[index - width].g +
                result[index + width].g +
                gradX.g -
                gradY.g) /
            4;
        result[index].b =
            (result[index - 1].b +
                result[index + 1].b +
                result[index - width].b +
                result[index + width].b +
                gradX.b -
                gradY.b) /
            4;
        result[index].a =
            (result[index - 1].a +
                result[index + 1].a +
                result[index - width].a +
                result[index + width].a +
                gradX.a -
                gradY.a) /
            4;
      }
    }
  }

  // Fill in gaps and normalize
  Uint8List finalResult = Uint8List(size * 4);
  for (int i = 0; i < size; i++) {
    if (validPixel[i]) {
      finalResult[i * 4] = (result[i].r.clamp(0, 255)).toInt();
      finalResult[i * 4 + 1] = (result[i].g.clamp(0, 255)).toInt();
      finalResult[i * 4 + 2] = (result[i].b.clamp(0, 255)).toInt();
      finalResult[i * 4 + 3] = (result[i].a.clamp(0, 255)).toInt();
    } else {
      // For invalid pixels, try to interpolate from neighbors
      List<int> validNeighbors = [];
      if (i > width && validPixel[i - width]) validNeighbors.add(i - width);
      if (i < size - width && validPixel[i + width]) validNeighbors.add(i + width);
      if (i % width > 0 && validPixel[i - 1]) validNeighbors.add(i - 1);
      if (i % width < width - 1 && validPixel[i + 1]) validNeighbors.add(i + 1);

      if (validNeighbors.isNotEmpty) {
        double r = 0, g = 0, b = 0, a = 0;
        for (int neighbor in validNeighbors) {
          r += result[neighbor].r;
          g += result[neighbor].g;
          b += result[neighbor].b;
          a += result[neighbor].a;
        }
        finalResult[i * 4] = (r / validNeighbors.length).clamp(0, 255).toInt();
        finalResult[i * 4 + 1] = (g / validNeighbors.length).clamp(0, 255).toInt();
        finalResult[i * 4 + 2] = (b / validNeighbors.length).clamp(0, 255).toInt();
        finalResult[i * 4 + 3] = (a / validNeighbors.length).clamp(0, 255).toInt();
      } else {
        // If no valid neighbors, set to transparent black
        finalResult[i * 4] = 0;
        finalResult[i * 4 + 1] = 0;
        finalResult[i * 4 + 2] = 0;
        finalResult[i * 4 + 3] = 0;
      }
    }
  }

  return finalResult;
}

Uint8List medianImages(List<Uint8List> images) {
  if (images.isEmpty) {
    return Uint8List(0);
  }

  int imageSize = images[0].length;
  Uint8List result = Uint8List(imageSize);
  int numImages = images.length;

  for (int i = 0; i < imageSize; i++) {
    List<int> pixelValues = [];
    for (int j = 0; j < numImages; j++) {
      pixelValues.add(images[j][i]);
    }

    pixelValues.sort();
    int medianIndex = numImages ~/ 2;
    result[i] = pixelValues[medianIndex];
  }

  return result;
}

Uint8List maxIntensityProjection(List<Uint8List> textures, int width, int height) {
  final int numTextures = textures.length;
  final int size = width * height;

  // Initialize the result with the first texture
  Uint8List result = Uint8List.fromList(textures[0]);

  // Iterate through all textures and perform max intensity projection
  for (int t = 1; t < numTextures; t++) {
    for (int i = 0; i < size * 4; i += 4) {
      // Calculate intensity (using luminance formula)
      double intensityCurrent = 0.299 * result[i] + 0.587 * result[i + 1] + 0.114 * result[i + 2];
      double intensityNew = 0.299 * textures[t][i] + 0.587 * textures[t][i + 1] + 0.114 * textures[t][i + 2];

      // If the new texture has higher intensity, use its values
      if (intensityNew > intensityCurrent) {
        result[i] = textures[t][i]; // R
        result[i + 1] = textures[t][i + 1]; // G
        result[i + 2] = textures[t][i + 2]; // B
        result[i + 3] = textures[t][i + 3]; // A
      }
    }
  }

  return result;
}

// Helper function to blend MIP result with Poisson blending
Uint8List blendMIPWithPoisson(Uint8List mipResult, Uint8List poissonResult, double alpha) {
  final int size = mipResult.length;
  Uint8List blendedResult = Uint8List(size);

  for (int i = 0; i < size; i++) {
    blendedResult[i] = (mipResult[i] * (1 - alpha) + poissonResult[i] * alpha).round().clamp(0, 255);
  }

  return blendedResult;
}

Uint8List medianBlending(List<Uint8List> textures, int width, int height) {
  final int numTextures = textures.length;
  final int size = width * height;

  Uint8List result = Uint8List(size * 4);

  for (int i = 0; i < size; i++) {
    List<int> values = [];
    for (int t = 0; t < numTextures; t++) {
      if (textures[t][i * 4] != 0 ||
          textures[t][i * 4 + 1] != 0 ||
          textures[t][i * 4 + 2] != 0 ||
          textures[t][i * 4 + 3] != 0) {
        values.addAll(textures[t].sublist(i * 4, i * 4 + 4));
      }
    }

    if (values.isNotEmpty) {
      values.sort();
      result[i] = values[values.length ~/ 2];
    } else {
      result[i] = 0; // If no valid data, set to transparent
    }
  }

  return result;
}

(Uint8List, int, int) readBmpToPixelBuffer(String filePath) {
  // Read the file bytes
  final Uint8List fileBytes = readFileBytesSync(filePath);

  // Decode the image using package:image
  final img.Image? decodedImage = img.decodeImage(fileBytes);

  if (decodedImage == null) {
    throw FormatException('Failed to decode image at $filePath');
  }

  // Convert to RGBA format (matching the format used in the comparison function)
  final img.Image rgbaImage = decodedImage.convert(format: img.Format.uint8, numChannels: 3);

  rgbaImage.remapChannels(ChannelOrder.bgr);

  // Get dimensions
  final int width = rgbaImage.width;
  final int height = rgbaImage.height;

  // Convert to Uint8List
  final Uint8List pixelBuffer = Uint8List.fromList(rgbaImage.toUint8List());

  if (pixelBuffer.length != width * height * 3) {
    throw Exception("MISMATCH");
  }

  return (pixelBuffer, width, height);
}

Uint8List comparePixelBuffers(Uint8List buffer1, Uint8List buffer2, int width, int height, {int threshold = 0}) {
  // Validate inputs
  if (buffer1.length != buffer2.length) {
    throw ArgumentError('Buffer sizes do not match: ${buffer1.length} vs ${buffer2.length}');
  }

  if (buffer1.length < width * height * 3) {
    throw ArgumentError('Buffer size is too small for the specified dimensions');
  }

  // Create result buffer
  final Uint8List result = Uint8List(buffer1.length);

  // Process each pixel
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int index = (y * width + x) * 3;

      if (buffer1[index + 2] != 0) {
        Logger.root.info("buffer 1 red ${buffer1[index + 2]} buffer 2 ${buffer2[index + 2]}");
      }

      // Compare RGB values
      final bool isDifferent =
          (buffer1[index] - buffer2[index]).abs() > threshold ||
          (buffer1[index + 1] - buffer2[index + 1]).abs() > threshold ||
          (buffer1[index + 2] - buffer2[index + 2]).abs() > threshold;

      if (isDifferent) {
        // result[index] = (buffer1[index] - buffer2[index]).abs(); // R
        // result[index + 1] = (buffer1[index + 1] - buffer2[index + 1]).abs(); //G
        // result[index + 2] = (buffer1[index + 2] - buffer2[index + 2]).abs(); //

        // Different pixels - white
        result[index] = 255; // R
        result[index + 1] = 255; // G
        result[index + 2] = 255; // B
      }
    }
  }

  return result;
}
