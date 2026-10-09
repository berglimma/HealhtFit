package com.healthfit.android.ui.profile

import android.content.Context
import android.net.Uri
import java.io.File

fun copyGalleryImage(context: Context, uri: Uri, fileName: String): File {
    val dir = File(context.filesDir, "profile").apply { mkdirs() }
    val dest = File(dir, fileName)
    context.contentResolver.openInputStream(uri).use { input ->
        requireNotNull(input) { "Não foi possível ler a foto." }
        dest.outputStream().use { output -> input.copyTo(output) }
    }
    return dest
}
