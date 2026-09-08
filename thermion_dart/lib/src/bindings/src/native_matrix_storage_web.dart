import 'js_interop.dart';

(Pointer<TMat4>, Float64List) allocateNativeMatrixStorage() {
  final owner = Mat4_create();
  final data = Mat4_getData(owner);
  final values = (Float64ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, data, 16) as JSFloat64Array).toDart;
  return (owner, values);
}
