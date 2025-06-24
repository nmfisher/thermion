/// A top-level interface for any object that need to be passed
/// across "native" boundaries (either via FFI or Javascript interop).
///
/// Currently, [T] must always be a [Pointer] (which is defined and implemented
/// differently depending on the target platform). However, T is unbounded so
/// this is never checked at compile-time (so getNativeHandle<Matrix4>() is 
/// not a compile-time error). 
///
abstract class NativeHandle<T> {
  T getNativeHandle<T>();
}
