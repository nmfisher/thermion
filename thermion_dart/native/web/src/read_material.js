// Both engine variants use Emscripten pthreads. Its loader retains wasmModule
// to start workers, including when the render loop runs on the main thread.
Module['readThermionMaterial'] = (name) =>
  WebAssembly.Module.customSections(wasmModule, name)[0];
