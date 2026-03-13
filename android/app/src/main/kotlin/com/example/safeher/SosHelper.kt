package com.example.safeher

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.telephony.SmsManager
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.location.Location
import android.location.LocationManager

/**
 * Shared helper for sending SOS (SMS + call).
 * Used by both MainActivity (foreground) and VolumeAccessibilityService (background).
 */
object SosHelper {
    const val EMERGENCY_NUMBER = "+916302620295"

    /**
     * Sends an SOS SMS with the current location and places a direct call.
     */
    fun triggerSos(context: Context) {
        val location = getLastKnownLocation(context)
        val message = if (location != null) {
            "I need help! My location: https://maps.google.com/?q=${location.latitude},${location.longitude}"
        } else {
            "I need help! (Location unavailable)"
        }

        sendSms(context, EMERGENCY_NUMBER, message)
        makeCall(context, EMERGENCY_NUMBER)
    }

    fun sendSms(context: Context, phoneNumber: String, message: String): Boolean {
        return try {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS)
                == PackageManager.PERMISSION_GRANTED) {
                val smsManager = SmsManager.getDefault()
                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    fun makeCall(context: Context, phoneNumber: String): Boolean {
        return try {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.CALL_PHONE)
                == PackageManager.PERMISSION_GRANTED) {
                val intent = Intent(Intent.ACTION_CALL)
                intent.data = Uri.parse("tel:$phoneNumber")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun getLastKnownLocation(context: Context): Location? {
        return try {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
                return null
            }
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            // Try GPS first, then network
            locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                ?: locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
        } catch (e: Exception) {
            null
        }
    }
}
