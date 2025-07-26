package com.ticom.android.data

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.ticom.android.models.Ticket
import com.ticom.android.utils.ErrorLogger
import com.ticom.android.utils.formattedString
import com.ticom.android.utils.toComposeColor
import com.ticom.android.utils.toHexString
import kotlinx.coroutines.launch
import java.io.File
import java.util.*

/**
 * Main ticket manager equivalent to Swift TicketManager class
 * Manages all ticket operations, settings, and UI state
 */
class TicketManager(private val context: Context) : ViewModel() {
    
    private val logger = ErrorLogger.getInstance()
    private val storage = TicketStorage(context)
    private val processor = TicketProcessor(context)
    private val preferences: SharedPreferences = context.getSharedPreferences("ticom_prefs", Context.MODE_PRIVATE)
    
    // Published state variables (equivalent to @Published in Swift)
    var ticketsEntrada by mutableStateOf<List<Ticket>>(emptyList())
        private set
    
    var ticketsSalida by mutableStateOf<List<Ticket>>(emptyList())
        private set
    
    var diasLaborables by mutableStateOf<List<String>>(emptyList())
        private set
    
    var mostrarDiasLaborables by mutableStateOf(false)
    var mostrarListaTickets by mutableStateOf(false)
    var mostrarEntradaHoy by mutableStateOf(false)
    var mostrarSalidaHoy by mutableStateOf(false)
    var selectedDate by mutableStateOf<Date?>(null)
    var processingCompleted by mutableStateOf(false)
    var isProcessing by mutableStateOf(false)
    var processingProgress by mutableStateOf(0.0)
    
    // Notification settings
    var notificationTime by mutableStateOf<Date>(getDefaultNotificationTime())
        private set
    
    var alertFrequency by mutableStateOf(1)
        private set
    
    // Color customization
    var backgroundGradientColors by mutableStateOf(getDefaultBackgroundColors())
        private set
    
    var entradaButtonColors by mutableStateOf(getDefaultEntradaColors())
        private set
    
    var salidaButtonColors by mutableStateOf(getDefaultSalidaColors())
        private set
    
    var diasLaborablesButtonColors by mutableStateOf(getDefaultDiasLaborablesColors())
        private set
    
    var listaTicketsButtonColors by mutableStateOf(getDefaultListaTicketsColors())
        private set
    
    var subirTicketButtonColors by mutableStateOf(getDefaultSubirTicketColors())
        private set
    
    // Processing state
    var totalTickets by mutableStateOf(0)
    var processedTickets by mutableStateOf(0)
    var showClearConfirmation by mutableStateOf(false)
    
    private var cancelProcessing: (() -> Unit)? = null
    private var calendarEvents: Map<String, List<Ticket>> = emptyMap()
    
    init {
        loadConfiguration()
        loadTickets()
        logger.log("TicketManager inicializado", ErrorLogger.LogLevel.ACTION)
    }
    
    private fun loadTickets() {
        viewModelScope.launch {
            val (entrada, salida) = storage.loadTickets()
            ticketsEntrada = entrada
            ticketsSalida = salida
            updateCalendar()
            logger.log("Tickets cargados - Entrada: ${entrada.size}, Salida: ${salida.size}", ErrorLogger.LogLevel.ACTION)
        }
    }
    
    private fun loadConfiguration() {
        diasLaborables = preferences.getStringSet("diasLaborables", emptySet())?.toList() ?: emptyList()
        
        // Load notification settings
        val notificationTimeMillis = preferences.getLong("notificationTime", getDefaultNotificationTime().time)
        notificationTime = Date(notificationTimeMillis)
        alertFrequency = preferences.getInt("alertFrequency", 1)
        
        // Load color settings
        backgroundGradientColors = loadColorList("backgroundGradientColors", getDefaultBackgroundColors())
        entradaButtonColors = loadColorList("entradaButtonColors", getDefaultEntradaColors())
        salidaButtonColors = loadColorList("salidaButtonColors", getDefaultSalidaColors())
        diasLaborablesButtonColors = loadColorList("diasLaborablesButtonColors", getDefaultDiasLaborablesColors())
        listaTicketsButtonColors = loadColorList("listaTicketsButtonColors", getDefaultListaTicketsColors())
        subirTicketButtonColors = loadColorList("subirTicketButtonColors", getDefaultSubirTicketColors())
    }
    
