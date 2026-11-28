package kr.ac.hansung.keepy.dohyeon

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "keepy/ocr_cache")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "cachePath" -> result.success(cacheDir.absolutePath)
                    else -> result.notImplemented()
                }
            }
    }
}
