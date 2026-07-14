import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';

/// A registry of runtime properties used exclusively for debugging.
///
/// Filament exposes a few properties that can be queried and set, which control certain debugging
/// features of the engine. These properties can be set at runtime at anytime.
///
abstract class DebugRegistry<T> extends NativeHandle<T> {
  /// Queries whether a property exists.
  ///
  /// [name] The name of the property to query.
  /// Returns true if the property exists, false otherwise.
  bool hasProperty(String name);

  /// Set the value of a boolean property.
  ///
  /// [name] Name of the property to set the value of.
  /// [value] Value to set.
  /// Returns true if the operation was successful, false otherwise.
  bool setPropertyBool(String name, bool value);

  /// Set the value of an integer property.
  ///
  /// [name] Name of the property to set the value of.
  /// [value] Value to set.
  /// Returns true if the operation was successful, false otherwise.
  bool setPropertyInt(String name, int value);

  /// Set the value of a float property.
  ///
  /// [name] Name of the property to set the value of.
  /// [value] Value to set.
  /// Returns true if the operation was successful, false otherwise.
  bool setPropertyFloat(String name, double value);

  /// Get the value of a boolean property.
  ///
  /// [name] Name of the property to get the value of.
  /// Returns the property value, or null if the property doesn't exist or has a different type.
  bool? getPropertyBool(String name);

  /// Get the value of an integer property.
  ///
  /// [name] Name of the property to get the value of.
  /// Returns the property value, or null if the property doesn't exist or has a different type.
  int? getPropertyInt(String name);

  /// Get the value of a float property.
  ///
  /// [name] Name of the property to get the value of.
  /// Returns the property value, or null if the property doesn't exist or has a different type.
  double? getPropertyFloat(String name);
}
