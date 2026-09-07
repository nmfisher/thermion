import 'js_interop.dart';

(Pointer<TNativeMatrix4>, Float64List) allocateNativeMatrixStorage() {
  final owner = NativeMatrix4_create();
  final data = NativeMatrix4_getData(owner);
  final values = (Float64ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, data, 16) as JSFloat64Array).toDart;
  return (owner, values);
}
