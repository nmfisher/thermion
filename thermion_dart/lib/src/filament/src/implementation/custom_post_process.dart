// CustomPostProcess — a reusable fullscreen post-process view.
//
// Redirects the main scene view into a render target (RT1: colour + depth),
// then runs a fullscreen triangle with a caller-supplied material that samples
// RT1's textures. The pp view renders to its own render target (RT2).
//
// Material contract: the material must declare
//   sampler2d tDiffuse ; sampler2d tDepth ; float2 texelSize

import 'package:thermion_dart/src/filament/src/implementation/ffi_color_grading.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'ffi_filament_app.dart';

/// A fullscreen post-process view that redirects [mainView] into sampleable
/// color and depth textures, then renders a caller-supplied material.
///
/// The material must declare tDiffuse, tDepth, and texelSize. The caller
/// retains ownership of the material and material instance.
class CustomPostProcess extends FFIView {
  final FFIFilamentApp _app;
  final View _mainView;
  final FFIMaterialInstance _materialInstance;
  final Scene _scene;
  final Skybox _skybox;
  final Camera _camera;
  final ThermionEntity _quadEntity;
  final FFIVertexBuffer _quadVB;
  final FFIIndexBuffer _quadIB;
  final FFITextureSampler _colorSampler;
  final FFITextureSampler _depthSampler;
  final ColorGrading _linearColorGrading;
  final ToneMapper _linearToneMapper;
  final RenderTarget? _outputRT;

  FFIRenderTarget? _sceneRT;
  FFIRenderTarget? _ppRT;
  FFITexture? _sceneColor;
  FFITexture? _sceneDepth;
  FFITexture? _ppColor;
  FFITexture? _ppDepth;

  CustomPostProcess._(
    Pointer<TView> view, {
    required FFIFilamentApp app,
    required View mainView,
    required FFIMaterialInstance materialInstance,
    required Scene scene,
    required Skybox skybox,
    required Camera camera,
    required ThermionEntity quadEntity,
    required FFIVertexBuffer quadVB,
    required FFIIndexBuffer quadIB,
    required FFITextureSampler colorSampler,
    required FFITextureSampler depthSampler,
    required ColorGrading linearColorGrading,
    required ToneMapper linearToneMapper,
    required RenderTarget? outputRT,
    required FFIRenderTarget? sceneRT,
    required FFIRenderTarget? ppRT,
    required FFITexture? sceneColor,
    required FFITexture? sceneDepth,
    required FFITexture? ppColor,
    required FFITexture? ppDepth,
  }) : _app = app,
       _mainView = mainView,
       _materialInstance = materialInstance,
       _scene = scene,
       _skybox = skybox,
       _camera = camera,
       _quadEntity = quadEntity,
       _quadVB = quadVB,
       _quadIB = quadIB,
       _colorSampler = colorSampler,
       _depthSampler = depthSampler,
       _linearColorGrading = linearColorGrading,
       _linearToneMapper = linearToneMapper,
       _outputRT = outputRT,
       _sceneRT = sceneRT,
       _ppRT = ppRT,
       _sceneColor = sceneColor,
       _sceneDepth = sceneDepth,
       _ppColor = ppColor,
       _ppDepth = ppDepth,
       super(view, app);

