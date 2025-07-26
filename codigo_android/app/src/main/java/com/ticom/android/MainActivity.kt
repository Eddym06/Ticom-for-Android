package com.ticom.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.ticom.android.data.TicketManager
import com.ticom.android.ui.theme.TicomTheme
import com.ticom.android.ui.ContentView

/**
 * Main Activity equivalent to iOS ContentView
 * Entry point for the Android application
 */
class MainActivity : ComponentActivity() {
    
    private lateinit var ticketManager: TicketManager
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize TicketManager
        ticketManager = TicketManager(this)
        
        setContent {
            TicomTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    ContentView(ticketManager = ticketManager)
                }
            }
        }
    }
}