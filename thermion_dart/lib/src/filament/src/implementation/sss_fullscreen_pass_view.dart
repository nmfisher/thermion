import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

/// Everything one fullscreen pass needs, built once by
/// [SssFullscreenPassView.buildResources] and handed to the concrete subclass.
class _SssPassResources {
  final FFIMaterial material;
  final FFIMaterialInstance materialInstance;
  final FFIVertexBuffer vertexBuffer;
  final FFIIndexBuffer indexBuffer;
  final ThermionEntity quadEntity;
  final FFIScene scene;
  final Skybox skybox;
  final Camera camera;
  final FFITextureSampler sampler;

  _SssPassResources({
    required this.material,
    required this.materialInstance,
    required this.vertexBuffer,
    required this.indexBuffer,
    required this.quadEntity,
    required this.scene,
    required this.skybox,
    required this.camera,
    required this.sampler,
  });
}

/// Common scaffolding for the screen-space subsurface scattering fullscreen
/// passes ([SssBlurView] and [SssCompositeView]).
///
/// A pass is a [View] whose scene contains nothing but one oversized triangle.
/// The triangle is drawn with an orthographic camera covering clip space, so
/// the material's `screenUV` variable sweeps [0,1] exactly once across the
/// output and the fragment shader runs once per output pixel. This is the same
/// construction used by [EdgeDetectionView].
///
/// Filament exposes no public hook for post-processing (see
/// docs/screen-space-subsurface-scattering.md), so a pass has to be a real
/// [View] that the RenderManager submits in order, writing to its own render
/// target.
abstract class SssFullscreenPassView extends FFIView {
  final FFIFilamentApp app;
  final FFIMaterial material;
  final FFIMaterialInstance materialInstance;
  final FFIVertexBuffer quadVertexBuffer;
  final FFIIndexBuffer quadIndexBuffer;
  final ThermionEntity quadEntity;
  final Scene passScene;
  final Skybox skybox;
  final Camera passCamera;

  /// Sampler used for every texture this pass reads.
  final FFITextureSampler sampler;

  SssFullscreenPassView._(
    Pointer<TView> view, {
    required this.app,
    required _SssPassResources resources,
  }) : material = resources.material,
       materialInstance = resources.materialInstance,
       quadVertexBuffer = resources.vertexBuffer,
       quadIndexBuffer = resources.indexBuffer,
       quadEntity = resources.quadEntity,
       passScene = resources.scene,
       skybox = resources.skybox,
       passCamera = resources.camera,
       sampler = resources.sampler,
       super(view, app);

  /// Builds the parts every fullscreen pass shares.
  ///
  /// [material] is the already-created material for this pass; each pass has
  /// its own so that its material instance can be configured independently.
  static Future<_SssPassResources> buildResources(
    FFIFilamentApp app,
    FFIMaterial material,
  ) async {
    final scene = await app.createScene() as FFIScene;

    // Fully transparent skybox: the quad covers the whole output, so the
    // skybox only ever has to define a clear value and must not contribute
    // colour of its own.
    final skybox = await app.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 0.0);
    await scene.setSkybox(skybox);

    final camera = await app.createCamera();
    await camera.setProjection(
      Projection.Orthographic,
      -1.0,
      1.0, // left, right
      -1.0,
      1.0, // bottom, top
      0.0,
      1.0, // near, far
    );

    // One oversized triangle covers clip space. z=0.5 places it in the middle
    // of the ortho frustum above.
    final positions = Float32List.fromList([-1.0, -1.0, 0.5, 3.0, -1.0, 0.5, -1.0, 3.0, 0.5]);

