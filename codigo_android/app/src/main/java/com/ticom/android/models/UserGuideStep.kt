package com.ticom.android.models

/**
 * Represents a step in the user guide
 * Equivalent to the Swift UserGuideStep struct
 */
data class UserGuideStep(
    val id: String = java.util.UUID.randomUUID().toString(),
    val title: String,
    val description: String,
    val imageName: String,
    val highlightID: String
)