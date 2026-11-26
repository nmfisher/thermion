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
// The Dart side (web/main.dart) describes its static geometry once as JSON on
// window.thermionSidecarScene and fires 'thermion-sidecar-ready'. This module
// mirrors that description into @meimu/mutracer and commits it with a single
// Engine.update() (the geometry never changes afterwards, so the static BLAS
// is built exactly once). Everything that changes afterwards comes through two
// per-frame channels the Dart side owns:
//
//   window.thermionSidecarCamera  { viewMatrix, position, focus, revision }
//       refreshed EVERY frame. `revision` only increments when the orbit
//       camera moved; a new revision is applied to the MuTracer camera (the
//       column-major view matrix is inverted into its camera-to-world
//       transform) and resets the sample accumulation.
//   window.thermionSidecarMode    'raytrace' | 'viewport'
//       'raytrace' (default): MuTracer's interactive policy — a cheap PREVIEW
//       Render (reduced resolution, adaptive scale) is shown while the camera
//       is moving, the full Render converges once it is stable — and
//       display.present() runs the composite pass below.
//       'viewport': no path tracing at all; Thermion's offscreen snapshot is
//       drawn unchanged to the visible canvas (pass-through of the Filament
//       raster frame). Both modes are presented by this sidecar, on the shared
//       device, and the single offscreen swapchain is kept in both.
//
// Raytrace motion: the first trace() after an accumulation reset can be a
// hidden timing probe (0 samples) and a sample slower than the tile budget is
// split over several refine() calls, so "restart, refine once, present if
// samples > 0" never presents while the camera changes every frame — the
// image froze during a drag and jumped on release. Now a camera change
// restarts the preview and refines it (capped) until it has a visible sample
// for the new view, and present() is called EVERY frame: `render` has the
// preview as its fallback, so display.present(render) shows the preview until
// the full image has its own sample for the current view.
//
// Compositing: every frame (after Thermion rendered) the hidden offscreen
// canvas' current swapchain texture is copied into a sampleable texture on the
// shared queue; Display.addPostProcess registers a pass that runs inside
// engine.display.present() on the same device and blends the path-traced
// image over that copy. present() then draws the blended image to the visible
// canvas — Thermion itself never presents (its swapchain is skipPresent).
// Filament skips frames while the previous frame is still pending on the GPU,
// and Blink hands out a blank texture to the first getCurrentTexture() caller
// of every frame, so the snapshot is only taken on frames Thermion actually
// rendered (see makeCompositor); on skipped frames the latest snapshot is
// reused by both modes.
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

const progressEl = document.getElementById('progress');
const statusEl = document.getElementById('status');
const setStatus = (text) => {
  // Dart owns the mode + controls hint (#mode_label); progress goes to
  // #progress so the two never overwrite each other.
  (progressEl ?? statusEl)?.replaceChildren(document.createTextNode(text));
};
const fail = (message) => {
  setStatus(message);
  throw new Error(message);
};

// Sidecar-tunable parameters (URL query):
//   ?samples=N   path-traced samples to accumulate (default 256)
//   ?blend=F     0..1 weight of the path-traced image over Thermion's (0.85)
//   ?exposure=E  linear exposure for the path-traced image (1)
//   ?mode=viewport  start in viewport mode (handled by Dart; see main.dart)
const query = new URLSearchParams(window.location.search);
const maxSamples = Math.max(1, Number(query.get('samples')) || 256);
const blend = Math.min(1, Math.max(0, Number(query.get('blend') ?? 0.85)));
const exposure = Number(query.get('exposure')) || 1;

