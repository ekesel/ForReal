package com.forreal.app

import com.forreal.app.capture.CaptureChannel
import com.forreal.app.capture.CaptureDispatcher
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var capture: CaptureChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        capture = CaptureChannel(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            activity = { this },
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        capture?.dispose()
        capture = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onStart() {
        super.onStart()
        CaptureDispatcher.appVisible = true
    }

    override fun onStop() {
        CaptureDispatcher.appVisible = false
        super.onStop()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (capture?.onRequestPermissionsResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
