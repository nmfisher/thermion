// The browser supplies a GPUDevice asynchronously. Finish requesting it
// before clients can create a Filament engine with the WebGPU backend.
function initializeWebGPUDevice() {
  if (Module['webgpu'] === false || Module['preinitializedWebGPUDevice'] || !globalThis.navigator?.gpu) {
    return;
  }

  const dependency = 'thermion-webgpu-device';
  addRunDependency(dependency);
  (async () => {
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) return;

    const requiredFeatures = [
      'immediates', 'chromium-experimental-immediate-data', 'rg11b10ufloat-renderable',
      'float32-filterable', 'float32-blendable', 'depth-clip-control', 'depth32float-stencil8',
      'texture-compression-bc', 'texture-compression-etc2', 'texture-compression-astc',
    ].filter(feature => adapter.features.has(feature));
    const requiredLimits = {};
    for (const key in adapter.limits) {
      requiredLimits[key] = adapter.limits[key];
    }
    if (requiredLimits.maxImmediateSize === undefined && requiredFeatures.includes('chromium-experimental-immediate-data')) {
      requiredLimits.maxImmediateSize = 64;
    }
    Module['preinitializedWebGPUDevice'] = await adapter.requestDevice({ requiredFeatures, requiredLimits });
  })().catch(error => {
    console.warn('Thermion could not initialize WebGPU:', error);
  }).finally(() => removeRunDependency(dependency));
}

const configuredPreRun = Module['preRun'];
Module['preRun'] = [
  ...(typeof configuredPreRun === 'function' ? [configuredPreRun] : configuredPreRun || []),
  initializeWebGPUDevice,
];
