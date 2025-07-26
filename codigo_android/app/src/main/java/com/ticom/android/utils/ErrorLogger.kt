package com.ticom.android.utils

import android.util.Log
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Error logger equivalent to Swift ErrorLogger class
 * Manages application logging with different levels
 */
class ErrorLogger private constructor() {
    
    enum class LogLevel(val displayName: String) {
        ACTION("ACCIÓN"),
        ERROR("ERROR"),
        PROCESS("PROCESO")
    }
    
    data class LogEntry(
        val id: String = UUID.randomUUID().toString(),
        val message: String,
        val level: LogLevel,
        val timestamp: Date = Date()
    )
    
    private val logs = ConcurrentLinkedQueue<LogEntry>()
    private val timeFormatter = SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale("es", "DO"))
    
    companion object {
        @Volatile
        private var INSTANCE: ErrorLogger? = null
        
        fun getInstance(): ErrorLogger {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: ErrorLogger().also { INSTANCE = it }
            }
        }
    }
    
    fun log(message: String, level: LogLevel, error: Throwable? = null) {
        val timestamp = Date()
        val formattedTimestamp = timeFormatter.format(timestamp)
        
        val prefix = when (level) {
            LogLevel.ACTION -> "📋 [ACCIÓN]"
            LogLevel.ERROR -> "🚨 [ERROR]"
            LogLevel.PROCESS -> "⚙️ [PROCESO]"
        }
        
        val fullMessage = buildString {
            append("$prefix [$formattedTimestamp]: $message")
            error?.let {
                append("\nStack Trace: ${it.localizedMessage}")
            }
        }
        
        val logEntry = LogEntry(
            message = fullMessage,
            level = level,
            timestamp = timestamp
        )
        
        logs.offer(logEntry)
        
        // Log to Android system log as well
        when (level) {
            LogLevel.ACTION -> Log.i("Ticom", fullMessage)
            LogLevel.ERROR -> Log.e("Ticom", fullMessage, error)
            LogLevel.PROCESS -> Log.d("Ticom", fullMessage)
        }
        
        // Keep only latest 1000 logs to prevent memory issues
        while (logs.size > 1000) {
            logs.poll()
        }
    }
    
    fun getLogs(): List<LogEntry> {
        return logs.toList().sortedByDescending { it.timestamp }
    }
    
    fun clearLogs() {
        logs.clear()
    }
    
    fun exportLogs(): String {
        return logs.sortedByDescending { it.timestamp }
            .joinToString(separator = "\n") { it.message }
    }
}