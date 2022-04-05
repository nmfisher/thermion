package app.polyvox.filament

import io.flutter.plugin.common.BinaryMessenger
import android.app.Activity

import android.content.Context
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class FilamentViewFactory(
    private val activity: Activity,
    private val binaryMessenger: BinaryMessenger 
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String?, Any?>?
        return FilamentView(viewId, context!!, activity, binaryMessenger, creationParams)
    }
}