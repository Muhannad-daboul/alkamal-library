package com.example.alkamal_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.alkamal/flavor")
            .setMethodCallHandler { call, result ->
                if (call.method == "getFlavor") result.success(BuildConfig.FLAVOR)
                else result.notImplemented()
            }
    }
}
