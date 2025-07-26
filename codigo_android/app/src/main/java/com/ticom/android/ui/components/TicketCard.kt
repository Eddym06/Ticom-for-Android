package com.ticom.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.ticom.android.models.Ticket
import com.ticom.android.utils.formattedString
import java.util.*
import java.util.Locale

/**
 * Ticket card component equivalent to Swift TicketCard
 * Displays ticket information in a card format
 */
@Composable
fun TicketCard(
    ticket: Ticket,
    locale: Locale = Locale("es", "DO"),
    onClick: (() -> Unit)? = null
) {
    var showingDetails by remember { mutableStateOf(false) }
    
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { 
                onClick?.invoke() ?: run { showingDetails = true }
            },
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.2f)
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Ticket image or placeholder
            Box(
                modifier = Modifier
                    .size(60.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color.Gray.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center
            ) {
                val imageData = ticket.getImageData()
                if (imageData != null) {
                    AsyncImage(
                        model = imageData,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Text(
                        text = "🎫",
                        fontSize = 24.sp,
                        color = Color.Gray
                    )
                }
            }
            
            Spacer(modifier = Modifier.width(15.dp))
            
            // Ticket information
            Column(
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = "${ticket.tipo.replaceFirstChar { it.uppercase() }} Ticket",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                
                Spacer(modifier = Modifier.height(4.dp))
                
                Text(
                    text = "Código: ${ticket.uniqueCode}",
                    fontSize = 14.sp,
                    color = Color.White.copy(alpha = 0.8f)
                )
                
                Spacer(modifier = Modifier.height(2.dp))
                
                Text(
                    text = "Fecha: ${Date(ticket.fecha).formattedString(locale)}",
                    fontSize = 14.sp,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }
        }
    }
    
    // Show ticket details dialog
    if (showingDetails) {
        TicketDetailDialog(
            ticket = ticket,
            locale = locale,
            onDismiss = { showingDetails = false }
        )
    }
}

@Composable
private fun TicketDetailDialog(
    ticket: Ticket,
    locale: Locale,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text("${ticket.tipo.replaceFirstChar { it.uppercase() }} Ticket")
        },
        text = {
            Column {
                Text("Código: ${ticket.uniqueCode}")
                Spacer(modifier = Modifier.height(8.dp))
                Text("Fecha: ${Date(ticket.fecha).formattedString(locale)}")
                Spacer(modifier = Modifier.height(8.dp))
                Text("Tipo: ${ticket.tipo}")
                
                // Show image if available
                val imageData = ticket.getImageData()
                if (imageData != null) {
                    Spacer(modifier = Modifier.height(16.dp))
                    AsyncImage(
                        model = imageData,
                        contentDescription = null,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp)
                            .clip(RoundedCornerShape(8.dp)),
                        contentScale = ContentScale.Fit
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Cerrar")
            }
        }
    )
}