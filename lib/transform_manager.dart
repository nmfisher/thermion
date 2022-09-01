
// import 'package:flutter/widgets.dart';
// import 'package:polyvox_filament/filament_controller.dart';
// import 'package:polyvox_filament/filament_controller.dart';
// import 'package:vector_math/vector_math_64.dart';

// class Position {
//   final double x;
//   final double y;
//   final double z;
//   Position(this.x, this.y, this.z);
//   Position copy({double? x, double? y, double? z}) {
//     return Position(x ?? this.x, y ?? this.y, z ?? this.z);
//   }
  
//   factory Position.zero() { 
//     return Position(0,0,0);
//   }
// }

// class Rotation {
//   final double rads;
//   final double x;
//   final double y;
//   final double z;
//   Rotation(this.x, this.y, this.z, this.rads);
//   Rotation copy({double? rads, double? x, double? y, double? z}) {
//     return Rotation(x ?? this.x, y ?? this.y, z ?? this.z, rads ?? this.rads);
//   }

//   factory Rotation.zero() { 
//     return Rotation(0, 1,0,0);
//   }

// }



// /// 
// /// Handles local transforms for assets/cameras.
// /// 
// class TransformManager {

//   final FilamentController _controller;

//   Matrix4 transform = Matrix4.identity();

//   TransformManager(this._controller);

//   void scale(double scale) {
//     transform.scale(scale, scale, scale);
//   }

  
//   void translate(double x, double y, double z) {
//     transform.translate(x,y,z);
//   }

//   void rotate(double x, double y, double z) {
//     transform.rotate(Vector3(x,y,z));
//   }

// }