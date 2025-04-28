import { readFile } from 'fs/promises';

import { compile } from './example.mjs';
import thermion_dart from './thermion_dart.js';


async function runDartWasm() {
    globalThis['thermion_dart'] = await thermion_dart(); 

    const wasmBytes = await readFile('example.wasm');
    const compiledApp = await compile(wasmBytes);
    const instantiatedApp = await compiledApp.instantiate({});
    try {
        instantiatedApp.invokeMain();
    } catch(err) {
        console.error("Failed");
        console.error(err);
    }
}

runDartWasm().catch(console.error);

