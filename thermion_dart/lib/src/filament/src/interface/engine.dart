enum Backend {
  /// !< Automatically selects an appropriate driver for the platform.
  DEFAULT(0),

  /// !< Selects the OpenGL/ES driver (default on Android)
  OPENGL(1),

  /// !< Selects the Vulkan driver if the platform supports it (default on Linux/Windows)
  VULKAN(2),

  /// !< Selects the Metal driver if the platform supports it (default on MacOS/iOS).
  METAL(3),

  /// !< Selects the no-op driver for testing purposes.
  NOOP(4);

  final int value;
  const Backend(this.value);

  static Backend fromValue(int value) => switch (value) {
        0 => DEFAULT,
        1 => OPENGL,
        2 => VULKAN,
        3 => METAL,
        4 => NOOP,
        _ => throw ArgumentError("Unknown value for TBackend: $value"),
      };
}

enum FeatureLevel {
  FeatureLevel0(0),
  FeatureLevel1(1),
  FeatureLevel2(2),
  FeatureLevel3(3);

  final int value;
  const FeatureLevel(this.value);
}
