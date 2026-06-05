import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class WebGpu {
  static bool isSupported() {
    final navigator = globalContext.getProperty('navigator'.toJS);
    if (navigator == null) return false;
    final gpu = (navigator as JSObject).getProperty('gpu'.toJS);
    return gpu != null;
  }
}
