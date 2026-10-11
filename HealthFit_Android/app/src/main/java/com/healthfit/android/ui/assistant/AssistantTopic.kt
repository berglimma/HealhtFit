package com.healthfit.android.ui.assistant

data class AssistantTopic(
    val keywords: List<String>,
    val respond: (AssistantAnswerContext) -> String,
)
