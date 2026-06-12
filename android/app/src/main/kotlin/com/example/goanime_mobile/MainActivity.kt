package com.example.goanime_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.res.Configuration

class MainActivity : FlutterActivity() {
    private val TV_DETECTOR_CHANNEL = "com.goanime.tv_detector"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_DETECTOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "isTV") {
                    val isTV = isTVDevice()
                    result.success(isTV)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun isTVDevice(): Boolean {
        return try {
            // Verifica UI_MODE_TYPE_TELEVISION
            val uiMode = resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
            val isTelevision = uiMode == Configuration.UI_MODE_TYPE_TELEVISION
            
            // Verifica se o dispositivo tem características de TV
            val hasTouchscreen = packageManager.hasSystemFeature("android.hardware.touchscreen")
            val hasDpad = packageManager.hasSystemFeature("android.hardware.navigation")
            
            // É TV se for UI_MODE_TYPE_TELEVISION ou não tiver touchscreen e tiver D-pad
            isTelevision || (!hasTouchscreen && hasDpad)
        } catch (e: Exception) {
            false
        }
    }
}