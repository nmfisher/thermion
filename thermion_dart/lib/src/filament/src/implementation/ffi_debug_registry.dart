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
    final cName = name.toNativeUtf8();
    try {
      return DebugRegistry_hasProperty(debugRegistry, cName.cast());
    } finally {
      malloc.free(cName);
    }
  }

  @override
  bool setPropertyBool(String name, bool value) {
    final cName = name.toNativeUtf8();
    try {
      return DebugRegistry_setProperty_bool(debugRegistry, cName.cast(), value);
    } finally {
      malloc.free(cName);
    }
  }

  @override
  bool setPropertyInt(String name, int value) {
    final cName = name.toNativeUtf8();
    try {
      return DebugRegistry_setProperty_int(debugRegistry, cName.cast(), value);
    } finally {
      malloc.free(cName);
    }
  }

  @override
  bool setPropertyFloat(String name, double value) {
    final cName = name.toNativeUtf8();
    try {
      return DebugRegistry_setProperty_float(debugRegistry, cName.cast(), value);
    } finally {
      malloc.free(cName);
    }
  }

  @override
  bool? getPropertyBool(String name) {
    final cName = name.toNativeUtf8();
    final outValue = malloc<Bool>();
    try {
      final success =
          DebugRegistry_getProperty_bool(debugRegistry, cName.cast(), outValue);
      if (!success) {
        return null;
      }
      return outValue.value;
    } finally {
      malloc.free(cName);
      malloc.free(outValue);
    }
  }

  @override
  int? getPropertyInt(String name) {
    final cName = name.toNativeUtf8();
    final outValue = malloc<Int>();
    try {
      final success =
          DebugRegistry_getProperty_int(debugRegistry, cName.cast(), outValue);
      if (!success) {
        return null;
      }
      return outValue.value;
    } finally {
      malloc.free(cName);
      malloc.free(outValue);
    }
  }

  @override
  double? getPropertyFloat(String name) {
    final cName = name.toNativeUtf8();
    final outValue = malloc<Float>();
    try {
      final success = DebugRegistry_getProperty_float(
          debugRegistry, cName.cast(), outValue);
      if (!success) {
        return null;
      }
      return outValue.value;
    } finally {
      malloc.free(cName);
      malloc.free(outValue);
    }
  }
}
