package com.healthfit.android.ui.home

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.widget.VideoView
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.designsystem.HealthFitColors
import java.io.File

sealed class LoadedShare {
    class Photo(val bitmap: Bitmap, val file: File) : LoadedShare()
    class Video(val file: File, val cover: Bitmap) : LoadedShare()
}

fun loadShare(context: android.content.Context, uri: Uri, session: FinishedWorkout): LoadedShare {
    val mime = context.contentResolver.getType(uri).orEmpty()
    return if (mime.startsWith("video")) {
        val file = SharePublisher.copyToShare(context, uri, "HealthFit-Video")
        val retriever = MediaMetadataRetriever()
        val frame = try {
            retriever.setDataSource(file.absolutePath)
            retriever.getFrameAtTime(0) ?: error("O vídeo não tem imagem para a capa.")
        } finally {
            retriever.release()
        }
        val cover = ShareCardImage.stampBitmap(context, frame, session)
        if (cover != frame) frame.recycle()
        LoadedShare.Video(file, cover)
    } else {
        val bitmap = ShareCardImage.stampPhoto(context, uri, session)
        val file = ShareCardImage.writeTemp(context, bitmap, "HealthFit-Foto")
        LoadedShare.Photo(bitmap, file)
    }
}

@Composable
fun ShareCommandButtons(
    saveLabel: String,
    busy: Boolean,
    onWhatsApp: () -> Unit,
    onInstagram: () -> Unit,
    onSave: () -> Unit,
) {
    GradientButton(
        text = if (busy) "Preparando…" else "Postar no WhatsApp Status",
        onClick = { if (!busy) onWhatsApp() },
    )
    Spacer(Modifier.height(8.dp))
    GradientButton(
        text = if (busy) "Preparando…" else "Postar nos Stories do Instagram",
        onClick = { if (!busy) onInstagram() },
    )
    Spacer(Modifier.height(8.dp))
    GradientButton(
        text = if (busy) "Salvando…" else saveLabel,
        onClick = { if (!busy) onSave() },
    )
}

@Composable
fun LoadedSharePreview(media: LoadedShare, session: FinishedWorkout) {
    when (media) {
        is LoadedShare.Photo -> Image(
            bitmap = media.bitmap.asImageBitmap(),
            contentDescription = "Foto com os dados de ${session.title}",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxWidth()
                .height(420.dp)
                .clip(RoundedCornerShape(16.dp)),
        )
        is LoadedShare.Video -> Box(
            Modifier
                .fillMaxWidth()
                .height(420.dp)
                .clip(RoundedCornerShape(16.dp)),
        ) {
            AndroidView(
                factory = { context ->
                    VideoView(context).apply {
                        setVideoPath(media.file.absolutePath)
                        setOnPreparedListener { player ->
                            player.isLooping = true
                            start()
                        }
                    }
                },
                modifier = Modifier.matchParentSize(),
            )
            Column(
                Modifier
                    .align(Alignment.BottomStart)
                    .fillMaxWidth()
                    .background(Color.Black.copy(alpha = 0.45f))
                    .padding(12.dp),
            ) {
                Text("Vídeo · ${session.title}", color = Color.White, fontWeight = FontWeight.Bold)
                Row(Modifier.padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    session.shareStats().forEach { stat ->
                        Column {
                            Text(stat.value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Text(stat.label, color = HealthFitColors.TextSecondary, fontSize = 10.sp)
                        }
                    }
                }
            }
        }
    }
    Text(
        "Prévia no app. Os dados mudam com a modalidade: ${session.shareStats().joinToString(" · ") { "${it.value} ${it.label}" }}",
        color = HealthFitColors.TextSecondary,
        fontSize = 12.sp,
        textAlign = TextAlign.Start,
        modifier = Modifier.padding(top = 8.dp),
    )
}
