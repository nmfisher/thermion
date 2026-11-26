// MuTracer sidecar: path-traces the mirrored Thermion scene on Thermion's own
// browser GPUDevice, composites the result over Thermion's offscreen
// (present-skip) output, and presents the composite on the viewer canvas.
//
// Shared-device import: the engine publishes its GPUDevice on
// Module['thermionWebGPUDevice'] (Thermion_exportWebGPUDevice, which resolves
// the WGPUDevice handle through Emscripten's WebGPU.getJsObject). MuTracer
// takes caller-owned devices via EngineParams.device; internally Emscripten's
// WebGPU.importJsDevice is exactly this JS-object -> handle direction, so
// both engines submit to the same GPUDevice and queues.
//
// The Dart side (web/main.dart) describes its static scene once as JSON on
// window.thermionSidecarScene and fires 'thermion-sidecar-ready'. This module
// mirrors that description into @meimu/mutracer, commits it with a single
// Engine.update() (the scene never changes afterwards, so the static BLAS is
// built exactly once), then accumulates path-traced samples every frame.
//
// Compositing: every frame (after Thermion rendered) the hidden offscreen
// canvas' current swapchain texture is copied into a sampleable texture on
// the shared queue; Display.addPostProcess registers a pass that runs inside
// engine.display.present() on the same device and blends the path-traced
// image over that copy. present() then draws the blended image to the visible
// canvas — Thermion itself never presents (its swapchain is skipPresent).
import {
  Engine,
  Render,
  Camera,
  Mesh,
  Geometry,
  GeometryAttribute as Attribute,
  OpenPBRMaterial,
  DirectionalLight,
} from '@meimu/mutracer';

const statusEl = document.getElementById('status');
const setStatus = (text) => { if (statusEl) statusEl.textContent = text; };
const fail = (message) => {
  setStatus(message);
  throw new Error(message);
};

// Sidecar-tunable parameters (URL query):
//   ?samples=N   path-traced samples to accumulate (default 256)
//   ?blend=F     0..1 weight of the path-traced image over Thermion's (0.85)
//   ?exposure=E  linear exposure for the path-traced image (1)
const query = new URLSearchParams(window.location.search);
const maxSamples = Math.max(1, Number(query.get('samples')) || 256);
const blend = Math.min(1, Math.max(0, Number(query.get('blend') ?? 0.85)));
const exposure = Number(query.get('exposure')) || 1;

// --- Scene mirror -----------------------------------------------------------
// Vertex data identical to Thermion's GeometryUtils.cube() / plane(12, 12),
// so both renderers trace/rasterize the same triangles in the same places.

function cubeGeometry() {
  // 2x2x2 cube, -1..1 per axis, per-face normals (matches CubeGeometry.cube).
  const faces = [
    { n: [0, 0, 1], v: [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]] },
    { n: [0, 0, -1], v: [[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1]] },
    { n: [0, 1, 0], v: [[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]] },
    { n: [0, -1, 0], v: [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]] },
    { n: [1, 0, 0], v: [[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]] },
    { n: [-1, 0, 0], v: [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]] },
  ];
  const position = [], normal = [], indices = [];
  faces.forEach((face, f) => {
    face.v.forEach((v) => { position.push(...v); normal.push(...face.n); });
    const b = f * 4;
    indices.push(b, b + 1, b + 2, b, b + 2, b + 3);
  });
  return new Geometry({
    position: new Attribute(new Float32Array(position), 3),
    normal: new Attribute(new Float32Array(normal), 3),
    indices: new Attribute(new Uint16Array(indices), 1),
  });
}

function planeGeometry(width, height) {
  // XZ plane, +Y normal (matches PlaneGeometry.plane).
  const w = width / 2, h = height / 2;
  return new Geometry({
    position: new Attribute(new Float32Array([
      -w, 0, -h, w, 0, -h, w, 0, h, -w, 0, h,
    ]), 3),
    normal: new Attribute(new Float32Array([0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]), 3),
    indices: new Attribute(new Uint16Array([0, 2, 1, 0, 3, 2]), 1),
  });
}

