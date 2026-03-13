package com.example.safeher

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

/**
 * An AccessibilityService that listens for volume-down key presses system-wide.
 * When 3 presses are detected within 2 seconds, it triggers SOS automatically.
 * This works even when the app is minimized / in the background.
 */
class VolumeAccessibilityService : AccessibilityService() {

    companion object {
        private const val REQUIRED_PRESSES = 3
        private const val TIME_WINDOW_MS = 2000L  // 2 seconds
    }

    private val pressTimestamps = mutableListOf<Long>()

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo()
        info.flags = AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        serviceInfo = info
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN && event.action == KeyEvent.ACTION_DOWN) {
            val now = System.currentTimeMillis()

            // Remove old presses outside the time window
            pressTimestamps.removeAll { now - it > TIME_WINDOW_MS }
            pressTimestamps.add(now)

            if (pressTimestamps.size >= REQUIRED_PRESSES) {
                pressTimestamps.clear()
                onTriplePressDetected()
            }
            // Don't consume the event so volume still works normally
            // (returning true would block the volume change)
        }
        return false
    }

    private fun onTriplePressDetected() {
        Toast.makeText(this, "🚨 SOS Triggered!", Toast.LENGTH_LONG).show()
        SosHelper.triggerSos(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not used — we only need key events
    }

    override fun onInterrupt() {
        // Required override
    }
}
