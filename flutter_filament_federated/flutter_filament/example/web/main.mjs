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

_11: x0 => new Array(x0),
_12: x0 => new Promise(x0),
_17: (o,s,v) => o[s] = v,
_18: f => finalizeWrapper(f,x0 => dartInstance.exports._18(f,x0)),
_19: f => finalizeWrapper(f,x0 => dartInstance.exports._19(f,x0)),
_20: (x0,x1,x2) => x0.call(x1,x2),
_21: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._21(f,x0,x1)),
_22: (x0,x1) => x0.call(x1),
_23: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._23(f,x0,x1)),
_44: () => Symbol("jsBoxedDartObjectProperty"),
_75: (x0,x1) => x0.getElementById(x1),
_1495: (x0,x1) => x0.width = x1,
_1497: (x0,x1) => x0.height = x1,
_1874: () => globalThis.window,
_1916: x0 => x0.innerWidth,
_1917: x0 => x0.innerHeight,
_6850: () => globalThis.document,
_12719: () => globalThis.createVoidCallback(),
_12720: () => globalThis.createVoidPointerCallback(),
_12721: () => globalThis.createBoolCallback(),
_12722: () => globalThis.createBoolCallback(),
_12724: v => stringToDartString(v.toString()),
_12740: () => {
          let stackString = new Error().stack.toString();
          let frames = stackString.split('\n');
          let drop = 2;
          if (frames[0] === 'Error') {
              drop += 1;
          }
          return frames.slice(drop).join('\n');
        },