    final vbBuilder = app.renderableManager.createVertexBufferBuilder();
    vbBuilder.vertexCount(3);
    vbBuilder.bufferCount(1);
    vbBuilder.attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3, byteOffset: 0, byteStride: 12);
    final vertexBuffer = await vbBuilder.build() as FFIVertexBuffer;
    await vertexBuffer.setBufferAt(0, positions);

    final ibBuilder = app.renderableManager.createIndexBufferBuilder();
    ibBuilder.indexCount(3);
    ibBuilder.bufferType(IndexType.USHORT);
    final indexBuffer = await ibBuilder.build() as FFIIndexBuffer;
    await indexBuffer.setBuffer(Uint16List.fromList([0, 1, 2]));

    final materialInstance = await material.createInstance() as FFIMaterialInstance;

    // LINEAR: the blur passes need filtered reads, and the composite pass
    // relies on filtered reads of the reduced-resolution scatter buffer to
    // upsample it.
    final sampler = await app.createTextureSampler(
      minFilter: TextureMinFilter.LINEAR,
      magFilter: TextureMagFilter.LINEAR,
      wrapS: TextureWrapMode.CLAMP_TO_EDGE,
      wrapT: TextureWrapMode.CLAMP_TO_EDGE,
    ) as FFITextureSampler;

    final quadEntity = await app.createEntity();

    final builder = app.renderableManager.createBuilder(1);
    builder.boundingBox(Aabb3.minMax(Vector3(-2, -2, 0), Vector3(4, 4, 1)));
    builder.geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 3);
    builder.material(0, materialInstance);
    builder.culling(false);
    builder.receiveShadows(false);
    builder.castShadows(false);
    await builder.build(quadEntity);

    await scene.addEntity(quadEntity);

    return _SssPassResources(
      material: material,
      materialInstance: materialInstance,
      vertexBuffer: vertexBuffer,
      indexBuffer: indexBuffer,
      quadEntity: quadEntity,
      scene: scene,
      skybox: skybox,
      camera: camera,
      sampler: sampler,
    );
  }

  /// Applies the pass-independent view configuration.
  ///
  /// Post-processing is off: the pass output is a raw colour buffer that the
  /// next pass reads back, so tonemapping, bloom and anti-aliasing would
  /// corrupt it.
  Future<void> configure(int width, int height) async {
    await setScene(passScene);
    await super.setCamera(passCamera);
    await setViewport(width, height);
    await setPostProcessingInternal(false);
    await setShadowsEnabled(false);
    await setFrustumCullingEnabled(false);
    await setBlendMode(BlendMode.opaque);
  }

  @override
  Future setCamera(Camera? camera) {
    throw UnsupportedError("Not supported for subsurface scattering pass views");
  }

  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) {
    throw UnsupportedError("Not supported for subsurface scattering pass views");
  }

  @override
  Future setPostProcessing(bool enabled) {
    throw UnsupportedError("Not supported for subsurface scattering pass views");
  }

  /// Internal: sets post-processing without the guard above.
  Future<void> setPostProcessingInternal(bool enabled) {
    return super.setPostProcessing(enabled);
  }

  @override
  Future removeStencilHighlight(ThermionAsset asset) {
    throw UnsupportedError("Not supported for subsurface scattering pass views");
  }

  @override
  Future setStencilHighlight(
    ThermionAsset asset, {
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
    int? entity,
    double scale = 1.05,
    double outlineWidth = 3.0,
    int primitiveIndex = 0,
    ThermionAsset? geometrySource,
  }) {
    throw UnsupportedError("Not supported for subsurface scattering pass views");
  }

  @override
  Future<void> destroy() async {
    await super.setRenderTarget(null);
    await super.setCamera(null);

    View_setScene(this.getNativeHandle(), nullptr);

    await passScene.removeEntity(quadEntity);
    await app.destroyEntity(quadEntity);

    await materialInstance.destroy();
    await quadVertexBuffer.destroy();
    await quadIndexBuffer.destroy();

    await passScene.setSkybox(null);
    await skybox.destroy();
    await (passScene as FFIScene).destroy();

    await material.destroy();
    await passCamera.destroy();

    await super.destroy();
  }
}

