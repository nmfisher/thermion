import 'package:animation_tools_dart/src/bone_animation_data.dart';
import 'package:animation_tools_dart/src/morph_animation_data.dart';
import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';
import 'package:dart_filament/dart_filament/entities/filament_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_filament/filament/flutter_filament_plugin.dart';
import 'package:vector_math/vector_math_64.dart';

// class FooViewer extends AbstractFilamentViewer {
//   @override
//   Future addAnimationComponent(FilamentEntity entity) {
//     // TODO: implement addAnimationComponent
//     throw UnimplementedError();
//   }

//   @override
//   Future addBoneAnimation(FilamentEntity entity, BoneAnimationData animation) {
//     // TODO: implement addBoneAnimation
//     throw UnimplementedError();
//   }

//   @override
//   Future addCollisionComponent(FilamentEntity entity, {void Function(int entityId1, int entityId2)? callback, bool affectsTransform = false}) {
//     // TODO: implement addCollisionComponent
//     throw UnimplementedError();
//   }

//   @override
//   Future<FilamentEntity> addLight(int type, double colour, double intensity, double posX, double posY, double posZ, double dirX, double dirY, double dirZ, bool castShadows) {
//     // TODO: implement addLight
//     throw UnimplementedError();
//   }

//   @override
//   Future clearBackgroundImage() {
//     // TODO: implement clearBackgroundImage
//     throw UnimplementedError();
//   }

//   @override
//   Future clearEntities() {
//     // TODO: implement clearEntities
//     throw UnimplementedError();
//   }

//   @override
//   Future clearLights() {
//     // TODO: implement clearLights
//     throw UnimplementedError();
//   }

//   @override
//   Future createGeometry(List<double> vertices, List<int> indices, {String? materialPath, PrimitiveType primitiveType = PrimitiveType.TRIANGLES}) {
//     // TODO: implement createGeometry
//     throw UnimplementedError();
//   }

//   @override
//   Future<FilamentEntity> createInstance(FilamentEntity entity) {
//     // TODO: implement createInstance
//     throw UnimplementedError();
//   }

//   @override
//   Future dispose() {
//     // TODO: implement dispose
//     throw UnimplementedError();
//   }

//   @override
//   Future<double> getAnimationDuration(FilamentEntity entity, int animationIndex) {
//     // TODO: implement getAnimationDuration
//     throw UnimplementedError();
//   }

//   @override
//   Future<List<String>> getAnimationNames(FilamentEntity entity) {
//     // TODO: implement getAnimationNames
//     throw UnimplementedError();
//   }

//   @override
//   Future<double> getCameraCullingFar() {
//     // TODO: implement getCameraCullingFar
//     throw UnimplementedError();
//   }

//   @override
//   Future<double> getCameraCullingNear() {
//     // TODO: implement getCameraCullingNear
//     throw UnimplementedError();
//   }

//   @override
//   Future<Matrix4> getCameraCullingProjectionMatrix() {
//     // TODO: implement getCameraCullingProjectionMatrix
//     throw UnimplementedError();
//   }

//   @override
//   Future<Frustum> getCameraFrustum() {
//     // TODO: implement getCameraFrustum
//     throw UnimplementedError();
//   }

//   @override
//   Future<Matrix4> getCameraModelMatrix() {
//     // TODO: implement getCameraModelMatrix
//     throw UnimplementedError();
//   }

//   @override
//   Future<Vector3> getCameraPosition() {
//     // TODO: implement getCameraPosition
//     throw UnimplementedError();
//   }

//   @override
//   Future<Matrix4> getCameraProjectionMatrix() {
//     // TODO: implement getCameraProjectionMatrix
//     throw UnimplementedError();
//   }

//   @override
//   Future<Matrix3> getCameraRotation() {
//     // TODO: implement getCameraRotation
//     throw UnimplementedError();
//   }

//   @override
//   Future<Matrix4> getCameraViewMatrix() {
//     // TODO: implement getCameraViewMatrix
//     throw UnimplementedError();
//   }

//   @override
//   Future<List<FilamentEntity>> getChildEntities(FilamentEntity parent, bool renderableOnly) {
//     // TODO: implement getChildEntities
//     throw UnimplementedError();
//   }