    private fun loadColorList(key: String, default: List<Color>): List<Color> {
        val hexStrings = preferences.getStringSet(key, null)
        return if (hexStrings != null) {
            hexStrings.map { it.toComposeColor() }
        } else {
            default
        }
    }
    
    private fun saveColorList(key: String, colors: List<Color>) {
        val hexStrings = colors.map { it.toHexString() }.toSet()
        preferences.edit().putStringSet(key, hexStrings).apply()
    }
    
    fun saveWorkdays(workdays: List<String>) {
        diasLaborables = workdays
        preferences.edit().putStringSet("diasLaborables", workdays.toSet()).apply()
        logger.log("Días de clase guardados: ${workdays.joinToString(\", \")}", ErrorLogger.LogLevel.ACTION)
    }
    
    fun saveNotificationTime(time: Date) {
        notificationTime = time
        preferences.edit().putLong("notificationTime", time.time).apply()
        logger.log("Hora de notificación guardada: ${time.formattedString()}", ErrorLogger.LogLevel.ACTION)
    }
    
    fun saveAlertFrequency(frequency: Int) {
        alertFrequency = frequency.coerceIn(1, 5)
        preferences.edit().putInt("alertFrequency", alertFrequency).apply()
        logger.log("Frecuencia de alertas guardada: $alertFrequency", ErrorLogger.LogLevel.ACTION)
    }
    
    fun saveBackgroundGradientColors(colors: List<Color>) {
        backgroundGradientColors = colors
        saveColorList("backgroundGradientColors", colors)
        logger.log("Colores de fondo guardados", ErrorLogger.LogLevel.ACTION)
    }
    
    fun saveEntradaButtonColors(colors: List<Color>) {
        entradaButtonColors = colors
        saveColorList("entradaButtonColors", colors)
        logger.log("Colores de botón Entrada guardados", ErrorLogger.LogLevel.ACTION)
    }
    
    fun saveSalidaButtonColors(colors: List<Color>) {
        salidaButtonColors = colors
        saveColorList("salidaButtonColors", colors)
        logger.log("Colores de botón Salida guardados", ErrorLogger.LogLevel.ACTION)
    }
    
    fun saveDiasLaborablesButtonColors(colors: List<Color>) {
        diasLaborablesButtonColors = colors
        saveColorList("diasLaborablesButtonColors", colors)
        logger.log("Colores de botón Días de Clase guardados", ErrorLogger.LogLevel.ACTION)
    }
    
    fun saveListaTicketsButtonColors(colors: List<Color>) {
        listaTicketsButtonColors = colors
        saveColorList("listaTicketsButtonColors", colors)
        logger.log("Colores de botón Lista de Tickets guardados", ErrorLogger.LogLevel.ACTION)
    }
    
    fun saveSubirTicketButtonColors(colors: List<Color>) {
        subirTicketButtonColors = colors
        saveColorList("subirTicketButtonColors", colors)
        logger.log("Colores de botón Subir Ticket guardados", ErrorLogger.LogLevel.ACTION)
    }
    
