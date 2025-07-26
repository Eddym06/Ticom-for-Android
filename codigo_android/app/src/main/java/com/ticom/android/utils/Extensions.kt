package com.ticom.android.utils

import androidx.compose.ui.graphics.Color
import java.text.SimpleDateFormat
import java.util.*

/**
 * Extension functions for Date formatting
 * Equivalent to Swift Date extensions
 */
fun Date.formattedString(locale: Locale = Locale("es", "DO")): String {
    val formatter = SimpleDateFormat("dd 'de' MMMM 'de' yyyy", locale)
    return formatter.format(this)
}

/**
 * Extension functions for Color operations
 * Equivalent to Swift Color extensions
 */
fun Color.toHexString(): String {
    val red = (this.red * 255).toInt()
    val green = (this.green * 255).toInt()
    val blue = (this.blue * 255).toInt()
    return String.format("#%02X%02X%02X", red, green, blue)
}

fun String.toComposeColor(): Color {
    val hex = this.removePrefix("#")
    return when (hex.length) {
        3 -> {
            // RGB (12-bit)
            val r = hex.substring(0, 1).toInt(16) * 17
            val g = hex.substring(1, 2).toInt(16) * 17
            val b = hex.substring(2, 3).toInt(16) * 17
            Color(r / 255f, g / 255f, b / 255f)
        }
        6 -> {
            // RGB (24-bit)
            val r = hex.substring(0, 2).toInt(16)
            val g = hex.substring(2, 4).toInt(16)
            val b = hex.substring(4, 6).toInt(16)
            Color(r / 255f, g / 255f, b / 255f)
        }
        8 -> {
            // ARGB (32-bit)
            val a = hex.substring(0, 2).toInt(16)
            val r = hex.substring(2, 4).toInt(16)
            val g = hex.substring(4, 6).toInt(16)
            val b = hex.substring(6, 8).toInt(16)
            Color(r / 255f, g / 255f, b / 255f, a / 255f)
        }
        else -> Color.Black
    }
}