//   @override
//   Future<FilamentEntity> getChildEntity(FilamentEntity parent, String childName) {
//     // TODO: implement getChildEntity
//     throw UnimplementedError();
//   }

//   @override
//   Future<List<String>> getChildEntityNames(FilamentEntity entity, {bool renderableOnly = true}) {
//     // TODO: implement getChildEntityNames
//     throw UnimplementedError();
//   }

//   @override
//   Future<int> getInstanceCount(FilamentEntity entity) {
//     // TODO: implement getInstanceCount
//     throw UnimplementedError();
//   }

//   @override
//   Future<List<FilamentEntity>> getInstances(FilamentEntity entity) {
//     // TODO: implement getInstances
//     throw UnimplementedError();
//   }

//   @override
//   Future<FilamentEntity> getMainCamera() {
//     // TODO: implement getMainCamera
//     throw UnimplementedError();
//   }

//   @override
//   Future<List<String>> getMorphTargetNames(FilamentEntity entity, String meshName) {
//     // TODO: implement getMorphTargetNames
//     throw UnimplementedError();
//   }

//   @override
//   String? getNameForEntity(FilamentEntity entity) {
//     // TODO: implement getNameForEntity
//     throw UnimplementedError();
//   }

//   @override
//   Future hide(FilamentEntity entity, String? meshName) {
//     // TODO: implement hide
//     throw UnimplementedError();
//   }

//   @override
//   Future<FilamentEntity> loadGlb(String path, {int numInstances = 1}) {
//     // TODO: implement loadGlb
//     throw UnimplementedError();
//   }

//   @override
//   Future<FilamentEntity> loadGltf(String path, String relativeResourcePath, {bool force = false}) {
//     // TODO: implement loadGltf
//     throw UnimplementedError();
//   }

//   @override
//   Future loadIbl(String lightingPath, {double intensity = 30000}) {
//     // TODO: implement loadIbl
//     throw UnimplementedError();
//   }

//   @override
//   Future loadSkybox(String skyboxPath) {
//     // TODO: implement loadSkybox
//     throw UnimplementedError();
//   }

//   @override
//   Future moveCameraToAsset(FilamentEntity entity) {
//     // TODO: implement moveCameraToAsset
//     throw UnimplementedError();
//   }

//   @override
//   Future panEnd() {
//     // TODO: implement panEnd
//     throw UnimplementedError();
//   }

//   @override
//   Future panStart(double x, double y) {
//     // TODO: implement panStart
//     throw UnimplementedError();
//   }

//   @override
//   Future panUpdate(double x, double y) {
//     // TODO: implement panUpdate
//     throw UnimplementedError();
//   }

//   @override
//   void pick(int x, int y) {
//     // TODO: implement pick
//   }

//   @override
//   // TODO: implement pickResult
//   Stream<FilamentPickResult> get pickResult => throw UnimplementedError();

//   @override
//   Future playAnimation(FilamentEntity entity, int index, {bool loop = false, bool reverse = false, bool replaceActive = true, double crossfade = 0.0}) {
//     // TODO: implement playAnimation
//     throw UnimplementedError();
//   }

//   @override
//   Future playAnimationByName(FilamentEntity entity, String name, {bool loop = false, bool reverse = false, bool replaceActive = true, double crossfade = 0.0}) {
//     // TODO: implement playAnimationByName
//     throw UnimplementedError();
//   }

//   @override
//   Future queuePositionUpdate(FilamentEntity entity, double x, double y, double z, {bool relative = false}) {
//     // TODO: implement queuePositionUpdate
//     throw UnimplementedError();
//   }

//   @override
//   Future queueRotationUpdate(FilamentEntity entity, double rads, double x, double y, double z, {bool relative = false}) {
//     // TODO: implement queueRotationUpdate
//     throw UnimplementedError();
//   }

//   @override
//   Future queueRotationUpdateQuat(FilamentEntity entity, Quaternion quat, {bool relative = false}) {
//     // TODO: implement queueRotationUpdateQuat
//     throw UnimplementedError();
//   }

//   @override
//   Future removeCollisionComponent(FilamentEntity entity) {
//     // TODO: implement removeCollisionComponent
//     throw UnimplementedError();
//   }

//   @override
//   Future removeEntity(FilamentEntity entity) {
//     // TODO: implement removeEntity
//     throw UnimplementedError();
//   }

