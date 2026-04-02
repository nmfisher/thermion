import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

// A special type of [ThermionAsset] that duplicates the geometry of 
// an underlying asset to shade the edges/vertices/faces.
// 
abstract class WireframeAsset<T extends NativeHandle> extends ThermionAsset<T> {
  
  Future setWireframeVisibility(bool enabled);
  Future setAssetVisibility(bool enabled);

}