  /// Creates a post-process at [width] by [height].
  ///
  /// When [redirectMain] is true, [mainView] is redirected to an internal HDR
  /// target. Call [resize] when the output dimensions change.
  static Future<CustomPostProcess> create(
    FilamentApp app, {
    required View mainView,
    required MaterialInstance materialInstance,
    required int width,
    required int height,
    bool redirectMain = true,
  }) async {
    if (app is! FFIFilamentApp) {
      throw UnsupportedError('CustomPostProcess currently supports the FFI backend only');
    }
    if (materialInstance is! FFIMaterialInstance) {
      throw UnsupportedError('CustomPostProcess requires an FFI material instance');
    }

    // Preserve a platform-provided output target (for example Flutter's
    // texture). The scene is redirected to RT1 and the post view takes over
    // the original target, so callers do not need a separate compositing path.
    final outputRT = await mainView.getRenderTarget();

    // RT1: the scene renders here (sampleable colour RGBA32F + depth).
    FFIRenderTarget? sceneRT;
    FFITexture? sceneColor;
    FFITexture? sceneDepth;
    if (redirectMain) {
      sceneColor =
          await app.createTexture(
                width,
                height,
                flags: {
                  TextureUsage.TEXTURE_USAGE_BLIT_SRC,
                  TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
                  TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
                },
                textureFormat: TextureFormat.RGBA32F,
              )
              as FFITexture;
      sceneDepth =
          await app.createTexture(
                width,
                height,
                flags: {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
                textureFormat: TextureFormat.DEPTH32F,
              )
              as FFITexture;
      sceneRT = await app.createRenderTarget(width, height, color: sceneColor, depth: sceneDepth) as FFIRenderTarget;
    }
    if (redirectMain) await mainView.setRenderTarget(sceneRT!);

    // PP view.
    final baseView = await app.createView();
    final viewPtr = baseView.getNativeHandle();
    final scene = await app.createScene();
    final skybox = await app.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 0.0);
    await scene.setSkybox(skybox);
    final camera = await app.createCamera();
    await camera.setProjection(Projection.Orthographic, -1, 1, -1, 1, 0.0, 1.0);

    // Fullscreen triangle. Build this directly instead of going through
    // SceneAsset: this renderable has no glTF transform hierarchy and must
    // remain visible despite its deliberately oversized clip-space bounds.
    // This is the same proven path used by EdgeDetectionView.
    final positions = Float32List.fromList([-1, -1, 0.5, 3, -1, 0.5, -1, 3, 0.5]);
    final vbBuilder = app.renderableManager.createVertexBufferBuilder();
    vbBuilder.vertexCount(3);
    vbBuilder.bufferCount(1);
    vbBuilder.attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3, byteOffset: 0, byteStride: 12);
    final quadVB = await vbBuilder.build() as FFIVertexBuffer;
    await quadVB.setBufferAt(0, positions);

    final indices = Uint16List.fromList([0, 1, 2]);
    final ibBuilder = app.renderableManager.createIndexBufferBuilder();
    ibBuilder.indexCount(3);
    ibBuilder.bufferType(IndexType.USHORT);
    final quadIB = await ibBuilder.build() as FFIIndexBuffer;
    await quadIB.setBuffer(indices);

    final quadEntity = await app.createEntity();
    final renderableBuilder = app.renderableManager.createBuilder(1);
    renderableBuilder.boundingBox(Aabb3.minMax(Vector3(-2, -2, 0), Vector3(4, 4, 1)));
    renderableBuilder.geometry(0, PrimitiveType.TRIANGLES, quadVB, quadIB, 0, 3);
    renderableBuilder.material(0, materialInstance);
    renderableBuilder.culling(false);
    renderableBuilder.receiveShadows(false);
    renderableBuilder.castShadows(false);
    if (!await renderableBuilder.build(quadEntity) || !app.renderableManager.hasComponent(quadEntity)) {
      throw StateError('Failed to build custom post-process renderable');
    }
    await scene.addEntity(quadEntity);

    // Samplers for the RT textures.
    final colorSampler =
        await app.createTextureSampler(
              minFilter: TextureMinFilter.NEAREST,
              magFilter: TextureMagFilter.NEAREST,
              wrapS: TextureWrapMode.CLAMP_TO_EDGE,
              wrapT: TextureWrapMode.CLAMP_TO_EDGE,
            )
            as FFITextureSampler;
    final depthSampler =
        await app.createTextureSampler(
              minFilter: TextureMinFilter.NEAREST,
              magFilter: TextureMagFilter.NEAREST,
              wrapS: TextureWrapMode.CLAMP_TO_EDGE,
              wrapT: TextureWrapMode.CLAMP_TO_EDGE,
            )
            as FFITextureSampler;