//   @override
//   Future removeIbl() {
//     // TODO: implement removeIbl
//     throw UnimplementedError();
//   }

//   @override
//   Future removeLight(FilamentEntity light) {
//     // TODO: implement removeLight
//     throw UnimplementedError();
//   }

//   @override
//   Future removeSkybox() {
//     // TODO: implement removeSkybox
//     throw UnimplementedError();
//   }

//   @override
//   Future render() {
//     // TODO: implement render
//     throw UnimplementedError();
//   }

//   @override
//   // TODO: implement rendering
//   bool get rendering => throw UnimplementedError();

//   @override
//   Future resetBones(FilamentEntity entity) {
//     // TODO: implement resetBones
//     throw UnimplementedError();
//   }

//   @override
//   Future reveal(FilamentEntity entity, String? meshName) {
//     // TODO: implement reveal
//     throw UnimplementedError();
//   }

//   @override
//   Future rotateEnd() {
//     // TODO: implement rotateEnd
//     throw UnimplementedError();
//   }

//   @override
//   Future rotateIbl(Matrix3 rotation) {
//     // TODO: implement rotateIbl
//     throw UnimplementedError();
//   }

//   @override
//   Future rotateStart(double x, double y) {
//     // TODO: implement rotateStart
//     throw UnimplementedError();
//   }

//   @override
//   Future rotateUpdate(double x, double y) {
//     // TODO: implement rotateUpdate
//     throw UnimplementedError();
//   }

//   @override
//   Future setAnimationFrame(FilamentEntity entity, int index, int animationFrame) {
//     // TODO: implement setAnimationFrame
//     throw UnimplementedError();
//   }

//   @override
//   Future setAntiAliasing(bool msaa, bool fxaa, bool taa) {
//     // TODO: implement setAntiAliasing
//     throw UnimplementedError();
//   }

//   @override
//   Future setBackgroundColor(double r, double g, double b, double alpha) {
//     // TODO: implement setBackgroundColor
//     throw UnimplementedError();
//   }

//   @override
//   Future setBackgroundImage(String path, {bool fillHeight = false}) {
//     // TODO: implement setBackgroundImage
//     throw UnimplementedError();
//   }

//   @override
//   Future setBackgroundImagePosition(double x, double y, {bool clamp = false}) {
//     // TODO: implement setBackgroundImagePosition
//     throw UnimplementedError();
//   }

//   @override
//   Future setBloom(double bloom) {
//     // TODO: implement setBloom
//     throw UnimplementedError();
//   }

//   @override
//   Future setCamera(FilamentEntity entity, String? name) {
//     // TODO: implement setCamera
//     throw UnimplementedError();
//   }

//   @override
//   Future setCameraCulling(double near, double far) {
//     // TODO: implement setCameraCulling
//     throw UnimplementedError();
//   }

//   @override
//   Future setCameraExposure(double aperture, double shutterSpeed, double sensitivity) {
//     // TODO: implement setCameraExposure
//     throw UnimplementedError();
//   }

//   @override
//   Future setCameraFocalLength(double focalLength) {
//     // TODO: implement setCameraFocalLength
//     throw UnimplementedError();
//   }

//   @override
//   Future setCameraFocusDistance(double focusDistance) {
//     // TODO: implement setCameraFocusDistance
//     throw UnimplementedError();
//   }

//   @override
//   Future setCameraFov(double degrees, double width, double height) {
//     // TODO: implement setCameraFov
//     throw UnimplementedError();
//   }

//   @override
//   Future setCameraManipulatorOptions({ManipulatorMode mode = ManipulatorMode.ORBIT, double orbitSpeedX = 0.01, double orbitSpeedY = 0.01, double zoomSpeed = 0.01}) {
//     // TODO: implement setCameraManipulatorOptions
//     throw UnimplementedError();
//   }

//   @override
//   Future setCameraModelMatrix(List<double> matrix) {
//     // TODO: implement setCameraModelMatrix
//     throw UnimplementedError();
//   }

//   @override
//   Future setCameraPosition(double x, double y, double z) {
//     // TODO: implement setCameraPosition
//     throw UnimplementedError();
//   }

