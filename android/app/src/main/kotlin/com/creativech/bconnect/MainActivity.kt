package com.creativech.bconnect

import android.bluetooth.BluetoothAdapter
import android.content.Intent
import android.os.Build
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.bconnect/bluetooth"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.creativech.bconnect/color_show")
            .setMethodCallHandler { call, result ->
                if (call.method == "setActive") {
                    val active = call.arguments == true
                    if (active) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        window.insetsController?.let { controller ->
                            if (active) {
                                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                                controller.hide(WindowInsets.Type.systemBars())
                            } else {
                                controller.show(WindowInsets.Type.systemBars())
                            }
                        }
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
            when (call.method) {
                "enableBluetooth" -> {
                    if (bluetoothAdapter == null) {
                        result.error("UNSUPPORTED", "Bluetooth not supported on this device", null)
                    } else if (!bluetoothAdapter.isEnabled) {
                        val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                        activity.startActivity(enableBtIntent)
                        result.success(true)
                    } else {
                        result.success(false) // Already enabled
                    }
                }
                "isBluetoothEnabled" -> {
                    if (bluetoothAdapter == null) {
                        result.success(false)
                    } else {
                        result.success(bluetoothAdapter.isEnabled)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