    fun procesarArchivos(uris: List<Uri>, completionHandler: (List<Ticket>) -> Unit = { }) {
        if (isProcessing) {
            logger.log("Procesamiento ya en curso, ignorando nueva solicitud", ErrorLogger.LogLevel.PROCESS)
            return
        }
        
        isProcessing = true
        processingProgress = 0.0
        totalTickets = uris.size
        processedTickets = 0
        
        viewModelScope.launch {
            val cancel = processor.processTickets(
                uris = uris,
                progressHandler = { progress ->
                    processingProgress = progress
                    processedTickets = (progress * totalTickets).toInt()
                }
            ) { newTickets ->
                var addedCount = 0
                for (ticket in newTickets) {
                    if (agregarTicket(ticket)) {
                        addedCount++
                    }
                }
                
                if (addedCount == 0 && uris.isNotEmpty()) {
                    logger.log("No se pudo procesar ningún ticket", ErrorLogger.LogLevel.ERROR)
                }
                
                updateStorage()
                updateCalendar()
                
                isProcessing = false
                processingProgress = 1.0
                cancelProcessing = null
                processingCompleted = true
                
                getTicketsEntradaForToday()
                getTicketsSalidaForToday()
                
                completionHandler(newTickets)
            }
            
            cancelProcessing = cancel
        }
    }
    
    fun cancelProcessingAction() {
        cancelProcessing?.invoke()
        isProcessing = false
        processingProgress = 0.0
        processedTickets = 0
        cancelProcessing = null
        logger.log("Procesamiento cancelado por el usuario", ErrorLogger.LogLevel.ACTION)
    }
    
    fun clearAllData() {
        if (showClearConfirmation) {
            ticketsEntrada = emptyList()
            ticketsSalida = emptyList()
            calendarEvents = emptyMap()
            selectedDate = null
            
            // Delete all ticket files
            val ticketsDir = File(context.filesDir, "tickets")
            if (ticketsDir.exists()) {
                ticketsDir.deleteRecursively()
            }
            
            updateStorage()
            logger.log("Todos los tickets han sido borrados", ErrorLogger.LogLevel.ACTION)
            showClearConfirmation = false
        }
    }
    
    fun obtenerTicketsDia(date: Date): List<Ticket> {
        val calendar = Calendar.getInstance()
        calendar.time = date
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        
        val startOfDay = calendar.time
        return calendarEvents[startOfDay.toString()] ?: emptyList()
    }
    
    fun getTicketsEntradaForToday(): List<Ticket> {
        val today = Date()
        val calendar = Calendar.getInstance()
        calendar.time = today
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startOfDay = calendar.time
        
        val tickets = ticketsEntrada.filter { ticket ->
            val ticketCalendar = Calendar.getInstance()
            ticketCalendar.time = Date(ticket.fecha)
            ticketCalendar.set(Calendar.HOUR_OF_DAY, 0)
            ticketCalendar.set(Calendar.MINUTE, 0)
            ticketCalendar.set(Calendar.SECOND, 0)
            ticketCalendar.set(Calendar.MILLISECOND, 0)
            ticketCalendar.time == startOfDay
        }
        
        mostrarEntradaHoy = tickets.isNotEmpty()
        logger.log("Tickets de entrada para hoy: ${tickets.size}", ErrorLogger.LogLevel.ACTION)
        return tickets
    }
    
    fun getTicketsSalidaForToday(): List<Ticket> {
        val today = Date()
        val calendar = Calendar.getInstance()
        calendar.time = today
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startOfDay = calendar.time
        
        val tickets = ticketsSalida.filter { ticket ->
            val ticketCalendar = Calendar.getInstance()
            ticketCalendar.time = Date(ticket.fecha)
            ticketCalendar.set(Calendar.HOUR_OF_DAY, 0)
            ticketCalendar.set(Calendar.MINUTE, 0)
            ticketCalendar.set(Calendar.SECOND, 0)
            ticketCalendar.set(Calendar.MILLISECOND, 0)
            ticketCalendar.time == startOfDay
        }
        
        mostrarSalidaHoy = tickets.isNotEmpty()
        logger.log("Tickets de salida para hoy: ${tickets.size}", ErrorLogger.LogLevel.ACTION)
        return tickets
    }
    
