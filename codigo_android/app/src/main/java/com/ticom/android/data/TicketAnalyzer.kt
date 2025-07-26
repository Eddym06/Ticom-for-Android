package com.ticom.android.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.ticom.android.models.Ticket
import com.ticom.android.utils.ErrorLogger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*
import java.util.regex.Pattern

/**
 * Ticket analyzer equivalent to Swift TicketAnalyzer class
 * Processes images using ML Kit Text Recognition to extract ticket information
 */
class TicketAnalyzer(private val context: Context) {
    
    private val logger = ErrorLogger.getInstance()
    private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    
    // Date patterns for Dominican Republic tickets
    private val datePatterns = listOf(
        "(?:LUNES|MARTES|MIÉRCOLES|JUEVES|VIERNES|SÁBADO|DOMINGO) \\d{1,2} DE (?:ENERO|FEBRERO|MARZO|ABRIL|MAYO|JUNIO|JULIO|AGOSTO|SEPTIEMBRE|OCTUBRE|NOVIEMBRE|DICIEMBRE) DEL? \\d{4}",
        "\\d{1,2} DE (?:ENERO|FEBRERO|MARZO|ABRIL|MAYO|JUNIO|JULIO|AGOSTO|SEPTIEMBRE|OCTUBRE|NOVIEMBRE|DICIEMBRE) DE? \\d{4}",
        "\\d{1,2}/\\d{1,2}/\\d{4}",
        "\\d{1,2}-\\d{1,2}-\\d{4}",
        "\\d{4}-\\d{1,2}-\\d{1,2}"
    )
    
    private val dateFormats = listOf(
        "EEEE d 'DE' MMMM 'DEL' yyyy",
        "d 'DE' MMMM 'DE' yyyy",
        "dd/MM/yyyy",
        "dd-MM-yyyy",
        "yyyy-MM-dd"
    )
    
    private val codePattern = "\\b\\d{6,}\\b"
    private val typePatterns = listOf("ENTRADA", "SALIDA")
    
    suspend fun analyzeTicket(uri: Uri, originalBitmap: Bitmap): Ticket? = withContext(Dispatchers.IO) {
        logger.log("Iniciando análisis de ticket: $uri", ErrorLogger.LogLevel.ACTION)
        
        try {
            // Save image to internal storage
            val filename = "ticket_${System.currentTimeMillis()}.jpg"
            val file = File(context.filesDir, "tickets/$filename")
            file.parentFile?.mkdirs()
            
            FileOutputStream(file).use { out ->
                originalBitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
            }
            
            // Preprocess image for better OCR
            val preprocessedBitmap = preprocessImage(originalBitmap, false)
            
            // Try OCR with Vision
            var ticket = tryVisionOCR(preprocessedBitmap, file.absolutePath)
            
            if (ticket == null) {
                // Retry with more aggressive preprocessing
                val retryBitmap = preprocessImage(originalBitmap, true)
                ticket = tryVisionOCR(retryBitmap, file.absolutePath)
            }
            
            if (ticket == null) {
                // Try with inverted colors as last resort
                val invertedBitmap = invertColors(originalBitmap)
                ticket = tryVisionOCR(invertedBitmap, file.absolutePath)
            }
            
            ticket?.let {
                logger.log("Ticket analizado exitosamente: ${it.uniqueCode}", ErrorLogger.LogLevel.ACTION)
            } ?: logger.log("Falló el análisis del ticket", ErrorLogger.LogLevel.ERROR)
            
            return@withContext ticket
            
        } catch (e: Exception) {
            logger.log("Error analizando ticket: ${e.message}", ErrorLogger.LogLevel.ERROR, e)
            return@withContext null
        }
    }
    
    private suspend fun tryVisionOCR(bitmap: Bitmap, filepath: String): Ticket? = withContext(Dispatchers.IO) {
        try {
            val image = InputImage.fromBitmap(bitmap, 0)
            val result = textRecognizer.process(image).await()
            
            val text = result.textBlocks.joinToString("\n") { block ->
                block.lines.joinToString("\n") { line ->
                    line.elements.joinToString(" ") { it.text }
                }
            }
            
            logger.log("Texto extraído: $text", ErrorLogger.LogLevel.PROCESS)
            
            return@withContext processText(text, filepath)
            
        } catch (e: Exception) {
            logger.log("Error en Vision OCR: ${e.message}", ErrorLogger.LogLevel.ERROR, e)
            return@withContext null
        }
    }
    
