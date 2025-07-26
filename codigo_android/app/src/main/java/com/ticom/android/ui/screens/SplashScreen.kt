package com.ticom.android.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ConfirmationNumber
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ticom.android.ui.theme.OrangeDark
import kotlinx.coroutines.delay

/**
 * Splash screen equivalent to Swift SplashView
 * Shows animated logo and app title on startup
 */
@Composable
fun SplashScreen() {
    var scale by remember { mutableStateOf(0.5f) }
    var opacity by remember { mutableStateOf(0f) }
    var offset by remember { mutableStateOf(-100f) }
    
    val animatedScale by animateFloatAsState(
        targetValue = scale,
        animationSpec = spring(
            dampingRatio = 0.8f,
            stiffness = 300f
        ),
        label = "splash_scale"
    )
    
    val animatedOpacity by animateFloatAsState(
        targetValue = opacity,
        animationSpec = tween(durationMillis = 1000),
        label = "splash_opacity"
    )
    
    val animatedOffset by animateFloatAsState(
        targetValue = offset,
        animationSpec = spring(
            dampingRatio = 0.8f,
            stiffness = 300f
        ),
        label = "splash_offset"
    )
    
    LaunchedEffect(Unit) {
        delay(200)
        scale = 1.0f
        offset = 0f
        delay(500)
        opacity = 1.0f
    }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(OrangeDark),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.Default.ConfirmationNumber,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier
                    .size(120.dp)
                    .scale(animatedScale)
                    .offset(y = animatedOffset.dp)
            )
            
            Spacer(modifier = Modifier.height(20.dp))
            
            Text(
                text = "Ticom",
                fontSize = 48.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White.copy(alpha = animatedOpacity)
            )
        }
    }
}