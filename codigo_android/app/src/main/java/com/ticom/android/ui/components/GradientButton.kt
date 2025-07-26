package com.ticom.android.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Gradient button component equivalent to Swift GradientButton
 * Implements custom gradient backgrounds and tap animations
 */
@Composable
fun GradientButton(
    title: String,
    icon: ImageVector? = null,
    colors: List<Color>,
    onClick: () -> Unit,
    isPrimary: Boolean = false,
    modifier: Modifier = Modifier
) {
    var isTapped by remember { mutableStateOf(false) }
    val haptic = LocalHapticFeedback.current
    
    val scale by animateFloatAsState(
        targetValue = if (isTapped) 0.92f else 1.0f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "button_scale"
    )
    
    Button(
        onClick = {
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            isTapped = true
            onClick()
            // Reset tap state after animation
            kotlin.run {
                kotlinx.coroutines.GlobalScope.launch {
                    kotlinx.coroutines.delay(200)
                    isTapped = false
                }
            }
        },
        modifier = modifier
            .scale(scale)
            .height(if (isPrimary) 65.dp else 50.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Transparent
        ),
        contentPadding = PaddingValues(
            horizontal = if (isPrimary) 28.dp else 20.dp,
            vertical = if (isPrimary) 18.dp else 12.dp
        ),
        shape = RoundedCornerShape(50)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    brush = Brush.horizontalGradient(colors = colors),
                    shape = RoundedCornerShape(50)
                ),
            contentAlignment = Alignment.Center
        ) {
            Row(
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(4.dp)
            ) {
                icon?.let {
                    Icon(
                        imageVector = it,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(if (isPrimary) 22.dp else 18.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                }
                Text(
                    text = title,
                    color = Color.White,
                    fontSize = if (isPrimary) 18.sp else 16.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}