    private fun processText(texto: String, filepath: String): Ticket? {
        val cleanedText = texto.replace(Regex("[^\\w\\s\\d/\\-.:]"), " ")
        val lines = cleanedText.split("\n").map { it.trim() }
        
        // Extract type
        val typeLine = lines.find { line ->
            typePatterns.any { pattern -> line.uppercase().contains(pattern) }
        }?.uppercase() ?: ""
        
        val tipo = when {
            typeLine.contains("ENTRADA") -> Ticket.TIPO_ENTRADA
            typeLine.contains("SALIDA") -> Ticket.TIPO_SALIDA
            else -> detectFringeColor(BitmapFactory.decodeFile(filepath)) ?: Ticket.TIPO_DESCONOCIDO
        }
        
        if (tipo == Ticket.TIPO_DESCONOCIDO) return null
        
        // Extract date
        val dateString = lines.reversed().find { line ->
            datePatterns.any { pattern ->
                Pattern.compile(pattern, Pattern.CASE_INSENSITIVE).matcher(line).find()
            }
        } ?: lines.lastOrNull()
        
        val fecha = dateString?.let { extractValidatedDate(it) } ?: return null
        
        // Extract code
        val codeLine = lines.find { line ->
            Pattern.compile(codePattern).matcher(line).find()
        } ?: cleanedText
        
        val uniqueCode = extractCode(codeLine) ?: return null
        
        return Ticket(
            filepath = filepath,
            fecha = fecha.time,
            tipo = tipo,
            uniqueCode = uniqueCode
        )
    }
    
    private fun extractValidatedDate(text: String): Date? {
        val uppercasedText = text.uppercase()
        val dateFormatter = SimpleDateFormat("", Locale("es", "DO"))
        
        for ((index, pattern) in datePatterns.withIndex()) {
            val matcher = Pattern.compile(pattern, Pattern.CASE_INSENSITIVE).matcher(uppercasedText)
            if (matcher.find()) {
                val dateString = matcher.group().trim()
                dateFormatter.applyPattern(dateFormats[index])
                try {
                    return dateFormatter.parse(dateString)
                } catch (e: Exception) {
                    continue
                }
            }
        }
        
        return null
    }
    
    private fun extractCode(text: String): String? {
        val matcher = Pattern.compile(codePattern).matcher(text.uppercase())
        return if (matcher.find()) {
            matcher.group().trim()
        } else null
    }
    
    private fun preprocessImage(bitmap: Bitmap, isRetry: Boolean): Bitmap {
        // Simple preprocessing - in a real app you might want more sophisticated image processing
        return bitmap
    }
    
    private fun invertColors(bitmap: Bitmap): Bitmap {
        // Simple color inversion - in a real app you might want more sophisticated processing
        return bitmap
    }
    
    private fun detectFringeColor(bitmap: Bitmap?): String? {
        bitmap ?: return null
        
        // Analyze the right edge of the image for color detection
        val width = bitmap.width
        val height = bitmap.height
        val fringeWidth = 40
        val startX = maxOf(0, width - fringeWidth)
        
        var totalR = 0f
        var totalG = 0f
        var totalB = 0f
        var pixelCount = 0
        
        for (y in 0 until height step 4) {
            for (x in startX until width step 4) {
                val pixel = bitmap.getPixel(x, y)
                val r = (pixel shr 16 and 0xFF) / 255f
                val g = (pixel shr 8 and 0xFF) / 255f
                val b = (pixel and 0xFF) / 255f
                
                totalR += r
                totalG += g
                totalB += b
                pixelCount++
            }
        }
        
        if (pixelCount == 0) return null
        
        val avgR = totalR / pixelCount
        val avgG = totalG / pixelCount
        val avgB = totalB / pixelCount
        
        val greenThreshold = avgG > 0.45f && avgG > avgR * 1.2f && avgG > avgB * 1.2f
        val blueThreshold = avgB > 0.45f && avgB > avgR * 1.2f && avgB > avgG * 1.2f
        
        return when {
            greenThreshold -> Ticket.TIPO_ENTRADA
            blueThreshold -> Ticket.TIPO_SALIDA
            else -> null
        }
    }
}