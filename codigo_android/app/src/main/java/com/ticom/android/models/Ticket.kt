package com.ticom.android.models

import kotlinx.serialization.Serializable
import java.util.*

/**
 * Represents a ticket in the Ticom application
 * Equivalent to the Swift Ticket struct
 */
@Serializable
data class Ticket(
    val id: String = UUID.randomUUID().toString(),
    val filepath: String,
    val fecha: Long, // Date stored as timestamp
    val tipo: String, // "entrada", "salida" or "desconocido"
    val uniqueCode: String
) {
    // imageData will be loaded dynamically from filepath when needed
    fun getImageData(): ByteArray? {
        return try {
            val file = java.io.File(filepath)
            if (file.exists()) {
                file.readBytes()
            } else null
        } catch (e: Exception) {
            null
        }
    }
    
    fun getDate(): Date = Date(fecha)
    
    companion object {
        const val TIPO_ENTRADA = "entrada"
        const val TIPO_SALIDA = "salida"
        const val TIPO_DESCONOCIDO = "desconocido"
    }
}