/// One direction of the separable, depth-aware, chromatic subsurface blur.
///
/// Both directions use this class; `direction` distinguishes them. The input
/// colour buffer differs per pass too: the horizontal pass reads the main
/// scene colour, the vertical pass reads the horizontal pass' output.
class SssBlurView extends SssFullscreenPassView {
  SssBlurView._(Pointer<TView> view, {required FFIFilamentApp app, required _SssPassResources resources})
    : super._(view, app: app, resources: resources);

  static Future<SssBlurView> create(FFIFilamentApp app, {required int width, required int height}) async {
    final viewPtr = await withPointerCallback<TView>((cb) => Engine_createViewRenderThread(app.engine, cb));

    final materialPtr = await withPointerCallback<TMaterial>(
      (cb) => Material_createSssBlurMaterialRenderThread(app.engine, cb),
    );
    final material = FFIMaterial(materialPtr, app);

    final resources = await SssFullscreenPassView.buildResources(app, material);
    final blurView = SssBlurView._(viewPtr, app: app, resources: resources);
    await blurView.configure(width, height);
    await blurView.setName("sss_blur");
    return blurView;
  }

  Future<void> setParameters({
    required Texture colorTexture,
    required Texture depthTexture,
    required Texture maskTexture,
    required double directionX,
    required double directionY,
    required double texelSizeX,
    required double texelSizeY,
    required List<double> scatterRadius,
    required double depthFalloff,
    required List<double> depthRange,
    required bool orthographic,
    required bool useDepth,
    required bool useMask,
  }) async {
    await materialInstance.setParameterTexture('color', colorTexture as FFITexture, sampler);
    await materialInstance.setParameterTexture('depth', depthTexture as FFITexture, sampler);
    await materialInstance.setParameterTexture('mask', maskTexture as FFITexture, sampler);
    await materialInstance.setParameterFloat2('direction', directionX, directionY);
    await materialInstance.setParameterFloat2('texelSize', texelSizeX, texelSizeY);
    await materialInstance.setParameterFloat3('scatterRadius', scatterRadius[0], scatterRadius[1], scatterRadius[2]);
    await materialInstance.setParameterFloat('depthFalloff', depthFalloff);
    await materialInstance.setParameterFloat2('depthRange', depthRange[0], depthRange[1]);
    await materialInstance.setParameterInt('orthographic', orthographic ? 1 : 0);
    await materialInstance.setParameterInt('useDepth', useDepth ? 1 : 0);
    await materialInstance.setParameterInt('useMask', useMask ? 1 : 0);
  }
}

/// Mixes the scattered radiance back over the un-scattered scene colour.
class SssCompositeView extends SssFullscreenPassView {
  SssCompositeView._(Pointer<TView> view, {required FFIFilamentApp app, required _SssPassResources resources})
    : super._(view, app: app, resources: resources);

  static Future<SssCompositeView> create(FFIFilamentApp app, {required int width, required int height}) async {
    final viewPtr = await withPointerCallback<TView>((cb) => Engine_createViewRenderThread(app.engine, cb));

    final materialPtr = await withPointerCallback<TMaterial>(
      (cb) => Material_createSssCompositeMaterialRenderThread(app.engine, cb),
    );
    final material = FFIMaterial(materialPtr, app);

    final resources = await SssFullscreenPassView.buildResources(app, material);
    final compositeView = SssCompositeView._(viewPtr, app: app, resources: resources);
    await compositeView.configure(width, height);
    await compositeView.setName("sss_composite");
    return compositeView;
  }

  Future<void> setParameters({
    required Texture sceneColorTexture,
    required Texture scatteredTexture,
    required Texture maskTexture,
    required double intensity,
  }) async {
    await materialInstance.setParameterTexture('sceneColor', sceneColorTexture as FFITexture, sampler);
    await materialInstance.setParameterTexture('scattered', scatteredTexture as FFITexture, sampler);
    await materialInstance.setParameterTexture('mask', maskTexture as FFITexture, sampler);
    await materialInstance.setParameterFloat('intensity', intensity);
  }
}
