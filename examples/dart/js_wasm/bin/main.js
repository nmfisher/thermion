import { readFile } from 'fs/promises';

import { compile } from './example.mjs';
import thermion_dart from './thermion_dart.js';

globalThis['thermion_dart'] = await thermion_dart(); 

const wasmBytes = await readFile('example.wasm');

async function runDartWasm() {
    const compiledApp = await compile(wasmBytes);
    const instantiatedApp = await compiledApp.instantiate({});
    instantiatedApp.invokeMain();
}

runDartWasm().catch(console.error);

