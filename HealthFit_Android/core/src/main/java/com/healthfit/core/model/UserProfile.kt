package com.healthfit.core.model

data class UserProfile(
    val uid: String,
    val displayName: String = "",
    val email: String = "",
    val countryCode: String = "BR",
)
