const fs = require('node:fs');
const dart_filament = require("./dart_filament.js")
const GLctx = require('gl')(100, 100, { preserveDrawingBuffer: true })

// queueMicrotask = (func) => {
//     func();
// }
// read('dart_filament.wasm', 'binary')
// const exports = {};
// const module = {};

const wasmBuffer = fs.readFileSync('dart_filament.wasm');

var dartFilamentModulePromise = WebAssembly.compile(wasmBuffer);

dart_filament({ctx:GLctx}).then((df) => { 
    dartFilamentResolveCallback = (cb, data) => {
        const fn = df.wasmTable.get(cb);
        if(data) {
            fn(data);
        } else { 
            fn();
        }
    }
    createVoidCallback = () => { 
        let res; //placeholder for resolver callback, outside of promise
        const promise = new Promise((resolve, reject) => {
            res = resolve;
        });
        try {
            const callback = () => { 
                try {
                    res({});
                } catch(err) {
                    console.log(err);
                }
            }
            const fnPtr = df.addFunction(callback, 'v');
            return [promise, fnPtr];
        } catch(err) {
            console.log(err);
            return null;
        } 
    }       
    createIntCallback = () => { 
        let res; 
        const promise = new Promise((resolve, reject) => {
            res = resolve;
        });
        try {
            const callback = (val) => { 
                try {
                    res(val);
                } catch(err) {
                    console.log(err);
                }
            }
            const fnPtr = df.addFunction(callback, 'vi');
            return [promise, fnPtr];
        } catch(err) {
            console.log(err);
            return null;
        } 
    }       
    createVoidPointerCallback = () => { 
        console.log("create void ptr callback");
        let res; //placeholder for resolver callback, outside of promise
        const promise = new Promise((resolve, reject) => {
            console.log("resolve");
            res = resolve;
        });
        try {
            console.log("try");
            const callback = (voidPtr) => { 
                try {
                    res(voidPtr);
                } catch(err) {
                    console.log(err);
                }
            }
            const fnPtr = df.addFunction(callback, 'vi');
            console.log("done, returning");
            return [promise, fnPtr];
        } catch(err) {
            console.log(err);
            return null;
        }        
    }   

    createBoolCallback = () => { 
        let res; //placeholder for resolver callback, outside of promise

        const promise = new Promise((resolve, reject) => {
            res = resolve;
        });
        try {
            const callback = (val) => { 
                try {
                    res(val);
                } catch(err) {
                    console.log(err);
                }
            }
            const fnPtr = df.addFunction(callback, 'vi');
            return [promise, fnPtr];
        } catch(err) {
            console.log(err);
            return null;
        }        
    }   

    import('./example_cli.mjs').then((dart2wasm_runtime) => { 
        var dartModulePromise = WebAssembly.compile(fs.readFileSync('./example_cli.wasm'));
        const imports = {"dart_filament": df, "ctx": GLctx};
        dart2wasm_runtime.instantiate(dartModulePromise, imports).then((moduleInstance) => { 
            dart2wasm_runtime.invoke(moduleInstance); 
        }); 
    });
});

//     // dartModulePromise.then((dartModule) => { console.log(dartModule.exports); dart2wasm_runtime.invoke(dartModule, imports);}); });