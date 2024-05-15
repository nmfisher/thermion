package app.polyvox.flutter_filament_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.TransparencyMode

class MainActivity: FlutterActivity() {
    override fun getTransparencyMode(): TransparencyMode {
        return TransparencyMode.transparent
    }
}
