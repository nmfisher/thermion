import java.io.*
import java.nio.file.FileSystems
import java.nio.file.Files
import java.nio.file.Path
import kotlin.io.path.absolutePathString
import kotlin.io.path.listDirectoryEntries
import android.util.Log


class HotReloadPathHelper {
    companion object {
        fun getAssetPath(path: String, packageName: String): String? {
            // iterate over evr
            val shortName = packageName.split(".").last().split("_").last()
            val packagePath = "/data/user/0/${packageName}/code_cache/"
            Log.v("FFI", "Looking for shortName ${shortName} under package path ${packagePath}")
            val files = File(packagePath).listFiles().filter {
              it.path.split("/").last().startsWith(shortName)
            }.map {
              val f = File(it.path + "/${shortName}/build/${path}")
              Log.v("FFI", "Looking for ${f.path.toString()}")
              f
            }.filter {
              it.exists()
            }.sortedBy {
              Log.v("FFI", it.path.toString())
              it.lastModified()
            }
            Log.v("FFI", files.size.toString())
            if(files.size > 0)
                return files.first().path;
            return null;
          }
    }
}