_12759: s => stringToDartString(JSON.stringify(stringFromDartString(s))),
_12760: s => printToConsole(stringFromDartString(s)),
_12761: f => finalizeWrapper(f,() => dartInstance.exports._12761(f)),
_12762: f => finalizeWrapper(f,() => dartInstance.exports._12762(f)),
_12763: f => finalizeWrapper(f,x0 => dartInstance.exports._12763(f,x0)),
_12764: f => finalizeWrapper(f,() => dartInstance.exports._12764(f)),
_12765: f => finalizeWrapper(f,x0 => dartInstance.exports._12765(f,x0)),
_12766: f => finalizeWrapper(f,() => dartInstance.exports._12766(f)),
_12767: f => finalizeWrapper(f,x0 => dartInstance.exports._12767(f,x0)),
_12768: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12768(f,x0,x1)),
_12769: f => finalizeWrapper(f,() => dartInstance.exports._12769(f)),
_12770: f => finalizeWrapper(f,(x0,x1,x2,x3) => dartInstance.exports._12770(f,x0,x1,x2,x3)),
_12771: f => finalizeWrapper(f,x0 => dartInstance.exports._12771(f,x0)),
_12772: f => finalizeWrapper(f,() => dartInstance.exports._12772(f)),
_12773: f => finalizeWrapper(f,x0 => dartInstance.exports._12773(f,x0)),
_12774: f => finalizeWrapper(f,x0 => dartInstance.exports._12774(f,x0)),
_12775: f => finalizeWrapper(f,() => dartInstance.exports._12775(f)),
_12776: f => finalizeWrapper(f,(x0,x1,x2,x3,x4,x5,x6,x7,x8,x9) => dartInstance.exports._12776(f,x0,x1,x2,x3,x4,x5,x6,x7,x8,x9)),
_12777: f => finalizeWrapper(f,x0 => dartInstance.exports._12777(f,x0)),
_12778: f => finalizeWrapper(f,() => dartInstance.exports._12778(f)),
_12779: f => finalizeWrapper(f,x0 => dartInstance.exports._12779(f,x0)),
_12780: f => finalizeWrapper(f,x0 => dartInstance.exports._12780(f,x0)),
_12781: f => finalizeWrapper(f,x0 => dartInstance.exports._12781(f,x0)),
_12782: f => finalizeWrapper(f,x0 => dartInstance.exports._12782(f,x0)),
_12783: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12783(f,x0,x1)),
_12784: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12784(f,x0,x1)),
_12785: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12785(f,x0,x1)),
_12786: f => finalizeWrapper(f,() => dartInstance.exports._12786(f)),
_12787: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12787(f,x0,x1)),
_12788: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12788(f,x0,x1)),
_12789: f => finalizeWrapper(f,() => dartInstance.exports._12789(f)),
_12790: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12790(f,x0,x1)),
_12791: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12791(f,x0,x1)),
_12792: f => finalizeWrapper(f,x0 => dartInstance.exports._12792(f,x0)),
_12793: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12793(f,x0,x1)),
_12794: f => finalizeWrapper(f,(x0,x1,x2,x3,x4) => dartInstance.exports._12794(f,x0,x1,x2,x3,x4)),
_12795: f => finalizeWrapper(f,x0 => dartInstance.exports._12795(f,x0)),
_12796: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12796(f,x0,x1)),
_12797: f => finalizeWrapper(f,x0 => dartInstance.exports._12797(f,x0)),
_12798: f => finalizeWrapper(f,() => dartInstance.exports._12798(f)),
_12799: f => finalizeWrapper(f,() => dartInstance.exports._12799(f)),
_12800: f => finalizeWrapper(f,(x0,x1,x2) => dartInstance.exports._12800(f,x0,x1,x2)),
_12801: f => finalizeWrapper(f,() => dartInstance.exports._12801(f)),
_12802: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12802(f,x0,x1)),
_12803: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12803(f,x0,x1)),
_12804: f => finalizeWrapper(f,(x0,x1,x2) => dartInstance.exports._12804(f,x0,x1,x2)),
_12805: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12805(f,x0,x1)),
_12806: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12806(f,x0,x1)),
_12807: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12807(f,x0,x1)),
_12808: f => finalizeWrapper(f,() => dartInstance.exports._12808(f)),
_12809: f => finalizeWrapper(f,() => dartInstance.exports._12809(f)),
_12810: f => finalizeWrapper(f,(x0,x1,x2) => dartInstance.exports._12810(f,x0,x1,x2)),
_12811: f => finalizeWrapper(f,x0 => dartInstance.exports._12811(f,x0)),
_12812: f => finalizeWrapper(f,x0 => dartInstance.exports._12812(f,x0)),
_12813: f => finalizeWrapper(f,x0 => dartInstance.exports._12813(f,x0)),
_12814: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12814(f,x0,x1)),
_12815: f => finalizeWrapper(f,() => dartInstance.exports._12815(f)),
_12816: f => finalizeWrapper(f,() => dartInstance.exports._12816(f)),
_12817: f => finalizeWrapper(f,x0 => dartInstance.exports._12817(f,x0)),
_12818: f => finalizeWrapper(f,() => dartInstance.exports._12818(f)),
_12819: f => finalizeWrapper(f,() => dartInstance.exports._12819(f)),
_12820: f => finalizeWrapper(f,() => dartInstance.exports._12820(f)),
_12821: f => finalizeWrapper(f,() => dartInstance.exports._12821(f)),
_12822: f => finalizeWrapper(f,() => dartInstance.exports._12822(f)),
_12823: f => finalizeWrapper(f,() => dartInstance.exports._12823(f)),
_12824: f => finalizeWrapper(f,(x0,x1,x2) => dartInstance.exports._12824(f,x0,x1,x2)),
_12825: f => finalizeWrapper(f,() => dartInstance.exports._12825(f)),
_12826: f => finalizeWrapper(f,x0 => dartInstance.exports._12826(f,x0)),
_12827: f => finalizeWrapper(f,x0 => dartInstance.exports._12827(f,x0)),
_12828: f => finalizeWrapper(f,(x0,x1,x2) => dartInstance.exports._12828(f,x0,x1,x2)),
_12829: f => finalizeWrapper(f,x0 => dartInstance.exports._12829(f,x0)),
_12830: f => finalizeWrapper(f,x0 => dartInstance.exports._12830(f,x0)),
_12831: f => finalizeWrapper(f,(x0,x1,x2,x3,x4,x5,x6) => dartInstance.exports._12831(f,x0,x1,x2,x3,x4,x5,x6)),
_12832: f => finalizeWrapper(f,x0 => dartInstance.exports._12832(f,x0)),
_12833: f => finalizeWrapper(f,(x0,x1,x2,x3) => dartInstance.exports._12833(f,x0,x1,x2,x3)),
_12834: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12834(f,x0,x1)),
_12835: f => finalizeWrapper(f,(x0,x1,x2,x3,x4) => dartInstance.exports._12835(f,x0,x1,x2,x3,x4)),
_12836: f => finalizeWrapper(f,(x0,x1,x2,x3,x4) => dartInstance.exports._12836(f,x0,x1,x2,x3,x4)),
_12837: f => finalizeWrapper(f,(x0,x1,x2,x3,x4,x5) => dartInstance.exports._12837(f,x0,x1,x2,x3,x4,x5)),
_12838: f => finalizeWrapper(f,(x0,x1,x2) => dartInstance.exports._12838(f,x0,x1,x2)),
_12839: f => finalizeWrapper(f,x0 => dartInstance.exports._12839(f,x0)),
_12840: f => finalizeWrapper(f,(x0,x1,x2) => dartInstance.exports._12840(f,x0,x1,x2)),
_12841: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12841(f,x0,x1)),
_12842: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12842(f,x0,x1)),
_12843: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12843(f,x0,x1)),
_12844: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12844(f,x0,x1)),
_12845: f => finalizeWrapper(f,x0 => dartInstance.exports._12845(f,x0)),
_12846: f => finalizeWrapper(f,() => dartInstance.exports._12846(f)),
_12847: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12847(f,x0,x1)),
_12848: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12848(f,x0,x1)),
_12849: f => finalizeWrapper(f,(x0,x1) => dartInstance.exports._12849(f,x0,x1)),
_12850: f => finalizeWrapper(f,x0 => dartInstance.exports._12850(f,x0)),
_12851: f => finalizeWrapper(f,x0 => dartInstance.exports._12851(f,x0)),
_12852: f => finalizeWrapper(f,x0 => dartInstance.exports._12852(f,x0)),
_12853: f => finalizeWrapper(f,x0 => dartInstance.exports._12853(f,x0)),
_12854: f => finalizeWrapper(f,() => dartInstance.exports._12854(f)),
_12868: (ms, c) =>
              setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
