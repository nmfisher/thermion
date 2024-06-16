let buildArgsList;

// `modulePromise` is a promise to the `WebAssembly.module` object to be
//   instantiated.
// `importObjectPromise` is a promise to an object that contains any additional
//   imports needed by the module that aren't provided by the standard runtime.
//   The fields on this object will be merged into the importObject with which
//   the module will be instantiated.
// This function returns a promise to the instantiated module.
export const instantiate = async (modulePromise, importObjectPromise) => {
    let dartInstance;

    function stringFromDartString(string) {
        const totalLength = dartInstance.exports.$stringLength(string);
        let result = '';
        let index = 0;
        while (index < totalLength) {
          let chunkLength = Math.min(totalLength - index, 0xFFFF);
          const array = new Array(chunkLength);
          for (let i = 0; i < chunkLength; i++) {
              array[i] = dartInstance.exports.$stringRead(string, index++);
          }
          result += String.fromCharCode(...array);
        }
        return result;
    }

    function stringToDartString(string) {
        const length = string.length;
        let range = 0;
        for (let i = 0; i < length; i++) {
            range |= string.codePointAt(i);
        }
        if (range < 256) {
            const dartString = dartInstance.exports.$stringAllocate1(length);
            for (let i = 0; i < length; i++) {
                dartInstance.exports.$stringWrite1(dartString, i, string.codePointAt(i));
            }
            return dartString;
        } else {
            const dartString = dartInstance.exports.$stringAllocate2(length);
            for (let i = 0; i < length; i++) {
                dartInstance.exports.$stringWrite2(dartString, i, string.charCodeAt(i));
            }
            return dartString;
        }
    }

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + js;
    }

    // Converts a Dart List to a JS array. Any Dart objects will be converted, but
    // this will be cheap for JSValues.
    function arrayFromDartList(constructor, list) {
        const length = dartInstance.exports.$listLength(list);
        const array = new constructor(length);
        for (let i = 0; i < length; i++) {
            array[i] = dartInstance.exports.$listRead(list, i);
        }
        return array;
    }

    buildArgsList = function(list) {
        const dartList = dartInstance.exports.$makeStringList();
        for (let i = 0; i < list.length; i++) {
            dartInstance.exports.$listAdd(dartList, stringToDartString(list[i]));
        }
        return dartList;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
        wrapped.dartFunction = dartFunction;
        wrapped[jsWrappedDartFunctionSymbol] = true;
        return wrapped;
    }

    // Imports
    const dart2wasm = {

_18: f => finalizeWrapper(f,x0 => dartInstance.exports._18(f,x0)),
_19: f => finalizeWrapper(f,x0 => dartInstance.exports._19(f,x0)),
_75: (x0,x1) => x0.getElementById(x1),
_76: f => finalizeWrapper(f,x0 => dartInstance.exports._76(f,x0)),
_77: (x0,x1,x2) => x0.addEventListener(x1,x2),
_78: f => finalizeWrapper(f,x0 => dartInstance.exports._78(f,x0)),
_79: f => finalizeWrapper(f,x0 => dartInstance.exports._79(f,x0)),
_1499: (x0,x1) => x0.width = x1,
_1501: (x0,x1) => x0.height = x1,
_1878: () => globalThis.window,
_1920: x0 => x0.innerWidth,
_1921: x0 => x0.innerHeight,
_6854: () => globalThis.document,
_12721: () => globalThis.createBoolCallback(),
_12722: () => globalThis.createVoidPointerCallback(),
_12723: () => globalThis.createVoidCallback(),
_12727: v => stringToDartString(v.toString()),
_12743: () => {
          let stackString = new Error().stack.toString();
          let frames = stackString.split('\n');
          let drop = 2;
          if (frames[0] === 'Error') {
              drop += 1;
          }
          return frames.slice(drop).join('\n');
        },
_12762: s => stringToDartString(JSON.stringify(stringFromDartString(s))),
_12763: s => printToConsole(stringFromDartString(s)),
_12777: (ms, c) =>
              setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
_12781: (c) =>
              queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
_12783: (a, i) => a.push(i),
_12794: a => a.length,
_12796: (a, i) => a[i],
_12797: (a, i, v) => a[i] = v,
_12799: a => a.join(''),
_12809: (s, p, i) => s.indexOf(p, i),
_12812: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
_12813: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
_12814: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
_12815: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
_12816: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
_12817: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
_12818: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
_12821: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
_12822: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
_12827: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
_12831: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
_12832: (b, o) => new DataView(b, o),
_12834: Function.prototype.call.bind(DataView.prototype.getUint8),
_12836: Function.prototype.call.bind(DataView.prototype.getInt8),
_12838: Function.prototype.call.bind(DataView.prototype.getUint16),
_12840: Function.prototype.call.bind(DataView.prototype.getInt16),
_12842: Function.prototype.call.bind(DataView.prototype.getUint32),
_12844: Function.prototype.call.bind(DataView.prototype.getInt32),
_12850: Function.prototype.call.bind(DataView.prototype.getFloat32),
_12852: Function.prototype.call.bind(DataView.prototype.getFloat64),
_12873: o => o === undefined,
_12874: o => typeof o === 'boolean',
_12875: o => typeof o === 'number',
_12877: o => typeof o === 'string',
_12880: o => o instanceof Int8Array,
_12881: o => o instanceof Uint8Array,
_12882: o => o instanceof Uint8ClampedArray,
_12883: o => o instanceof Int16Array,
_12884: o => o instanceof Uint16Array,
_12885: o => o instanceof Int32Array,
_12886: o => o instanceof Uint32Array,
_12887: o => o instanceof Float32Array,
_12888: o => o instanceof Float64Array,
_12889: o => o instanceof ArrayBuffer,
_12890: o => o instanceof DataView,
_12891: o => o instanceof Array,
_12892: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
_12896: (l, r) => l === r,
_12897: o => o,
_12898: o => o,
_12899: o => o,
_12900: b => !!b,
_12901: o => o.length,
_12904: (o, i) => o[i],
_12905: f => f.dartFunction,
_12906: l => arrayFromDartList(Int8Array, l),
_12907: l => arrayFromDartList(Uint8Array, l),
_12908: l => arrayFromDartList(Uint8ClampedArray, l),
_12909: l => arrayFromDartList(Int16Array, l),
_12910: l => arrayFromDartList(Uint16Array, l),
_12911: l => arrayFromDartList(Int32Array, l),
_12912: l => arrayFromDartList(Uint32Array, l),
_12913: l => arrayFromDartList(Float32Array, l),
_12914: l => arrayFromDartList(Float64Array, l),
_12915: (data, length) => {
          const view = new DataView(new ArrayBuffer(length));
          for (let i = 0; i < length; i++) {
              view.setUint8(i, dartInstance.exports.$byteDataGetUint8(data, i));
          }
          return view;
        },
_12916: l => arrayFromDartList(Array, l),
_12917: stringFromDartString,
_12918: stringToDartString,
_12921: l => new Array(l),
_12925: (o, p) => o[p],
_12929: o => String(o),
_12930: (p, s, f) => p.then(s, f),
_12949: (o, p) => o[p]
    };

    const baseImports = {
        dart2wasm: dart2wasm,


        Math: Math,
        Date: Date,
        Object: Object,
        Array: Array,
        Reflect: Reflect,
    };

    const jsStringPolyfill = {
        "charCodeAt": (s, i) => s.charCodeAt(i),
        "compare": (s1, s2) => {
            if (s1 < s2) return -1;
            if (s1 > s2) return 1;
            return 0;
        },
        "concat": (s1, s2) => s1 + s2,
        "equals": (s1, s2) => s1 === s2,
        "fromCharCode": (i) => String.fromCharCode(i),
        "length": (s) => s.length,
        "substring": (s, a, b) => s.substring(a, b),
    };

    dartInstance = await WebAssembly.instantiate(await modulePromise, {
        ...baseImports,
        ...(await importObjectPromise),
        "wasm:js-string": jsStringPolyfill,
    });

    return dartInstance;
}

// Call the main function for the instantiated module
// `moduleInstance` is the instantiated dart2wasm module
// `args` are any arguments that should be passed into the main function.
export const invoke = (moduleInstance, ...args) => {
    const dartMain = moduleInstance.exports.$getMain();
    const dartArgs = buildArgsList(args);
    moduleInstance.exports.$invokeMain(dartMain, dartArgs);
}