    // RT2: the pp view's output target (RGBA32F for HDR post-process).
    FFIRenderTarget? ppRT;
    FFITexture? ppColor;
    FFITexture? ppDepth;
    if (outputRT == null) {
      ppColor =
          await app.createTexture(
                width,
                height,
                flags: {
                  TextureUsage.TEXTURE_USAGE_BLIT_SRC,
                  TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
                  TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
                },
                textureFormat: TextureFormat.RGBA32F,
              )
              as FFITexture;
      ppDepth =
          await app.createTexture(
                width,
                height,
                flags: {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
                textureFormat: TextureFormat.DEPTH32F,
              )
              as FFITexture;
      ppRT = await app.createRenderTarget(width, height, color: ppColor, depth: ppDepth) as FFIRenderTarget;
    }

    // Linear tone mapper + grading (no double tonemap).
    final linTM = await ToneMapper.linear(app);
    final cgb = FFIColorGradingBuilder(
      await withPointerCallback<TColorGradingBuilder>((cb) => ColorGradingBuilder_createRenderThread(cb)),
      app,
    );
    cgb.toneMapper(linTM);
    final linCG = await cgb.build();
    await cgb.dispose();

    final pp = CustomPostProcess._(
      viewPtr,
      app: app,
      mainView: mainView,
      materialInstance: materialInstance,
      scene: scene,
      skybox: skybox,
      camera: camera,
      quadEntity: quadEntity,
      quadVB: quadVB,
      quadIB: quadIB,
      colorSampler: colorSampler,
      depthSampler: depthSampler,
      linearColorGrading: linCG,
      linearToneMapper: linTM,
      outputRT: outputRT,
      sceneRT: sceneRT,
      ppRT: ppRT,
      sceneColor: sceneColor,
      sceneDepth: sceneDepth,
      ppColor: ppColor,
      ppDepth: ppDepth,
    );

    await pp.setCamera(camera);
    await pp.setScene(scene);
    await pp.setRenderTarget(outputRT ?? ppRT);
    await pp.setViewport(width, height);
    await pp.setColorGrading(linCG);
    await pp.setPostProcessing(false);
    await pp.setFrustumCullingEnabled(false);
    await pp.setBlendMode(BlendMode.transparent);

    // Bind RT1's textures into the material.
    if (sceneRT != null) {
      await materialInstance.setParameterTexture('tDiffuse', sceneColor!, colorSampler);
      await materialInstance.setParameterTexture('tDepth', sceneDepth!, depthSampler);
      await materialInstance.setParameterFloat2('texelSize', 1.0 / width, 1.0 / height);
    }
    return pp;
  }

  Future<void> resize(int width, int height) async {
    final sceneColor =
        await _app.createTexture(
              width,
              height,
              flags: {
                TextureUsage.TEXTURE_USAGE_BLIT_SRC,
                TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
                TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
              },
              textureFormat: TextureFormat.RGBA32F,
            )
            as FFITexture;
    final sceneDepth =
        await _app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
              textureFormat: TextureFormat.DEPTH32F,
            )
            as FFITexture;
    final sceneRT =
        await _app.createRenderTarget(width, height, color: sceneColor, depth: sceneDepth) as FFIRenderTarget;
    await _materialInstance.setParameterTexture('tDiffuse', sceneColor, _colorSampler);
    await _materialInstance.setParameterTexture('tDepth', sceneDepth, _depthSampler);
    await _materialInstance.setParameterFloat2('texelSize', 1.0 / width, 1.0 / height);
    await _mainView.setRenderTarget(sceneRT);
    await _mainView.setViewport(width, height);
    await _sceneRT?.destroy();
    await _sceneColor?.destroy();
    await _sceneDepth?.destroy();
    _sceneRT = sceneRT;
    _sceneColor = sceneColor;
    _sceneDepth = sceneDepth;

    if (_outputRT == null) {
      final ppColor =
          await _app.createTexture(
                width,
                height,
                flags: {
                  TextureUsage.TEXTURE_USAGE_BLIT_SRC,
                  TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
                  TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
                },
                textureFormat: TextureFormat.RGBA32F,
              )
              as FFITexture;
      final ppDepth =
          await _app.createTexture(
                width,
                height,
                flags: {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
                textureFormat: TextureFormat.DEPTH32F,
              )
              as FFITexture;
      final ppRT = await _app.createRenderTarget(width, height, color: ppColor, depth: ppDepth) as FFIRenderTarget;
      await setRenderTarget(ppRT);
      await _ppRT?.destroy();
      await _ppColor?.destroy();
      await _ppDepth?.destroy();
      _ppRT = ppRT;
      _ppColor = ppColor;
      _ppDepth = ppDepth;
    } else {
      await setRenderTarget(_outputRT);
    }
    await setViewport(width, height);
  }

  @override
  Future<void> destroy() async {
    await setRenderTarget(null);
    await _mainView.setRenderTarget(_outputRT);
    await setCamera(null);
    await _scene.removeEntity(_quadEntity);
    await _app.destroyEntity(_quadEntity);
    await _quadVB.destroy();
    await _quadIB.destroy();
    await _scene.setSkybox(null);
    await _skybox.destroy();
    await (_scene as FFIScene).destroy();
    await setColorGrading(null);
    await (_linearColorGrading as FFIColorGrading).dispose();
    await _linearToneMapper.dispose();
    await _camera.destroy();
    await _sceneRT?.destroy();
    await _ppRT?.destroy();
    await _sceneColor?.destroy();
    await _sceneDepth?.destroy();
    await _ppColor?.destroy();
    await _ppDepth?.destroy();
    super.destroy();
  }
}
