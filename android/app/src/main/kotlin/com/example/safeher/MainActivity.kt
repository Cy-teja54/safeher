package com.example.safeher

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.telephony.SmsManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.safeher/native_comm"
    private val VOLUME_EVENT_CHANNEL = "com.example.safeher/volume_events"

    private var volumeEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Method Channel for SMS, Call & Accessibility ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        val message = call.argument<String>("message")
                        if (phoneNumber != null && message != null) {
                            val success = SosHelper.sendSms(this, phoneNumber, message)
                            if (success) result.success(true)
                            else result.error("SMS_ERROR", "Failed to send SMS", null)
                        } else {
                            result.error("INVALID_ARGS", "Phone number and message required", null)
                        }
                    }
                    "makeDirectCall" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        if (phoneNumber != null) {
                            val success = SosHelper.makeCall(this, phoneNumber)
                            if (success) result.success(true)
                            else result.error("CALL_ERROR", "Failed to place call", null)
                        } else {
                            result.error("INVALID_ARGS", "Phone number required", null)
                        }
                    }
                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "openAccessibilitySettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Event Channel for volume button presses (foreground) ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    volumeEventSink = null
                }
            })
    }

    // ── Intercept hardware volume button presses (foreground only) ──
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            volumeEventSink?.success("volume_down")
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    // ── Check if our AccessibilityService is enabled ──
    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "$packageName/${VolumeAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains(serviceName)
    }
}