_12872: (c) =>
              queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
_12874: (a, i) => a.push(i),
_12885: a => a.length,
_12887: (a, i) => a[i],
_12888: (a, i, v) => a[i] = v,
_12890: a => a.join(''),
_12900: (s, p, i) => s.indexOf(p, i),
_12903: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
_12904: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
_12905: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
_12906: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
_12907: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
_12908: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
_12909: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
_12912: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
_12913: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
_12918: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
_12922: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
_12923: (b, o) => new DataView(b, o),
_12925: Function.prototype.call.bind(DataView.prototype.getUint8),
_12927: Function.prototype.call.bind(DataView.prototype.getInt8),
_12929: Function.prototype.call.bind(DataView.prototype.getUint16),
_12931: Function.prototype.call.bind(DataView.prototype.getInt16),
_12933: Function.prototype.call.bind(DataView.prototype.getUint32),
_12935: Function.prototype.call.bind(DataView.prototype.getInt32),
_12941: Function.prototype.call.bind(DataView.prototype.getFloat32),
_12943: Function.prototype.call.bind(DataView.prototype.getFloat64),
_12962: (x0,x1,x2) => x0[x1] = x2,
_12964: o => o === undefined,
_12965: o => typeof o === 'boolean',
_12966: o => typeof o === 'number',
_12968: o => typeof o === 'string',
_12971: o => o instanceof Int8Array,
_12972: o => o instanceof Uint8Array,
_12973: o => o instanceof Uint8ClampedArray,
_12974: o => o instanceof Int16Array,
_12975: o => o instanceof Uint16Array,
_12976: o => o instanceof Int32Array,
_12977: o => o instanceof Uint32Array,
_12978: o => o instanceof Float32Array,
_12979: o => o instanceof Float64Array,
_12980: o => o instanceof ArrayBuffer,
_12981: o => o instanceof DataView,
_12982: o => o instanceof Array,
_12983: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
_12987: (l, r) => l === r,
_12988: o => o,
_12989: o => o,
_12990: o => o,
_12991: b => !!b,
_12992: o => o.length,
_12995: (o, i) => o[i],
_12996: f => f.dartFunction,
_12997: l => arrayFromDartList(Int8Array, l),
_12998: l => arrayFromDartList(Uint8Array, l),
_12999: l => arrayFromDartList(Uint8ClampedArray, l),
_13000: l => arrayFromDartList(Int16Array, l),
_13001: l => arrayFromDartList(Uint16Array, l),
_13002: l => arrayFromDartList(Int32Array, l),
_13003: l => arrayFromDartList(Uint32Array, l),
_13004: l => arrayFromDartList(Float32Array, l),
_13005: l => arrayFromDartList(Float64Array, l),
_13006: (data, length) => {
          const view = new DataView(new ArrayBuffer(length));
          for (let i = 0; i < length; i++) {
              view.setUint8(i, dartInstance.exports.$byteDataGetUint8(data, i));
          }
          return view;
        },
_13007: l => arrayFromDartList(Array, l),
_13008: stringFromDartString,
_13009: stringToDartString,
_13010: () => ({}),
_13012: l => new Array(l),
_13013: () => globalThis,
_13014: (constructor, args) => {
      const factoryFunction = constructor.bind.apply(
          constructor, [null, ...args]);
      return new factoryFunction();
    },
_13016: (o, p) => o[p],
_13018: (o, m, a) => o[m].apply(o, a),
_13020: o => String(o),
_13021: (p, s, f) => p.then(s, f),
_13040: (o, p) => o[p],
_13041: (o, p, v) => o[p] = v
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

