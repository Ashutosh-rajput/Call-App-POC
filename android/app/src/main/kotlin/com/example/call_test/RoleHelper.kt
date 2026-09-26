package com.example.call_test

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build

object RoleHelper {
    const val ROLE_SYSTEM_CALL_STREAMING = "android.app.role.SYSTEM_CALL_STREAMING"
    const val PERM_CALL_AUDIO_INTERCEPTION = "android.permission.CALL_AUDIO_INTERCEPTION"

    fun isRoleAvailable(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = context.getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return false
        return try {
            roleManager.isRoleAvailable(ROLE_SYSTEM_CALL_STREAMING)
        } catch (e: Exception) {
            false
        }
    }

    fun isRoleHeld(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = context.getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return false
        return try {
            roleManager.isRoleHeld(ROLE_SYSTEM_CALL_STREAMING)
        } catch (e: Exception) {
            false
        }
    }

    fun createRequestRoleIntent(context: Context): Intent? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val roleManager = context.getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return null
        return try {
            roleManager.createRequestRoleIntent(ROLE_SYSTEM_CALL_STREAMING)
        } catch (e: Exception) {
            null
        }
    }

    fun getAdbAddRoleCommand(packageName: String): String {
        return "adb shell cmd role add-role-holder --bypass-role-qualification $ROLE_SYSTEM_CALL_STREAMING $packageName"
    }

    fun getAdbRemoveRoleCommand(packageName: String): String {
        return "adb shell cmd role remove-role-holder --bypass-role-qualification $ROLE_SYSTEM_CALL_STREAMING $packageName"
    }

    fun getAdbGrantPermissionsCommand(packageName: String): List<String> {
        return listOf(
            "adb shell pm grant $packageName android.permission.RECORD_AUDIO",
            "adb shell pm grant $packageName $PERM_CALL_AUDIO_INTERCEPTION",
            "adb shell pm grant $packageName android.permission.READ_PHONE_STATE",
            "adb shell pm grant $packageName android.permission.MANAGE_OWN_CALLS"
        )
    }
}
