// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

(async function () {
  let dart2wasm_runtime;
  let moduleInstance;
  try {
    var Module = {};
    // adding this as a property to Module means it will get exported "across" the web worker boundary as a handler
    Module['loadFlutterAsset'] = (path, context) => {
      return moduleInstance.exports.loadFlutterAsset(path, context);
    }
    Module['instantiateWasm'] = function(imports, successCallback) {
      imports["env"]["loadFlutterAsset"] = (out, length, callback, userData) => { 
        console.log("This function is only provided on the main thread to satisfy the WASM runtime linker. You should never actually see this being called.")
      }
      fetch('assets/assets/web/flutter_filament_plugin.wasm', { credentials: 'same-origin' }).then(async (response)  => {
        var result = await WebAssembly.instantiateStreaming(response, imports);
        successCallback(result.instance,result.module);
      });
      return {};
    }
    const imports = {"flutter_filament_plugin":await flutter_filament_plugin(Module),"ffi":{"memory":new WebAssembly.Memory({
      initial: 10,
      maximum: 100,
    })}};
    const dartModulePromise = WebAssembly.compileStreaming(fetch('main.dart.wasm'));
        
    dart2wasm_runtime = await import('./main.dart.mjs');
    moduleInstance = await dart2wasm_runtime.instantiate(dartModulePromise, imports);
  } catch (exception) {
    console.error(`Failed to fetch and instantiate wasm module: ${exception}`);
    console.error('See https://flutter.dev/wasm for more information.');
  }

  if (moduleInstance) {
    try {
      await dart2wasm_runtime.invoke(moduleInstance);
    } catch (exception) {
      console.error(`Exception while invoking test: ${exception}`);
    }
  }
})();
