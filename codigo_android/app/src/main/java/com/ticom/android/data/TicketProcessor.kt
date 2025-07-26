package com.ticom.android.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import com.ticom.android.models.Ticket
import com.ticom.android.utils.ErrorLogger
import kotlinx.coroutines.*
import java.util.concurrent.Semaphore

/**
 * Ticket processor equivalent to Swift TicketProcessor class
 * Handles concurrent processing of multiple ticket images
 */
class TicketProcessor(private val context: Context) {
    
    private val logger = ErrorLogger.getInstance()
    private val analyzer = TicketAnalyzer(context)
    private val maxConcurrentOperations = 5
    private val semaphore = Semaphore(maxConcurrentOperations)
    
    @Volatile
    private var isCancelled = false
    
    suspend fun processTickets(
        uris: List<Uri>,
        progressHandler: (Double) -> Unit,
        completion: (List<Ticket>) -> Unit
    ): () -> Unit = withContext(Dispatchers.IO) {
        
        logger.log("Iniciando procesamiento de ${uris.size} tickets", ErrorLogger.LogLevel.ACTION)
        
        val totalTickets = uris.size
        var processedCount = 0
        var successfulTickets = mutableListOf<Ticket>()
        isCancelled = false
        
        val jobs = uris.map { uri ->
            async {
                if (isCancelled) return@async null
                
                semaphore.acquire()
                try {
                    val bitmap = loadBitmapFromUri(uri)
                    if (bitmap != null && !isCancelled) {
                        val ticket = analyzer.analyzeTicket(uri, bitmap)
                        if (ticket != null) {
                            synchronized(successfulTickets) {
                                successfulTickets.add(ticket)
                            }
                        }
                        ticket
                    } else null
                } catch (e: Exception) {
                    logger.log("Error procesando archivo $uri: ${e.message}", ErrorLogger.LogLevel.ERROR, e)
                    null
                } finally {
                    semaphore.release()
                    synchronized(this@TicketProcessor) {
                        processedCount++
                        val progress = if (totalTickets > 0) processedCount.toDouble() / totalTickets else 0.0
                        withContext(Dispatchers.Main) {
                            progressHandler(progress)
                        }
                    }
                }
            }
        }
        
        // Wait for all jobs to complete
        jobs.awaitAll()
        
        if (isCancelled) {
            logger.log("Procesamiento cancelado. Tickets exitosos: ${successfulTickets.size} de $processedCount intentos", ErrorLogger.LogLevel.ACTION)
        } else {
            logger.log("Procesamiento completado. Tickets exitosos: ${successfulTickets.size} de $processedCount intentos", ErrorLogger.LogLevel.ACTION)
        }
        
        withContext(Dispatchers.Main) {
            completion(successfulTickets.toList())
        }
        
        // Return cancellation function
        return@withContext {
            isCancelled = true
            logger.log("Solicitud de cancelación recibida", ErrorLogger.LogLevel.ACTION)
        }
    }
    
    private fun loadBitmapFromUri(uri: Uri): Bitmap? {
        return try {
            context.contentResolver.openInputStream(uri)?.use { inputStream ->
                BitmapFactory.decodeStream(inputStream)
            }
        } catch (e: Exception) {
            logger.log("Error cargando imagen desde URI $uri: ${e.message}", ErrorLogger.LogLevel.ERROR, e)
            null
        }
    }
}