// Interactive policy (MuTracer RenderLoop defaults): the preview accumulates a
// few samples while it is on screen, a camera edit is followed by a short idle
// window before the full image resumes (so a brief pause between pointer moves
// does not start a full-resolution sample that the next move would discard),
// and after a restart the preview is refined at most this many times in one
// frame until it has a visible sample (hidden probe, tiled first sample); the
// cap keeps a slow adapter from busy-looping inside a frame.
const PREVIEW_SAMPLES = 4;
const IDLE_MS = 150;
const PREVIEW_REFINE_CAP = 6;

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
    // Index order must match Thermion's cube (cube.dart): the -Z (back) face,
    // faces[1] (b = 4), is REVERSED (5,4,7 / 5,7,6) so that it is
    // counter-clockwise seen from outside, i.e. front-facing w.r.t. its normal
    // [0,0,-1]. With the generic quad pattern its winding is flipped and
    // MuTracer backface-culls it (that side of the cube goes missing). The
    // other five faces use the generic pattern. Keep in sync with cube.dart.
    if (f === 1) {
      indices.push(b + 1, b, b + 3, b + 1, b + 3, b + 2);
    } else {
      indices.push(b, b + 1, b + 2, b, b + 2, b + 3);
    }
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

// Inverts a rigid (rotation + translation, no scale) column-major 4x4 view
// matrix into the camera-to-world transform MuTracer's Camera.transform takes:
// view = [R | t] with t = -R * eye, so inverse = [R^T | -R^T t].
function cameraToWorld(view) {
  const out = new Array(16);
  out[0] = view[0]; out[1] = view[4]; out[2] = view[8]; out[3] = 0;
  out[4] = view[1]; out[5] = view[5]; out[6] = view[9]; out[7] = 0;
  out[8] = view[2]; out[9] = view[6]; out[10] = view[10]; out[11] = 0;
  const tx = view[12], ty = view[13], tz = view[14];
  out[12] = -(view[0] * tx + view[1] * ty + view[2] * tz);
  out[13] = -(view[4] * tx + view[5] * ty + view[6] * tz);
  out[14] = -(view[8] * tx + view[9] * ty + view[10] * tz);
  out[15] = 1;
  return out;
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
  // Initial camera-to-world; superseded every frame by the per-frame channel.
  camera.transform = description.camera.transform;

  return {
    scene: { meshes, lights: [sun], background: description.background },
    camera,
  };
}

// Fullscreen triangle shared by both passes: uv in [0,1], v flipped to image
// (top-first) space, which is also the texel space of the canvas copy.
const fullscreenVertex = /* wgsl */ `
struct VSOut { @builtin(position) pos: vec4f, @location(0) uv: vec2f };
@vertex
fn vs(@builtin(vertex_index) i: u32) -> VSOut {
  let p = vec2f(f32((i << 1u) & 2u), f32(i & 2u));
  var out: VSOut;
  out.pos = vec4f(p * 2.0 - 1.0, 0.0, 1.0);
  out.uv = vec2f(p.x, 1.0 - p.y);
  return out;
}
`;

