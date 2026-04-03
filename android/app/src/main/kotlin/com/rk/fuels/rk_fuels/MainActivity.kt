package com.rk.fuels.rk_fuels

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.rk.fuels.rk_fuels/native_config"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getDefaultWebClientId") {
                val resId = resources.getIdentifier(
                    "default_web_client_id",
                    "string",
                    packageName
                )
                if (resId != 0) {
                    result.success(getString(resId))
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
