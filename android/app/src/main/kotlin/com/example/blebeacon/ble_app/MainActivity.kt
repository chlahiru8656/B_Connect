package com.example.blebeacon.ble_app

import android.bluetooth.BluetoothAdapter
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.bconnect/bluetooth"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