// --- Compositing pass (raytrace mode) ---------------------------------------
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
function makeCompositor(device, offscreenCanvas) {
  const thermionContext = offscreenCanvas.getContext('webgpu');
  if (!thermionContext) fail('Thermion\u2019s offscreen canvas has no WebGPU context.');

  // Snapshot of the latest Thermion frame, refreshed by captureThermion().
  let thermionCopy = null;
  const stats = { captures: 0, skippedFrames: 0 };

  // Filament does not necessarily render every animation frame: its beginFrame
  // rejects a frame while the previous frame's GPU work is still pending
  // (routinely every other frame on a software adapter). Blink nevertheless
  // hands a fresh, blank texture to the first getCurrentTexture() caller of
  // EVERY frame, so a sidecar that blindly snapshots "the current texture"
  // copies blank frames on the skipped ones (a flickering composite in
  // raytrace mode, a black canvas in viewport mode). Within one frame
  // getCurrentTexture() returns the same texture to every caller, so the
  // sidecar watches the texture Thermion itself acquires — Thermion's
  // Emscripten surface code calls this very context method — and snapshots
  // only when the current texture is that one, i.e. Thermion rendered this
  // frame. On a skipped frame the previous snapshot stays the latest frame.
  let thermionTexture = null;
  const acquireCurrentTexture = thermionContext.getCurrentTexture.bind(thermionContext);
  thermionContext.getCurrentTexture = () => (thermionTexture = acquireCurrentTexture());

  // Call once per animation frame, after Thermion rendered into the hidden
  // canvas and before present(). Returns whether a new frame was captured.
  const captureThermion = () => {
    const source = acquireCurrentTexture();
    if (source !== thermionTexture) {
      stats.skippedFrames++;
      return false;
    }
    stats.captures++;
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
    return true;
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

${fullscreenVertex}
fn toLinear(c: vec3f) -> vec3f {
  return select(pow((c + 0.055) / 1.055, vec3f(2.4)), c / 12.92, c <= vec3f(0.04045));
}
fn toSrgb(c: vec3f) -> vec3f {
  let l = max(c, vec3f(0.0));
  return select(1.055 * pow(l, vec3f(1.0 / 2.4)) - 0.055, l * 12.92, l <= vec3f(0.0031308));
}

@fragment
fn fs(in: VSOut) -> @location(0) vec4f {
  // Centered crop of a (possibly larger) fixed render's internal image onto
  // its requested rectangle (scale 1 for the preview), matching Render's
  // fixed-size framing. Thermion's snapshot is the full frame: 1:1.
  let uv = (in.uv - 0.5) * vec2f(params.scaleX, params.scaleY) + 0.5;
  let base = textureSampleLevel(thermionTexture, tracedSampler, in.uv, 0.0);
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

  // The post-process image (`input`, and `output`) is at the render's internal
  // size. A fixed-size render may round that up and widen the view; its
  // width/height is then the requested centered rectangle, so UVs are scaled
  // into it to keep the framing. A scale-based preview render covers exactly
  // the canvas view at a smaller size: scale 1 (the image is simply upscaled
  // by present()). The Thermion snapshot is the full frame in both cases and
  // is sampled 1:1, so both images line up for either render.
  let lastScaleX = 1, lastScaleY = 1;
  const postProcess = ({ device: passDevice, encoder, input, output, render }) => {
    const scaleX = render.width / input.width, scaleY = render.height / input.height;
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

  return {
    captureThermion,
    postProcess,
    get captured() { return thermionCopy; },
    get info() {
      return thermionCopy && { format: thermionCopy.format, width: thermionCopy.width, height: thermionCopy.height };
    },
    get stats() { return { ...stats }; },
  };
}

// --- Viewport pass-through (viewport mode) ----------------------------------
// Presents Thermion's offscreen snapshot UNCHANGED on the visible canvas: no
// path tracing, no blend, no re-encoding — a fullscreen draw that samples the
// copy and writes it to the visible canvas' current swapchain texture on the
// shared device. The visible canvas' WebGPU context is the one MuTracer
// configured for its own presentation (same device); this pass only borrows
// its current texture, exactly as MuTracer's display does, so both modes end
// up in the same place without a second swapchain for Thermion.
function makeViewportPresenter(device, presentCanvas) {
  const context = presentCanvas.getContext('webgpu');
  if (!context) fail('The visible canvas has no WebGPU context.');

  const module = device.createShaderModule({
    label: 'thermion-sidecar-viewport',
    code: /* wgsl */ `
@group(0) @binding(0) var thermionTexture: texture_2d<f32>;
@group(0) @binding(1) var thermionSampler: sampler;

${fullscreenVertex}
@fragment
fn fs(in: VSOut) -> @location(0) vec4f {
  // Pass-through of the Filament raster frame: same texel, same alpha.
  return textureSampleLevel(thermionTexture, thermionSampler, in.uv, 0.0);
}
`,
  });
  const sampler = device.createSampler({ magFilter: 'linear', minFilter: 'linear' });
  const pipelines = new Map();
  let cached = { source: null, format: null, bindGroup: null };
  let lastTarget = null;

  // `source` is the latest captureThermion() copy; call once per frame.
  const presentViewport = (source) => {
    const target = context.getCurrentTexture();
    lastTarget = { format: target.format, width: target.width, height: target.height };
    let pipeline = pipelines.get(target.format);
    if (!pipeline) {
      pipeline = device.createRenderPipeline({
        label: 'thermion-sidecar-viewport',
        layout: 'auto',
        vertex: { module, entryPoint: 'vs' },
        fragment: { module, entryPoint: 'fs', targets: [{ format: target.format }] },
        primitive: { topology: 'triangle-list' },
      });
      pipelines.set(target.format, pipeline);
    }
    if (cached.source !== source || cached.format !== target.format) {
      cached = {
        source,
        format: target.format,
        bindGroup: device.createBindGroup({
          layout: pipeline.getBindGroupLayout(0),
          entries: [
            { binding: 0, resource: source.createView() },
            { binding: 1, resource: sampler },
          ],
        }),
      };
    }
    const encoder = device.createCommandEncoder({ label: 'thermion-sidecar-viewport' });
    const pass = encoder.beginRenderPass({
      colorAttachments: [{
        view: target.createView(),
        loadOp: 'clear',
        storeOp: 'store',
        clearValue: { r: 0, g: 0, b: 0, a: 0 },
      }],
    });
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, cached.bindGroup);
    pass.draw(3);
    pass.end();
    device.queue.submit([encoder.finish()]);
  };

  return { presentViewport, get info() { return lastTarget; } };
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
  // WebGPU validation errors are silent unless someone listens; surface them
  // in the console so a bad pass never looks like a black canvas.
  device.addEventListener('uncapturederror', (event) => {
    console.error(`[mutracer_sidecar] WebGPU: ${event.error?.message ?? event.error}`);
  });

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

  // Commit the static geometry exactly once. Nothing in `scene` changes after
  // this, so later update() calls only ever report the camera (which never
  // touches the BLAS) — the frame loop asserts exactly that.
  const committed = engine.update();
  if (!committed) fail('Scene mirror produced no changes to commit.');
  await engine.prepare(scene); // static BLAS, built once
  setStatus('MuTracer: BLAS built; compiling shaders\u2026');

  // Full image: fixed size, up to maxSamples, 4 bounces.
  const render = new Render(engine, {
    width: bridge.width,
    height: bridge.height,
    maxSamples,
    bounces: 4,
  });
  // Interactive preview, with MuTracer's RenderLoop preview defaults: a
  // canvas-relative Render at half resolution whose scale adapts to the frame
  // time (down to 1/8), 2 bounces, no bevel, one wavelength and two light
  // candidates, so a sample fits a frame even on a slow adapter. Shown while
  // the camera moves and until the full image has a sample for that view.
  const preview = new Render(engine, {
    resolutionScale: 0.5,
    maxSamples: PREVIEW_SAMPLES,
    timeBudgetMs: 80,
    adaptiveResolution: { targetFrameMs: 80, minScale: 0.125 },
    bounces: 2,
    bevel: false,
    dispersionWavelengths: 1,
    directLightCandidates: 2,
  });
  // display.present(render) falls back to the preview while `render` has no
  // presentable image for the current camera (after every restart).
  render.fallback = preview;
  engine.display.toneMapping = 'aces';
  engine.display.toneMappingExposure = 1;
  const compositor = makeCompositor(device, offscreenCanvas);
  engine.display.addPostProcess(compositor.postProcess);
  const viewportPresenter = makeViewportPresenter(device, presentCanvas);
  const { presentViewport } = viewportPresenter;

  // Per-frame channel state.
  const stats = {
    mode: 'raytrace',
    cameraRevision: -1, // last revision applied to the MuTracer camera
    restarts: 0, // accumulation resets (camera or mode changes; both renders)
    refineCalls: 0, // full-image refine() calls
    previewRefines: 0, // preview refine() calls
    previewFrames: 0, // raytrace frames that presented the preview
    finalFrames: 0, // raytrace frames that presented the full image
    changing: false, // camera moving (or inside the idle window after a move)
    viewportFrames: 0,
    raytraceFrames: 0,
    unexpectedCommits: 0, // update() reported changes without a camera edit
  };
  const currentMode = () =>
    window.thermionSidecarMode === 'viewport' ? 'viewport' : 'raytrace';
  let mode = currentMode();
  stats.mode = mode;
  let lastCameraChange = -Infinity; // performance.now() of the last camera edit
  // Exposed for headless checks (README, Verification); read-only.
  const debug = {
    snapshot: () => ({
      ...stats,
      captures: compositor.stats.captures,
      skippedFrames: compositor.stats.skippedFrames,
      samples: render.samples,
      converged: render.converged,
      maxSamples,
      preview: {
        samples: preview.samples,
        maxSamples: preview.maxSamples,
        resolutionScale: preview.resolutionScale,
        width: preview.width,
        height: preview.height,
      },
      cameraPosition: Array.from(camera.position),
      capture: compositor.info,
    }),
  };
  window.thermionSidecarDebug = debug;

  const frame = () => {
    const now = performance.now();
    // 1. Per-frame camera sync. A new revision means the orbit camera moved:
    // apply it to the MuTracer camera and restart accumulation.
    const channel = window.thermionSidecarCamera;
    let cameraChanged = false;
    if (channel && channel.revision !== stats.cameraRevision) {
      stats.cameraRevision = channel.revision;
      camera.transform = cameraToWorld(channel.viewMatrix);
      cameraChanged = true;
      lastCameraChange = now;
    }

    // 2. Mode: Dart writes window.thermionSidecarMode on every toggle.
    mode = currentMode();
    const modeChanged = mode !== stats.mode;
    stats.mode = mode;

    // 3. Change check. A camera edit is expected to report a change; it
    //    never re-commits the scene, so anything else is a BLAS-once violation.
    if (engine.update() && !cameraChanged) stats.unexpectedCommits++;

    // 4. Reset the accumulation when the camera or the mode changed, so the
    //    path-traced image never mixes samples from different views. Both
    //    renders restart; neither is presentable for the new view until it has
    //    traced a sample for it (display.present() checks exactly that).
    if (cameraChanged || modeChanged) {
      render.restart();
      preview.restart();
      stats.restarts++;
    }

    // 5. Snapshot Thermion's freshly rendered swapchain texture (same frame,
    //    same queue); on a frame Filament skipped this keeps the previous
    //    snapshot, which is then the latest frame either mode can show.
    compositor.captureThermion();

    if (mode === 'viewport') {
      // Pass-through of the Filament raster frame: no refine(), no blend.
      if (compositor.captured) presentViewport(compositor.captured);
      stats.viewportFrames++;
      stats.changing = false;
      setStatus(`Viewport: Thermion\u2019s raster frame passed through unchanged (path tracing paused).`);
    } else {
      // MuTracer's interactive policy: changing ? preview : final.
      const changing = cameraChanged || now - lastCameraChange < IDLE_MS;
      stats.changing = changing;
      if (changing) {
        // Camera moving: the preview must show THIS view this frame. The
        // restart dropped it to 0 samples; the first refine() after a reset
        // may be a hidden timing probe and a slow sample is split into tiles,
        // so keep refining (capped) until a sample is complete. Inside the
        // idle window after a move (no new revision) let it converge a little.
        const wanted = cameraChanged ? 1 : preview.maxSamples;
        const cap = cameraChanged ? PREVIEW_REFINE_CAP : 1;
        for (let i = 0; i < cap && preview.samples < wanted; i++) {
          preview.refine();
          stats.previewRefines++;
        }
      } else {
        // Camera stable: the full image converges. The preview stays on
        // screen (fallback) only until the full image has its first sample.
        if (!render.converged) {
          render.refine();
          stats.refineCalls++;
        }
        if (render.samples === 0 && !preview.converged) {
          preview.refine();
          stats.previewRefines++;
        }
      }
      // Present EVERY raytrace frame: the full image, or the preview while the
      // full image has no complete sample for the current camera. If neither
      // has one (nothing visible was produced this frame) present() draws
      // nothing and the canvas keeps showing the previous image; it never
      // blanks and never freezes on a stale view while the preview has one.
      const presented = engine.display.present(render);
      if (presented === preview) stats.previewFrames++;
      else if (presented === render) stats.finalFrames++;
      stats.raytraceFrames++;
      setStatus(render.converged
        ? `MuTracer sidecar: ${render.samples} samples on Thermion's GPUDevice (shared, BLAS built once${stats.unexpectedCommits ? ' — WARNING: scene re-committed' : ''}). Blend ${blend}.`
        : changing
          ? `MuTracer sidecar: camera moving, preview ${preview.samples} spp at ${preview.width}x${preview.height} (full image resumes when the camera stops)\u2026`
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