function mirrorScene(description) {
  const meshes = description.meshes.map((m) => {
    const geometry = m.geometry === 'unitCube' ? cubeGeometry()
      : m.geometry === 'plane12' ? planeGeometry(12, 12)
      : fail(`Unknown geometry in scene description: ${m.geometry}`);
    const material = new OpenPBRMaterial({
      baseColor: m.baseColor,
      baseMetalness: m.metallic,
      specularRoughness: m.roughness,
    });
    const mesh = new Mesh(geometry, material);
    mesh.name = m.name;
    mesh.transform = m.transform; // column-major, same layout as Matrix4.storage
    return mesh;
  });

  const sun = new DirectionalLight({
    color: description.sun.color,
    intensity: description.sun.intensity,
  });
  // MuTracer analytic lights emit along local -Z; aim it down the sun vector.
  const d = description.sun.direction;
  sun.lookAt([d[0], d[1], d[2]]);

  const camera = new Camera({
    projection: 'perspective',
    fov: description.camera.fovDegrees,
    near: description.camera.near,
    far: description.camera.far,
  });
  camera.transform = description.camera.transform; // camera-to-world

  return {
    scene: { meshes, lights: [sun], background: description.background },
    camera,
  };
}

// --- Compositing pass -------------------------------------------------------
// Runs inside display.present() on the shared device. `input` is MuTracer's
// tone-mapped sRGB image (premultiplied). Thermion's frame is not imported
// directly: WebGPU's importExternalTexture accepts video only, so instead the
// hidden canvas' WebGPU context (created and configured by Emscripten for the
// present-skip swapchain; getContext returns that same context) is asked for
// its current swapchain texture — the one Thermion just rendered into — and
// that texture is copied into a sampleable one on the shared queue, which
// orders the copy after Thermion's submitted frame. The pass blends the
// path-traced image over the copy in linear space and re-encodes; present()
// then draws the result to the visible canvas. Thermion itself never presents
// (its swapchain is skipPresent). The pass receives MuTracer's composed image
// as `input` (a regular texture) and must fully write `output`; the pipeline
// is built per output format and the pass's encoder is borrowed, exactly as
// MuTracer's PostProcessContext documents.
function makeCompositor(device, offscreenCanvas, width, height) {
  const thermionContext = offscreenCanvas.getContext('webgpu');
  if (!thermionContext) fail('Thermion\u2019s offscreen canvas has no WebGPU context.');

  // Snapshot of the latest Thermion frame, refreshed by captureThermion().
  let thermionCopy = null;

  // Call once per animation frame, after Thermion rendered into the hidden
  // canvas and before present(). getCurrentTexture() returns the same texture
  // for every call within one frame, so this is exactly Thermion's target.
  const captureThermion = () => {
    const source = thermionContext.getCurrentTexture();
    if (!thermionCopy || thermionCopy.width !== source.width ||
        thermionCopy.height !== source.height ||
        thermionCopy.format !== source.format) {
      thermionCopy?.destroy();
      thermionCopy = device.createTexture({
        label: 'thermion-sidecar-frame',
        size: [source.width, source.height],
        format: source.format,
        usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
      });
    }
    const encoder = device.createCommandEncoder({ label: 'thermion-sidecar-capture' });
    encoder.copyTextureToTexture({ texture: source }, { texture: thermionCopy },
      [source.width, source.height]);
    device.queue.submit([encoder.finish()]);
  };

  // scaleX/scaleY map post-process UVs onto the centered requested rectangle
  // when MuTracer's internal target is larger than the requested size.
  const paramsBuffer = device.createBuffer({
    size: 16,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  device.queue.writeBuffer(paramsBuffer, 0, new Float32Array([blend, exposure, 1, 1]));
  const sampler = device.createSampler({ magFilter: 'linear', minFilter: 'linear' });

  const module = device.createShaderModule({
    label: 'thermion-sidecar-composite',
    code: /* wgsl */ `
@group(0) @binding(0) var thermionTexture: texture_2d<f32>;
@group(0) @binding(1) var tracedSampler: sampler;
@group(0) @binding(2) var tracedTexture: texture_2d<f32>;
struct Params { blend: f32, exposure: f32, scaleX: f32, scaleY: f32 };
@group(0) @binding(3) var<uniform> params: Params;

struct VSOut { @builtin(position) pos: vec4f, @location(0) uv: vec2f };
@vertex
fn vs(@builtin(vertex_index) i: u32) -> VSOut {
  // Fullscreen triangle; uv in [0,1], v flipped to image (top-first) space,
  // which is also the texel space of the canvas copy.
  let p = vec2f(f32((i << 1u) & 2u), f32(i & 2u));
  var out: VSOut;
  out.pos = vec4f(p * 2.0 - 1.0, 0.0, 1.0);
  out.uv = vec2f(p.x, 1.0 - p.y);
  return out;
}

fn toLinear(c: vec3f) -> vec3f {
  return select(pow((c + 0.055) / 1.055, vec3f(2.4)), c / 12.92, c <= vec3f(0.04045));
}
fn toSrgb(c: vec3f) -> vec3f {
  let l = max(c, vec3f(0.0));
  return select(1.055 * pow(l, vec3f(1.0 / 2.4)) - 0.055, l * 12.92, l <= vec3f(0.0031308));
}

@fragment
fn fs(in: VSOut) -> @location(0) vec4f {
  // Centered crop of the (possibly larger) internal image onto the requested
  // rectangle, matching Render's fixed-size framing.
  let uv = (in.uv - 0.5) * vec2f(params.scaleX, params.scaleY) + 0.5;
  let base = textureSampleLevel(thermionTexture, tracedSampler, uv, 0.0);
  let traced = textureSampleLevel(tracedTexture, tracedSampler, uv, 0.0);
  // Both inputs are premultiplied sRGB. Un-premultiply, decode, blend, re-encode.
  let baseRgb = toLinear(base.rgb / max(base.a, 1e-4));
  let tracedRgb = toLinear(traced.rgb / max(traced.a, 1e-4)) * params.exposure;
  let rgb = mix(baseRgb, tracedRgb, params.blend);
  let a = mix(base.a, traced.a, params.blend);
  return vec4f(toSrgb(rgb) * a, a);
}
`,
  });

  const pipelines = new Map();
  const pipelineFor = (format) => {
    let pipeline = pipelines.get(format);
    if (!pipeline) {
      pipeline = device.createRenderPipeline({
        label: 'thermion-sidecar-composite',
        layout: 'auto',
        vertex: { module, entryPoint: 'vs' },
        fragment: { module, entryPoint: 'fs', targets: [{ format }] },
        primitive: { topology: 'triangle-list' },
      });
      pipelines.set(format, pipeline);
    }
    return pipeline;
  };

  // MuTracer's fixed-size renders may round the internal target up and widen
  // the view; the post-process images stay at the internal size while the
  // canvases keep the requested size. Scale UVs into the centered requested
  // rectangle so the composite lines up with Thermion's framing.
  let lastScaleX = 1, lastScaleY = 1;
  const postProcess = ({ device: passDevice, encoder, input, output, width: renderWidth, height: renderHeight }) => {
    const scaleX = width / renderWidth, scaleY = height / renderHeight;
    if (scaleX !== lastScaleX || scaleY !== lastScaleY) {
      lastScaleX = scaleX; lastScaleY = scaleY;
      device.queue.writeBuffer(paramsBuffer, 0,
        new Float32Array([blend, exposure, scaleX, scaleY]));
    }
    // The pass must fully write `output`; before the first capture that is
    // a transparent clear.
    const captured = thermionCopy;
    const pass = encoder.beginRenderPass({
      colorAttachments: [{
        view: output.createView(),
        loadOp: 'clear',
        storeOp: 'store',
        clearValue: { r: 0, g: 0, b: 0, a: 0 },
      }],
    });
    if (captured) {
      const pipeline = pipelineFor(output.format);
      const bindGroup = passDevice.createBindGroup({
        layout: pipeline.getBindGroupLayout(0),
        entries: [
          { binding: 0, resource: captured.createView() },
          { binding: 1, resource: sampler },
          { binding: 2, resource: input.createView() },
          { binding: 3, resource: { buffer: paramsBuffer } },
        ],
      });
      pass.setPipeline(pipeline);
      pass.setBindGroup(0, bindGroup);
      pass.draw(3);
    }
    pass.end();
  };

  return { captureThermion, postProcess };
}

// --- Boot -------------------------------------------------------------------

async function start() {
  const bridge = JSON.parse(window.thermionSidecarScene);
  const module = window.thermion_dart;
  const device = module?.thermionWebGPUDevice;
  if (!device) {
    fail('No Module["thermionWebGPUDevice"]: build the engine with ' +
      'THERMION_ENABLE_WEBGPU=ON and use Backend.WEBGPU (see README).');
  }
  const offscreenCanvas = document.querySelector(bridge.offscreenCanvasSelector);
  const presentCanvas = document.querySelector(bridge.presentCanvasSelector);
  if (!offscreenCanvas || !presentCanvas) fail('Sidecar canvases are missing.');

  const { scene, camera } = mirrorScene(bridge.scene);

  // Caller-owned device: MuTracer renders on Thermion's GPUDevice.
  const engine = new Engine({
    device,
    backend: 'webgpu',
    canvas: presentCanvas,
  });
  engine.scene = scene;
  engine.camera = camera;
  // BLAS preparation may use MuTracer's worker pool (the build script emits
  // the worker chunk next to the bundle); the scene is tiny either way.
  engine.on('error', (error) => fail(`MuTracer: ${error.message}`));

  setStatus('MuTracer: initializing on Thermion\u2019s GPUDevice\u2026');
  const info = await engine.init();
  if (info.backend !== 'webgpu') fail('MuTracer fell back to WebGL; expected WebGPU.');

  // Commit the static scene exactly once. Nothing in `scene` changes after
  // this, so later update() calls report no changes and the BLAS is never
  // rebuilt.
  const committed = engine.update();
  if (!committed) fail('Scene mirror produced no changes to commit.');
  await engine.prepare(scene); // static BLAS, built once
  setStatus('MuTracer: BLAS built; compiling shaders\u2026');

  const render = new Render(engine, {
    width: bridge.width,
    height: bridge.height,
    maxSamples,
    bounces: 4,
  });
  engine.display.toneMapping = 'aces';
  engine.display.toneMappingExposure = 1;
  const { captureThermion, postProcess } =
    makeCompositor(device, offscreenCanvas, bridge.width, bridge.height);
  engine.display.addPostProcess(postProcess);

  let blasRebuilt = false;
  const frame = () => {
    // No scene edits: update() is a no-op change check, kept to prove the
    // BLAS-once contract (it must keep returning false).
    if (engine.update()) blasRebuilt = true;
    if (!render.converged) render.refine();
    // Snapshot Thermion's freshly rendered swapchain texture (same frame, same
    // queue) so the composite always uses the latest offscreen frame.
    captureThermion();
    if (render.samples > 0) {
      engine.display.present(render);
      setStatus(render.converged
        ? `MuTracer sidecar: ${render.samples} samples on Thermion's GPUDevice (shared, BLAS built once${blasRebuilt ? ' — WARNING: scene re-committed' : ''}). Blend ${blend}.`
        : `MuTracer sidecar: ${render.samples}/${maxSamples} samples\u2026`);
    }
    requestAnimationFrame(frame);
  };
  requestAnimationFrame(frame);
}

if (window.thermionSidecarScene) {
  start().catch((error) => fail(String(error?.message ?? error)));
} else {
  window.addEventListener('thermion-sidecar-ready',
    () => start().catch((error) => fail(String(error?.message ?? error))),
    { once: true });
}