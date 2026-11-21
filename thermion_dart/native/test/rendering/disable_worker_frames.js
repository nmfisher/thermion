// Model a background tab: worker rendering callbacks never fire. Commands and
// shutdown must still complete using event notifications, without Dart polling.
if (typeof window === 'undefined') {
  globalThis.requestAnimationFrame = () => 0;
}
