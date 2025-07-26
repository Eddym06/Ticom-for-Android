package com.ticom.android.data

import android.content.Context
import com.ticom.android.models.Ticket
import com.ticom.android.utils.ErrorLogger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Ticket storage equivalent to Swift TicketStorage class
 * Handles saving and loading tickets to/from JSON files
 */
class TicketStorage(private val context: Context) {
    
    private val logger = ErrorLogger.getInstance()
    private val json = Json { 
        prettyPrint = true
        ignoreUnknownKeys = true
    }
    
    companion object {
        private const val ENTRADA_FILE_NAME = "ticketsEntrada.json"
        private const val SALIDA_FILE_NAME = "ticketsSalida.json"
    }
    
    suspend fun saveTickets(entrada: List<Ticket>, salida: List<Ticket>) = withContext(Dispatchers.IO) {
        try {
            val entradaFile = File(context.filesDir, ENTRADA_FILE_NAME)
            val salidaFile = File(context.filesDir, SALIDA_FILE_NAME)
            
            // Save entrada tickets
            val entradaJson = json.encodeToString(entrada)
            entradaFile.writeText(entradaJson)
            logger.log("Tickets de entrada guardados: ${entrada.size}", ErrorLogger.LogLevel.ACTION)
            
            // Save salida tickets
            val salidaJson = json.encodeToString(salida)
            salidaFile.writeText(salidaJson)
            logger.log("Tickets de salida guardados: ${salida.size}", ErrorLogger.LogLevel.ACTION)
            
        } catch (e: Exception) {
            logger.log("Error al guardar tickets: ${e.message}", ErrorLogger.LogLevel.ERROR, e)
        }
    }
    
    suspend fun loadTickets(): Pair<List<Ticket>, List<Ticket>> = withContext(Dispatchers.IO) {
        var entrada = emptyList<Ticket>()
        var salida = emptyList<Ticket>()
        
        try {
            val entradaFile = File(context.filesDir, ENTRADA_FILE_NAME)
            if (entradaFile.exists()) {
                val entradaJson = entradaFile.readText()
                entrada = json.decodeFromString<List<Ticket>>(entradaJson)
                    .filter { File(it.filepath).exists() } // Validate file exists
                logger.log("Tickets de entrada cargados: ${entrada.size}", ErrorLogger.LogLevel.ACTION)
            } else {
                logger.log("No existe archivo de tickets de entrada", ErrorLogger.LogLevel.PROCESS)
            }
            
            val salidaFile = File(context.filesDir, SALIDA_FILE_NAME)
            if (salidaFile.exists()) {
                val salidaJson = salidaFile.readText()
                salida = json.decodeFromString<List<Ticket>>(salidaJson)
                    .filter { File(it.filepath).exists() } // Validate file exists
                logger.log("Tickets de salida cargados: ${salida.size}", ErrorLogger.LogLevel.ACTION)
            } else {
                logger.log("No existe archivo de tickets de salida", ErrorLogger.LogLevel.PROCESS)
            }
            
        } catch (e: Exception) {
            logger.log("Error al cargar tickets: ${e.message}", ErrorLogger.LogLevel.ERROR, e)
        }
        
        return@withContext Pair(entrada, salida)
    }
}