//   @override
//   Future setCameraRotation(Quaternion quaternion) {
//     // TODO: implement setCameraRotation
//     throw UnimplementedError();
//   }

//   @override
//   Future setFrameRate(int framerate) {
//     // TODO: implement setFrameRate
//     throw UnimplementedError();
//   }

//   @override
//   Future setMainCamera() {
//     // TODO: implement setMainCamera
//     throw UnimplementedError();
//   }

//   @override
//   Future setMaterialColor(FilamentEntity entity, String meshName, int materialIndex, double r, double g, double b, double a) {
//     // TODO: implement setMaterialColor
//     throw UnimplementedError();
//   }

//   @override
//   Future setMorphAnimationData(FilamentEntity entity, MorphAnimationData animation, {List<String>? targetMeshNames}) {
//     // TODO: implement setMorphAnimationData
//     throw UnimplementedError();
//   }

//   @override
//   Future setMorphTargetWeights(FilamentEntity entity, List<double> weights) {
//     // TODO: implement setMorphTargetWeights
//     throw UnimplementedError();
//   }

//   @override
//   Future setParent(FilamentEntity child, FilamentEntity parent) {
//     // TODO: implement setParent
//     throw UnimplementedError();
//   }

//   @override
//   Future setPosition(FilamentEntity entity, double x, double y, double z) {
//     // TODO: implement setPosition
//     throw UnimplementedError();
//   }

//   @override
//   Future setPostProcessing(bool enabled) {
//     // TODO: implement setPostProcessing
//     throw UnimplementedError();
//   }

//   @override
//   Future setPriority(FilamentEntity entityId, int priority) {
//     // TODO: implement setPriority
//     throw UnimplementedError();
//   }

//   @override
//   Future setRecording(bool recording) {
//     // TODO: implement setRecording
//     throw UnimplementedError();
//   }

//   @override
//   Future setRecordingOutputDirectory(String outputDirectory) {
//     // TODO: implement setRecordingOutputDirectory
//     throw UnimplementedError();
//   }

//   @override
//   Future setRendering(bool render) {
//     // TODO: implement setRendering
//     throw UnimplementedError();
//   }

//   @override
//   Future setRotation(FilamentEntity entity, double rads, double x, double y, double z) {
//     // TODO: implement setRotation
//     throw UnimplementedError();
//   }

//   @override
//   Future setRotationQuat(FilamentEntity entity, Quaternion rotation) {
//     // TODO: implement setRotationQuat
//     throw UnimplementedError();
//   }

//   @override
//   Future setScale(FilamentEntity entity, double scale) {
//     // TODO: implement setScale
//     throw UnimplementedError();
//   }

//   @override
//   Future setToneMapping(ToneMapper mapper) {
//     // TODO: implement setToneMapping
//     throw UnimplementedError();
//   }

//   @override
//   Future setViewFrustumCulling(bool enabled) {
//     // TODO: implement setViewFrustumCulling
//     throw UnimplementedError();
//   }

//   @override
//   Future stopAnimation(FilamentEntity entity, int animationIndex) {
//     // TODO: implement stopAnimation
//     throw UnimplementedError();
//   }

//   @override
//   Future stopAnimationByName(FilamentEntity entity, String name) {
//     // TODO: implement stopAnimationByName
//     throw UnimplementedError();
//   }

//   @override
//   Future testCollisions(FilamentEntity entity) {
//     // TODO: implement testCollisions
//     throw UnimplementedError();
//   }

//   @override
//   Future transformToUnitCube(FilamentEntity entity) {
//     // TODO: implement transformToUnitCube
//     throw UnimplementedError();
//   }

//   @override
//   Future zoomBegin() {
//     // TODO: implement zoomBegin
//     throw UnimplementedError();
//   }

//   @override
//   Future zoomEnd() {
//     // TODO: implement zoomEnd
//     throw UnimplementedError();
//   }

//   @override
//   Future zoomUpdate(double x, double y, double z) {
//     // TODO: implement zoomUpdate
//     throw UnimplementedError();
//   }

//   @override
//   // TODO: implement scene
//   Scene get scene => throw UnimplementedError();

// }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // late AbstractFilamentViewer viewer;
  int _counter = 0;

  void _incrementCounter() {
    final plugin = FlutterFilamentPlugin();

    // viewer = FooViewer();
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
