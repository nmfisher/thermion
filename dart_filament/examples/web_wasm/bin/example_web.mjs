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

_48: v => stringToDartString(v.toString()),
_64: () => {
          let stackString = new Error().stack.toString();
          let frames = stackString.split('\n');
          let drop = 2;
          if (frames[0] === 'Error') {
              drop += 1;
          }
          return frames.slice(drop).join('\n');
        },
_83: s => stringToDartString(JSON.stringify(stringFromDartString(s))),
_84: s => printToConsole(stringFromDartString(s)),
_98: (ms, c) =>
              setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
_102: (c) =>
              queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
_104: (a, i) => a.push(i),
_115: a => a.length,
_117: (a, i) => a[i],
_118: (a, i, v) => a[i] = v,
_120: a => a.join(''),
_130: (s, p, i) => s.indexOf(p, i),
_133: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
_134: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
_135: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
_136: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
_137: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
_138: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
_139: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
_142: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
_143: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
_148: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
_152: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
_153: (b, o) => new DataView(b, o),
_155: Function.prototype.call.bind(DataView.prototype.getUint8),
_157: Function.prototype.call.bind(DataView.prototype.getInt8),
_159: Function.prototype.call.bind(DataView.prototype.getUint16),
_161: Function.prototype.call.bind(DataView.prototype.getInt16),
_163: Function.prototype.call.bind(DataView.prototype.getUint32),
_165: Function.prototype.call.bind(DataView.prototype.getInt32),
_171: Function.prototype.call.bind(DataView.prototype.getFloat32),
_173: Function.prototype.call.bind(DataView.prototype.getFloat64),
_194: o => o === undefined,
_195: o => typeof o === 'boolean',
_196: o => typeof o === 'number',
_198: o => typeof o === 'string',
_201: o => o instanceof Int8Array,
_202: o => o instanceof Uint8Array,
_203: o => o instanceof Uint8ClampedArray,
_204: o => o instanceof Int16Array,
_205: o => o instanceof Uint16Array,
_206: o => o instanceof Int32Array,
_207: o => o instanceof Uint32Array,
_208: o => o instanceof Float32Array,
_209: o => o instanceof Float64Array,
_210: o => o instanceof ArrayBuffer,
_211: o => o instanceof DataView,
_212: o => o instanceof Array,
_213: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
_217: (l, r) => l === r,
_218: o => o,
_219: o => o,
_220: o => o,
_221: b => !!b,
_222: o => o.length,
_225: (o, i) => o[i],
_226: f => f.dartFunction,
_227: l => arrayFromDartList(Int8Array, l),
_228: l => arrayFromDartList(Uint8Array, l),
_229: l => arrayFromDartList(Uint8ClampedArray, l),
_230: l => arrayFromDartList(Int16Array, l),
_231: l => arrayFromDartList(Uint16Array, l),
_232: l => arrayFromDartList(Int32Array, l),
_233: l => arrayFromDartList(Uint32Array, l),
_234: l => arrayFromDartList(Float32Array, l),
_235: l => arrayFromDartList(Float64Array, l),
_236: (data, length) => {
          const view = new DataView(new ArrayBuffer(length));
          for (let i = 0; i < length; i++) {
              view.setUint8(i, dartInstance.exports.$byteDataGetUint8(data, i));
          }
          return view;
        },
_237: l => arrayFromDartList(Array, l),
_238: stringFromDartString,
_239: stringToDartString,
_242: l => new Array(l),
_246: (o, p) => o[p],
_250: o => String(o)
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

