import 'js_interop.dart';

Float64List nativeMatrixStorage(Pointer<TMat4> owner) {
  final data = Mat4_getData(owner);
  final values = (Float64ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, data, 16) as JSFloat64Array).toDart;
  return values;
}
