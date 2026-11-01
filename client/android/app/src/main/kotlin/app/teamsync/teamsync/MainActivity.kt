package app.teamsync.teamsync

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class TeamSyncMediaProvider : FileProvider()

class MainActivity : FlutterActivity() {
    private fun ownClip(path: String?): File {
        require(path != null)
        val root = File(filesDir, "media").canonicalFile
        val file = File(path).canonicalFile
        require(file.path.startsWith(root.path + File.separator))
        require(file.isFile && file.extension.lowercase() == "mp4")
        require(file.length() in 24L..(20L * 1024 * 1024))
        return file
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.teamsync/media")
            .setMethodCallHandler { call, result ->
                if (call.method !in listOf("openVideo", "canOpenVideo")) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val file = ownClip(call.argument<String>("path"))
                    val uri = FileProvider.getUriForFile(this, "$packageName.media", file)
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "video/mp4")
                        clipData = ClipData.newRawUri("TeamSync clip", uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    val available = intent.resolveActivity(packageManager) != null
                    if (call.method == "openVideo" && available) startActivity(intent)
                    result.success(available)
                } catch (_: ActivityNotFoundException) {
                    result.success(false)
                } catch (_: Exception) {
                    result.error("invalidMedia", "Media is unavailable", null)
                }
            }
    }
}
