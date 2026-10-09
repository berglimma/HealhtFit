package com.healthfit.android.ui.home

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.widget.Toast
import androidx.core.content.FileProvider
import java.io.File

object SharePublisher {
    enum class Target { WhatsAppStatus, InstagramStories }

    fun post(context: Context, file: File, mime: String, target: Target) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val intent = intentFor(context, uri, mime, target)
        val packageName = intent.`package`
        if (packageName != null) {
            context.grantUriPermission(packageName, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun saveVideo(context: Context, file: File, displayName: String) {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, "$displayName.mp4")
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/HealthFit")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            ?: error("A galeria não aceitou o vídeo.")
        resolver.openOutputStream(uri).use { output ->
            requireNotNull(output)
            file.inputStream().use { it.copyTo(output) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
    }

    fun copyToShare(context: Context, uri: Uri, name: String): File {
        val dir = File(context.cacheDir, "share").apply { mkdirs() }
        val ext = if (context.contentResolver.getType(uri)?.startsWith("video") == true) "mp4" else "jpg"
        val file = File(dir, "$name.$ext")
        context.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Não foi possível ler a mídia." }
            file.outputStream().use { input.copyTo(it) }
        }
        return file
    }

    private fun intentFor(context: Context, uri: Uri, mime: String, target: Target): Intent {
        val packages = context.packageManager
        return when (target) {
            Target.WhatsAppStatus -> {
                val pkg = listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull { installed(packages, it) }
                    ?: error("O WhatsApp não está instalado neste aparelho.")
                Intent(Intent.ACTION_SEND).apply {
                    type = mime
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra("jid", "status@broadcast")
                    setPackage(pkg)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            }
            Target.InstagramStories -> {
                if (!installed(packages, "com.instagram.android")) {
                    error("O Instagram não está instalado neste aparelho.")
                }
                val stories = Intent("com.instagram.share.ADD_TO_STORY").apply {
                    setDataAndType(uri, mime)
                    setPackage("com.instagram.android")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                if (stories.resolveActivity(packages) != null) {
                    stories
                } else {
                    Intent(Intent.ACTION_SEND).apply {
                        type = mime
                        putExtra(Intent.EXTRA_STREAM, uri)
                        setPackage("com.instagram.android")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                }
            }
        }
    }

    private fun installed(packages: PackageManager, name: String): Boolean =
        runCatching { packages.getPackageInfo(name, 0) }.isSuccess
}

fun toastShare(context: Context, block: () -> Unit) {
    runCatching(block).onFailure {
        Toast.makeText(context, it.message ?: "Não foi possível publicar", Toast.LENGTH_LONG).show()
    }
}
