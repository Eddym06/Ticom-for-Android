package com.ticom.android.ui

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ticom.android.data.TicketManager
import com.ticom.android.ui.components.CircularProgressView
import com.ticom.android.ui.components.GradientButton
import com.ticom.android.ui.screens.SplashScreen
import kotlinx.coroutines.delay

/**
 * Main content view equivalent to Swift ContentView
 * Root composable that manages app state and navigation
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContentView(ticketManager: TicketManager) {
    var showSplash by remember { mutableStateOf(true) }
    var showingDocumentPicker by remember { mutableStateOf(false) }
    var showingWorkdays by remember { mutableStateOf(false) }
    var showingTicketList by remember { mutableStateOf(false) }
    var showingSettings by remember { mutableStateOf(false) }
    var showingClearDataAlert by remember { mutableStateOf(false) }
    
    // Document picker launcher
    val documentPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetMultipleContents()
    ) { uris: List<Uri> ->
        if (uris.isNotEmpty()) {
            ticketManager.procesarArchivos(uris)
        }
    }
    
    // Show splash screen initially
    LaunchedEffect(Unit) {
        delay(2500)
        showSplash = false
    }
    
    if (showSplash) {
        SplashScreen()
    } else {
        MainContent(
            ticketManager = ticketManager,
            onShowDocumentPicker = { 
                showingDocumentPicker = true
                documentPickerLauncher.launch("image/*")
            },
            onShowWorkdays = { showingWorkdays = true },
            onShowTicketList = { showingTicketList = true },
            onShowSettings = { showingSettings = true },
            onShowClearData = { showingClearDataAlert = true }
        )
    }
    
    // Processing overlay
    if (ticketManager.isProcessing) {
        ProcessingOverlay(ticketManager = ticketManager)
    }
    
    // Clear data confirmation dialog
    if (showingClearDataAlert) {
        AlertDialog(
            onDismissRequest = { showingClearDataAlert = false },
            title = { Text("Borrar Todos los Datos") },
            text = { Text("¿Estás seguro de que deseas borrar todos los tickets y configuraciones? Esta acción no se puede deshacer.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        ticketManager.clearAllData()
                        showingClearDataAlert = false
                    }
                ) {
                    Text("Borrar", color = Color.Red)
                }
            },
            dismissButton = {
                TextButton(onClick = { showingClearDataAlert = false }) {
                    Text("Cancelar")
                }
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MainContent(
    ticketManager: TicketManager,
    onShowDocumentPicker: () -> Unit,
    onShowWorkdays: () -> Unit,
    onShowTicketList: () -> Unit,
    onShowSettings: () -> Unit,
    onShowClearData: () -> Unit
) {
    val scrollState = rememberScrollState()
    
    // Animate content offset based on selected date
    val offset by animateFloatAsState(
        targetValue = if (ticketManager.selectedDate != null) -20f else 0f,
        animationSpec = tween(300),
        label = "content_offset"
    )
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.linearGradient(
                    colors = ticketManager.backgroundGradientColors,
                    start = androidx.compose.ui.geometry.Offset(0f, 0f),
                    end = androidx.compose.ui.geometry.Offset(1000f, 1000f)
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(top = 40.dp)
                .offset(y = offset.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // App title
            Text(
                text = "Ticom",
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.padding(top = 40.dp)
            )
            
            Spacer(modifier = Modifier.height(30.dp))
            
            // Action buttons
            ActionButtonsView(
                ticketManager = ticketManager,
                onShowWorkdays = onShowWorkdays,
                onShowTicketList = onShowTicketList,
                onShowDocumentPicker = onShowDocumentPicker
            )
            
            Spacer(modifier = Modifier.height(20.dp))
            
            // Calendar placeholder (will be implemented in next phase)
            CalendarPlaceholder()
            
            Spacer(modifier = Modifier.height(100.dp))
        }
        
        // Toolbar
        TopAppBar(
            title = { },
            navigationIcon = {
                IconButton(onClick = { /* User guide */ }) {
                    Icon(
                        imageVector = Icons.Default.Help,
                        contentDescription = "Guía de usuario",
                        tint = Color.White
                    )
                }
            },
            actions = {
                IconButton(onClick = onShowSettings) {
                    Icon(
                        imageVector = Icons.Default.Settings,
                        contentDescription = "Ajustes",
                        tint = Color.White
                    )
                }
                IconButton(onClick = onShowClearData) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = "Borrar datos",
                        tint = Color.White
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Transparent
            )
        )
    }
}

@Composable
private fun ActionButtonsView(
    ticketManager: TicketManager,
    onShowWorkdays: () -> Unit,
    onShowTicketList: () -> Unit,
    onShowDocumentPicker: () -> Unit
) {
    val entradaTickets = ticketManager.getTicketsEntradaForToday()
    val salidaTickets = ticketManager.getTicketsSalidaForToday()
    
    Column(
        modifier = Modifier.padding(horizontal = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Entry and Exit buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            GradientButton(
                title = "Entrada",
                icon = Icons.Default.ArrowForward,
                colors = ticketManager.entradaButtonColors,
                onClick = {
                    // Show entry ticket for today or picker if none exists
                    if (entradaTickets.isEmpty()) {
                        onShowDocumentPicker()
                    }
                },
                isPrimary = true,
                modifier = Modifier.weight(1f)
            )
            
            GradientButton(
                title = "Salida",
                icon = Icons.Default.ArrowBack,
                colors = ticketManager.salidaButtonColors,
                onClick = {
                    // Show exit ticket for today or picker if none exists
                    if (salidaTickets.isEmpty()) {
                        onShowDocumentPicker()
                    }
                },
                isPrimary = true,
                modifier = Modifier.weight(1f)
            )
        }
        
        Spacer(modifier = Modifier.height(12.dp))
        
        // Secondary buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            GradientButton(
                title = "Días de Clase",
                icon = Icons.Default.CalendarToday,
                colors = ticketManager.diasLaborablesButtonColors,
                onClick = onShowWorkdays,
                modifier = Modifier.weight(1f)
            )
            
            GradientButton(
                title = "Lista de Tickets",
                icon = Icons.Default.List,
                colors = ticketManager.listaTicketsButtonColors,
                onClick = onShowTicketList,
                modifier = Modifier.weight(1f)
            )
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Upload button
        GradientButton(
            title = "Subir Ticket",
            icon = Icons.Default.Add,
            colors = ticketManager.subirTicketButtonColors,
            onClick = onShowDocumentPicker,
            modifier = Modifier.width(200.dp)
        )
    }
}

@Composable
private fun CalendarPlaceholder() {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(280.dp)
            .padding(horizontal = 20.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.2f)
        ),
        shape = RoundedCornerShape(15.dp)
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "Calendario\n(Implementación pendiente)",
                color = Color.White,
                textAlign = TextAlign.Center,
                fontSize = 18.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
private fun ProcessingOverlay(ticketManager: TicketManager) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.5f)),
        contentAlignment = Alignment.Center
    ) {
        Card(
            modifier = Modifier.padding(32.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color.White.copy(alpha = 0.9f)
            ),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                CircularProgressView(progress = ticketManager.processingProgress)
                
                Spacer(modifier = Modifier.height(16.dp))
                
                Text(
                    text = "${ticketManager.processedTickets} de ${ticketManager.totalTickets} tickets procesados",
                    color = Color.Black,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                GradientButton(
                    title = "Cancelar",
                    icon = Icons.Default.Close,
                    colors = listOf(Color.Red, Color.Red.copy(alpha = 0.8f)),
                    onClick = { ticketManager.cancelProcessingAction() }
                )
            }
        }
    }
}