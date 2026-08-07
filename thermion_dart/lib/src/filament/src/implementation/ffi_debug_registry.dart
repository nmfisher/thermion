import 'package:thermion_dart/thermion_dart.dart';

class FFIDebugRegistry extends DebugRegistry<Pointer<TDebugRegistry>> {
  final Pointer<TDebugRegistry> debugRegistry;

  @override
  Pointer<TDebugRegistry> getNativeHandle() {
    return debugRegistry;
  }

  FFIDebugRegistry(this.debugRegistry);

  @override
  bool hasProperty(String name) {
    final ptr = name.toNativeUtf8();
    try {
      return DebugRegistry_hasProperty(debugRegistry, ptr.cast());
    } finally {
      free(ptr);
    }
  }

  @override
  bool setPropertyBool(String name, bool value) {
    final ptr = name.toNativeUtf8();
    try {
      return DebugRegistry_setProperty_bool(debugRegistry, ptr.cast(), value);
    } finally {
      free(ptr);
    }
  }

  @override
  bool setPropertyInt(String name, int value) {
    final ptr = name.toNativeUtf8();
    try {
      return DebugRegistry_setProperty_int(debugRegistry, ptr.cast(), value);
    } finally {
      free(ptr);
    }
  }

  @override
  bool setPropertyFloat(String name, double value) {
    final ptr = name.toNativeUtf8();
    try {
      return DebugRegistry_setProperty_float(debugRegistry, ptr.cast(), value);
    } finally {
      free(ptr);
    }
  }

  @override
  bool? getPropertyBool(String name) {
    final ptr = name.toNativeUtf8();
    try {
      final outValue = makeInt32List(1);

      final success = DebugRegistry_getProperty_bool(debugRegistry, ptr.cast(), outValue.address.cast());
      if (!success) {
        return null;
      }
      return outValue[0] == 1;
    } finally {
      free(ptr);
    }
  }

  @override
  int? getPropertyInt(String name) {
    final ptr = name.toNativeUtf8();
    try {
      final outValue = Int32List(1);

      final success = DebugRegistry_getProperty_int(debugRegistry, ptr.cast(), outValue.address.cast());
      if (!success) {
        return null;
      }
      return outValue[0];
    } finally {
      free(ptr);
    }
  }

  @override
  double? getPropertyFloat(String name) {
    final ptr = name.toNativeUtf8();
    try {
      final outValue = Float32List(1);

      final success = DebugRegistry_getProperty_float(debugRegistry, ptr.cast(), outValue.address);
      if (!success) {
        return null;
      }
      return outValue[0];
    } finally {
      free(ptr);
    }
  }
}
