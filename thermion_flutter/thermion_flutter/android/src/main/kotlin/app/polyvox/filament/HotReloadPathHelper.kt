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
            val packagePath = "/data/user/0/${packageName}/code_cache/"
            Log.v("thermion_flutter", "Looking for hot reloaded asset ${path} under package path ${packagePath}")
            val files = File(packagePath).walkBottomUp().filter {
              it.path.endsWith(path)
            }.sortedBy {
              it.lastModified()
            }.toList()
            if(files.size > 0) {
              Log.v("thermion_flutter", "Using hot reloaded asset at ${files.last().path}")
              return files.last().path;
            }
            Log.v("thermion_flutter", "No hot reloaded asset found.")
            return null;
          }
    }
}