    fun obtenerTicketsFiltrados(filtro: String): List<Ticket> {
        return when (filtro) {
            "Todos" -> (ticketsEntrada + ticketsSalida).sortedByDescending { it.fecha }
            "Entrada" -> ticketsEntrada.sortedByDescending { it.fecha }
            "Salida" -> ticketsSalida.sortedByDescending { it.fecha }
            else -> emptyList()
        }
    }
    
    private fun agregarTicket(ticket: Ticket): Boolean {
        val existingTickets = ticketsEntrada + ticketsSalida
        if (existingTickets.any { it.uniqueCode == ticket.uniqueCode || it.filepath == ticket.filepath }) {
            logger.log("Ticket duplicado detectado: ${ticket.uniqueCode}", ErrorLogger.LogLevel.ERROR)
            return false
        }
        
        when (ticket.tipo) {
            Ticket.TIPO_ENTRADA -> {
                ticketsEntrada = ticketsEntrada + ticket
            }
            Ticket.TIPO_SALIDA -> {
                ticketsSalida = ticketsSalida + ticket
            }
            else -> return false
        }
        
        logger.log("Ticket agregado: ${ticket.uniqueCode} (${ticket.tipo})", ErrorLogger.LogLevel.ACTION)
        updateStorage()
        updateCalendar()
        
        // Check if it's today's ticket
        val today = Calendar.getInstance()
        val ticketCalendar = Calendar.getInstance()
        ticketCalendar.time = Date(ticket.fecha)
        
        if (today.get(Calendar.YEAR) == ticketCalendar.get(Calendar.YEAR) &&
            today.get(Calendar.DAY_OF_YEAR) == ticketCalendar.get(Calendar.DAY_OF_YEAR)) {
            getTicketsEntradaForToday()
            getTicketsSalidaForToday()
        }
        
        return true
    }
    
    private fun updateStorage() {
        viewModelScope.launch {
            storage.saveTickets(ticketsEntrada, ticketsSalida)
            logger.log("Almacenamiento actualizado - Entrada: ${ticketsEntrada.size}, Salida: ${ticketsSalida.size}", ErrorLogger.LogLevel.ACTION)
        }
    }
    
    private fun updateCalendar() {
        val events = mutableMapOf<String, MutableList<Ticket>>()
        
        for (ticket in ticketsEntrada + ticketsSalida) {
            val calendar = Calendar.getInstance()
            calendar.time = Date(ticket.fecha)
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            
            val startOfDay = calendar.time
            val key = startOfDay.toString()
            
            events.getOrPut(key) { mutableListOf() }.add(ticket)
        }
        
        calendarEvents = events
        logger.log("Calendario actualizado con eventos", ErrorLogger.LogLevel.ACTION)
    }
    
    fun getCalendarEvents(): Map<String, List<Ticket>> = calendarEvents
    
    // Default color getters
    private fun getDefaultNotificationTime(): Date {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 20)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.time
    }
    
    private fun getDefaultBackgroundColors(): List<Color> = listOf(
        "#FF9500".toComposeColor(),
        "#FF6200".toComposeColor(),
        "#FFAD35".toComposeColor()
    )
    
    private fun getDefaultEntradaColors(): List<Color> = listOf(
        "#00CC00".toComposeColor(),
        "#006600".toComposeColor()
    )
    
    private fun getDefaultSalidaColors(): List<Color> = listOf(
        "#1E3A8A".toComposeColor(),
        "#3B82F6".toComposeColor()
    )
    
    private fun getDefaultDiasLaborablesColors(): List<Color> = listOf(
        "#6F6F6F".toComposeColor(),
        "#484848".toComposeColor()
    )
    
    private fun getDefaultListaTicketsColors(): List<Color> = listOf(
        "#F80000".toComposeColor(),
        "#950000".toComposeColor()
    )
    
    private fun getDefaultSubirTicketColors(): List<Color> = listOf(
        "#52A49A".toComposeColor(),
        "#3C876A".toComposeColor()
    )
}