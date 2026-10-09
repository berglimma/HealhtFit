package com.healthfit.android.ui.profile

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.ui.platform.LocalContext
import java.io.File
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Pool
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material.icons.filled.Watch
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.TextButton
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.components.BiotypeSection
import com.healthfit.android.ui.home.DailyWellness
import com.healthfit.android.ui.home.SleepCard
import com.healthfit.android.ui.home.WaterCard
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.core.model.UserProfile
import com.healthfit.designsystem.HealthFitColors

private data class Modality(val title: String, val subtitle: String, val icon: ImageVector, val group: String)

@Composable
fun ProfileScreen(
    profile: UserProfile,
    wellness: DailyWellness,
    athlete: com.healthfit.android.ui.home.AthleteProfile,
    onSignOut: () -> Unit,
) {
    val modalities = remember {
        mutableStateListOf(
            Modality("Musculação", "Programas academia e mobilidade", Icons.Filled.FitnessCenter, "TREINO"),
            Modality("Treino em casa", "Peso corporal, HIIT e core", Icons.Filled.Home, "TREINO"),
            Modality("Caminhada", "Caminhada outdoor com mapa GPS, ritmo e passos", Icons.Filled.DirectionsRun, "CARDIO"),
            Modality("Mountain bike", "Mountain bike em trilha ou terreno irregular", Icons.Filled.DirectionsBike, "CARDIO"),
            Modality("Bicicleta pedal", "Ciclismo outdoor em rua ou ciclovia", Icons.Filled.DirectionsBike, "CARDIO"),
            Modality("Bicicleta ergométrica", "Bike estacionária indoor, sem GPS", Icons.Filled.DirectionsBike, "CARDIO"),
            Modality("Surf", "Sessão de surf com GPS, spot e registro de condições", Icons.Filled.Pool, "CARDIO"),
            Modality("Kitesurf", "Kitesurf com equipamento, modos, saltos e mapa", Icons.Filled.Pool, "CARDIO"),
            Modality("Elíptico", "Movimento fluido de corpo inteiro", Icons.Filled.DirectionsRun, "CARDIO"),
            Modality("Pular Corda", "Saltos contínuos com corda", Icons.Filled.DirectionsRun, "CARDIO"),
            Modality("Escada", "Simulador de escadas ou degraus", Icons.Filled.DirectionsRun, "CARDIO"),
            Modality("Escalada", "Escalada em parede indoor ou rocha", Icons.Filled.DirectionsRun, "CARDIO"),
            Modality("Remo", "Remo na água ou ergométrico · SPM, split / 500 m", Icons.Filled.Pool, "CARDIO"),
            Modality("Natação", "Nados em piscina com voltas, distância e ritmo", Icons.Filled.Pool, "CARDIO"),
            Modality("Polichinelo", "Jumping jacks em ritmo constante", Icons.Filled.DirectionsRun, "CARDIO"),
            Modality("Luta", "Boxe, Muay Thai, Jiu-Jitsu e MMA", Icons.Filled.FitnessCenter, "CARDIO"),
            Modality("Corrida", "Corrida ao ar livre com mapa GPS, ritmo e rota", Icons.Filled.DirectionsRun, "CARDIO"),
            Modality("Esteira Ergométrica", "Indoor, com ou sem elevação", Icons.Filled.DirectionsRun, "CARDIO"),
            Modality("Burpees", "Exercício funcional de alta intensidade", Icons.Filled.FitnessCenter, "CARDIO"),
            Modality("Meditação", "Respiração, foco, sono e recuperação", Icons.Filled.Spa, "MENTE"),
        )
    }
    val active = remember { mutableStateListOf(*modalities.map { it.title }.toTypedArray()) }
    var supplementsOn by remember { mutableStateOf(true) }
    var mealsOn by remember { mutableStateOf(true) }
    var page by remember { mutableStateOf("main") }
    var birth by remember { mutableStateOf("") }
    val context = LocalContext.current
    var coverFile by remember { mutableStateOf(File(context.filesDir, "profile/cover.jpg").takeIf { it.exists() }) }
    var avatarFile by remember { mutableStateOf(File(context.filesDir, "profile/avatar.jpg").takeIf { it.exists() }) }
    val coverPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) {
            coverFile = runCatching { copyGalleryImage(context, uri, "cover.jpg") }.getOrElse {
                Toast.makeText(context, it.message ?: "Não foi possível usar a foto", Toast.LENGTH_SHORT).show()
                coverFile
            }
        }
    }
    val avatarPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) {
            avatarFile = runCatching { copyGalleryImage(context, uri, "avatar.jpg") }.getOrElse {
                Toast.makeText(context, it.message ?: "Não foi possível usar a foto", Toast.LENGTH_SHORT).show()
                avatarFile
            }
        }
    }
    var prescribed by remember { mutableStateOf(false) }
    var rest by remember { mutableIntStateOf(75) }
    var synced by remember { mutableStateOf(false) }
    var nickname by remember { mutableStateOf(profile.displayName.ifBlank { "Berg" }) }
    var plan by remember { mutableStateOf("Fit") }
    var role by remember { mutableStateOf("Aluno") }
    var hasTrainer by remember { mutableStateOf(false) }
    var trainerName by remember { mutableStateOf("") }
    var trainerEmail by remember { mutableStateOf("") }
    var hasNutri by remember { mutableStateOf(false) }
    var nutriName by remember { mutableStateOf("") }
    var nutriEmail by remember { mutableStateOf("") }
    var energy by remember { mutableIntStateOf(0) }
    var preWorkout by remember { mutableIntStateOf(0) }
    var restAlert by remember { mutableIntStateOf(120) }
    var restNotify by remember { mutableStateOf(true) }
    var language by remember { mutableStateOf("🇧🇷 Português") }
    var feedbackKind by remember { mutableStateOf("Sugestão") }
    var feedbackText by remember { mutableStateOf("") }
    var feedbackSent by remember { mutableStateOf(false) }
    var showDelete by remember { mutableStateOf(false) }
    val measures = remember {
        mutableStateMapOf(
            "Pescoço" to "",
            "Ombros" to "",
            "Peito" to "",
            "Braço direito" to "",
            "Braço esquerdo" to "",
            "Cintura" to "",
            "Abdômen" to "",
            "Quadril" to "",
            "Coxa direita" to "",
            "Coxa esquerda" to "",
            "Panturrilha direita" to "",
            "Panturrilha esquerda" to "",
        )
    }
    if (page != "main") {
        when (page) {
            "plan" -> PlanPage(plan, { plan = it }, { page = "main" })
            "measures" -> MeasuresPage(measures, { page = "main" })
            "privacy" -> InfoPage(
                "Política de Privacidade",
                "O HealthFit guarda sono, água, treinos e medidas neste aparelho. Fotos de evolução ficam privadas. Passos e batimentos entram pelo Health Connect quando você autoriza.",
                { page = "main" },
            )
            "terms" -> InfoPage(
                "Termos de Uso",
                "O HealthFit é um diário de treino e nutrição. Não substitui personal, nutricionista ou médico. A assinatura é cobrada pela loja do aparelho.",
                { page = "main" },
            )
            "coach" -> CoachHubScreen(
                onBack = { page = "main" },
                onOpen = { page = it },
                sent = prescribed,
            )
            "coach-alunos" -> CoachStudentsScreen(onBack = { page = "coach" }, onOpenSheet = { page = "coach-fichas" })
            "coach-prescribe" -> CoachPrescribeScreen(onBack = { page = "coach" }) {
                prescribed = true
                page = "coach"
            }
            "coach-chat" -> CoachChatScreen(onBack = { page = "coach" })
            "coach-fichas" -> CoachSheetScreen(onBack = { page = "coach" })
            "support" -> InfoPage(
                "Suporte",
                "Escreva para o suporte pelo formulário de feedback nesta tela, com o tipo Dúvida. A resposta usa o e-mail da sua conta.",
                { page = "main" },
            )
            else -> ProfileDetail(page, wellness.weightKg, athlete.heightCm, rest, synced, { wellness.weightKg = it }, { athlete.heightCm = it }, { rest = it }, { synced = true }) {
                page = "main"
            }
        }
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Text(
            "Perfil",
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        ProfileCover(
            coverFile = coverFile,
            avatarFile = avatarFile,
            name = nickname.ifBlank { profile.displayName.ifBlank { "Berg Limma" } },
            email = profile.email.ifBlank { "berg.limma@gmail.com" },
            onChangeCover = {
                coverPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
            onChangeAvatar = {
                avatarPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
            onClearCover = {
                coverFile?.delete()
                coverFile = null
            },
            onClearAvatar = {
                avatarFile?.delete()
                avatarFile = null
            },
        )
        Text(
            nickname.ifBlank { profile.displayName.ifBlank { "Berg Limma" } },
            color = Color(0xFFB7C0C8),
            fontSize = 13.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
        )
        NicknameSection(nickname) { nickname = it }
        PlanRow(plan) { page = "plan" }
        Spacer(Modifier.height(12.dp))
        Text("Você é", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            RoleCard("Aluno", Icons.Filled.DirectionsRun, Color(0xFF1F6B32), Modifier.weight(1f), role == "Aluno") { role = "Aluno" }
            RoleCard("Personal", Icons.Filled.FitnessCenter, Color(0xFF1A3A6A), Modifier.weight(1f), role == "Personal") { role = "Personal" }
        }
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            RoleCard("Nutricionista", Icons.Filled.Spa, Color(0xFF8A5A2A), Modifier.weight(1f), role == "Nutricionista") { role = "Nutricionista" }
            RoleCard("Personal e Nutrição", Icons.Filled.Groups, Color(0xFFB4232C), Modifier.weight(1f), role == "Personal e Nutrição") { role = "Personal e Nutrição" }
        }
        Text(
            "Aluno treina com o app. Personal e nutricionista usam como profissionais — dá para marcar os dois.",
            color = Color(0xFFB7C0C8),
            fontSize = 13.sp,
            modifier = Modifier.padding(vertical = 8.dp),
        )
        CoachEntryCard(onClick = { page = "coach" })
        Spacer(Modifier.height(16.dp))
        BiotypeSection(athlete.bodyType) { athlete.bodyType = it }
        Spacer(Modifier.height(18.dp))
        Text("Modalidades que pratico", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        DarkCard {
            Text(
                "Marque o que você pratica. A lista de treinos mostra só as modalidades ativas.",
                color = Color(0xFFB7C0C8),
                fontSize = 13.sp,
            )
            Row(modifier = Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "Marcar todas",
                    color = HealthFitColors.Accent,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable {
                        active.clear()
                        active.addAll(modalities.map { it.title })
                    },
                )
                Text(
                    "  Só musculação",
                    color = HealthFitColors.Accent,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable {
                        active.clear()
                        active.add("Musculação")
                    },
                )
                Spacer(Modifier.weight(1f))
                Text("${active.size} ativas", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
            }
        }
        var lastGroup = ""
        modalities.forEach { item ->
            if (item.group != lastGroup) {
                lastGroup = item.group
                Text(
                    item.group,
                    color = Color(0xFF8E989F),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 14.dp, bottom = 6.dp),
                )
            }
            val on = item.title in active
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        if (on) active.remove(item.title) else active.add(item.title)
                    }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(item.icon, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(22.dp))
                Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
                    Text(item.title, color = Color.White, fontWeight = FontWeight.SemiBold)
                    Text(item.subtitle, color = Color(0xFF8E989F), fontSize = 12.sp)
                }
                if (on) {
                    Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = HealthFitColors.Accent)
                } else {
                    Box(
                        Modifier
                            .size(22.dp)
                            .border(1.5.dp, Color(0xFF8E989F), CircleShape),
                    )
                }
            }
        }
        LinkedProSection(
            title = "Personal",
            question = "Você tem personal?",
            enabled = hasTrainer,
            onEnabled = { hasTrainer = it },
            name = trainerName,
            onName = { trainerName = it },
            email = trainerEmail,
            onEmail = { trainerEmail = it },
            hint = "Informe o e-mail para enviar a ficha de treino.",
        )
        LinkedProSection(
            title = "Nutricionista",
            question = "Você tem nutricionista?",
            enabled = hasNutri,
            onEnabled = { hasNutri = it },
            name = nutriName,
            onName = { nutriName = it },
            email = nutriEmail,
            onEmail = { nutriEmail = it },
            hint = "Cadastre o e-mail para enviar o relatório de nutrição.",
        )
        HealthIconSection(healthy = wellness.sleepHours > 0f && wellness.waterMl > 0)
        Text(
            "Sono e Hidratação",
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 16.dp),
        )
        Text(
            "O mesmo registro da tela inicial. A meta de água usa 35 ml por kg.",
            color = Color(0xFF8E989F),
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
        )
        SleepCard(hours = wellness.sleepHours, onHours = { wellness.sleepHours = it })
        Spacer(Modifier.height(12.dp))
        WaterCard(
            ml = wellness.waterMl,
            goal = wellness.goalMl,
            onMinus = { wellness.addWater(-250) },
            onPlus = { wellness.addWater(250) },
            onCup = { wellness.addWater(250) },
            onBottle = { wellness.addWater(500) },
        )
        EnergySection(energy, { energy = it }, preWorkout, { preWorkout = it })
        Spacer(Modifier.height(16.dp))
        Text("Evolução Corporal", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        DarkCard(onClick = { page = "evolution" }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.CameraAlt, contentDescription = null, tint = HealthFitColors.Accent)
                Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
                    Text("Fotos e comparativo (30 dias)", color = Color.White, fontWeight = FontWeight.SemiBold)
                    Text(
                        "Inicie o acompanhamento (fotos opcionais e privadas).",
                        color = Color(0xFF8E989F),
                        fontSize = 12.sp,
                    )
                }
                Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = Color(0xFF8E989F))
            }
        }
        Spacer(Modifier.height(10.dp))
        DarkCard {
            Text("Seus dados", color = Color.White, fontWeight = FontWeight.SemiBold)
            Text(
                "Esses dados alimentam o cálculo de calorias e o cardápio em Nutrição. A data de nascimento é obrigatória.",
                color = Color(0xFF8E989F),
                fontSize = 12.sp,
            )
            OutlinedTextField(
                wellness.weightKg,
                { wellness.weightKg = it.filter { char -> char.isDigit() || char == '.' }.take(5) },
                label = { Text("Peso (kg)") },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    focusedBorderColor = HealthFitColors.Accent,
                    unfocusedBorderColor = Color(0xFF3A4148),
                ),
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            OutlinedTextField(
                athlete.heightCm,
                { athlete.heightCm = it.filter { char -> char.isDigit() }.take(3) },
                label = { Text("Altura (cm)") },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    focusedBorderColor = HealthFitColors.Accent,
                    unfocusedBorderColor = Color(0xFF3A4148),
                ),
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            OutlinedTextField(
                birth,
                { birth = it.take(10) },
                label = { Text("Data de nascimento") },
                placeholder = { Text("dd/mm/aaaa") },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    focusedBorderColor = HealthFitColors.Accent,
                    unfocusedBorderColor = Color(0xFF3A4148),
                ),
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            Text(
                "Ajustar descanso",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 8.dp).clickable { page = "body" },
            )
        }
        Spacer(Modifier.height(10.dp))
        DarkCard(onClick = { page = "measures" }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("Medidas corporais", color = Color.White, fontWeight = FontWeight.SemiBold)
                    Text("Pescoço, cintura, quadril e demais circunferências", color = Color(0xFF8E989F), fontSize = 12.sp)
                }
                Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = Color(0xFF8E989F))
            }
        }
        Spacer(Modifier.height(16.dp))
        Text("Integrações", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        DarkCard(onClick = { page = "integrations" }) {
            IntegrationRow(Icons.Filled.Favorite, "Health Connect", "Disponível", HealthFitColors.Accent)
            IntegrationRow(Icons.Filled.Watch, "Galaxy Watch7", if (synced) "Sincronizado agora" else "Sincronização ativa", Color(0xFFB7C0C8))
            IntegrationRow(Icons.Filled.Notifications, "Notificações", "Ativas", Color(0xFFB7C0C8))
            IntegrationRow(Icons.Filled.Favorite, "Sensor Bluetooth", "Toque para parear BPM", Color(0xFFB7C0C8))
        }
        Text(
            "Passos e calorias entram pelo Health Connect. O relógio sincroniza treinos e batimentos.",
            color = Color(0xFF8E989F),
            fontSize = 12.sp,
            modifier = Modifier.padding(vertical = 8.dp),
        )
        Text("Notificações de Nutrição", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(Modifier.height(8.dp))
        DarkCard {
            ToggleRow("Notificações de suplementos", supplementsOn) { supplementsOn = it }
            ToggleRow("Notificações de alimentação", mealsOn) { mealsOn = it }
        }
        Text(
            "Suplementos: lembretes a cada 3h (06h–21h). Alimentação: alertas no horário de cada refeição.",
            color = Color(0xFF8E989F),
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 6.dp),
        )
        RestTimerSection(rest, { rest = it }, restAlert, { restAlert = it }, restNotify) { restNotify = it }
        Text("Sobre", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
        Spacer(Modifier.height(8.dp))
        DarkCard {
            Text("App", color = Color(0xFF8E989F), fontSize = 12.sp)
            Text("HealthFit", color = Color.White, fontWeight = FontWeight.SemiBold)
            Text("Versão 1.0", color = Color(0xFFB7C0C8), fontSize = 13.sp)
        }
        Text("Legal", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
        Spacer(Modifier.height(8.dp))
        DarkCard(onClick = { page = "privacy" }) {
            Text("Política de Privacidade", color = Color.White, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(8.dp))
        DarkCard(onClick = { page = "terms" }) {
            Text("Termos de Uso", color = Color.White, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(8.dp))
        DarkCard(onClick = { page = "support" }) {
            Text("Suporte", color = Color.White, fontWeight = FontWeight.SemiBold)
        }
        Text("Feedback", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
        Spacer(Modifier.height(8.dp))
        DarkCard {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("Reclamação", "Sugestão", "Melhoria", "Dúvida").forEach { kind ->
                    Text(
                        kind,
                        color = if (feedbackKind == kind) Color.Black else Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (feedbackKind == kind) HealthFitColors.Accent else Color(0xFF2A3138))
                            .clickable { feedbackKind = kind }
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                    )
                }
            }
            OutlinedTextField(
                value = feedbackText,
                onValueChange = { feedbackText = it },
                label = { Text("Escreva sua reclamação, sugestão, melhoria ou dúvida…") },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    focusedBorderColor = HealthFitColors.Accent,
                    unfocusedBorderColor = Color(0xFF3A4148),
                    cursorColor = HealthFitColors.Accent,
                    focusedLabelColor = HealthFitColors.Accent,
                    unfocusedLabelColor = Color(0xFF8E989F),
                ),
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            Text(
                if (feedbackSent) "Enviado" else "Enviar feedback",
                color = if (feedbackText.isBlank()) Color(0xFF8E989F) else Color.Black,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .padding(top = 8.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (feedbackText.isBlank()) Color(0xFF2A3138) else HealthFitColors.Accent)
                    .clickable(enabled = feedbackText.isNotBlank()) {
                        feedbackSent = true
                        feedbackText = ""
                    }
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            )
        }
        LanguageSection(language) { language = it }
        Text(
            "Excluir conta",
            color = HealthFitColors.Danger,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .padding(top = 16.dp)
                .clickable { showDelete = true },
        )
        Text(
            "Sair",
            color = HealthFitColors.Danger,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .padding(vertical = 16.dp)
                .clickable(onClick = onSignOut),
        )
        if (showDelete) {
            AlertDialog(
                onDismissRequest = { showDelete = false },
                containerColor = HealthFitColors.CardBackground,
                title = { Text("Excluir conta", color = Color.White) },
                text = { Text("A sessão local deste aparelho será encerrada.", color = Color(0xFFD5DDE3)) },
                confirmButton = {
                    TextButton(onClick = {
                        showDelete = false
                        onSignOut()
                    }) { Text("Excluir", color = HealthFitColors.Danger) }
                },
                dismissButton = {
                    TextButton(onClick = { showDelete = false }) { Text("Cancelar", color = HealthFitColors.Accent) }
                },
            )
        }
    }
}

@Composable
private fun RoleCard(
    title: String,
    icon: ImageVector,
    color: Color,
    modifier: Modifier,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier
            .height(92.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(color)
            .border(if (selected) 2.dp else 0.dp, if (selected) Color.White else Color.Transparent, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Color.White)
        Text(title, color = Color.White, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, fontSize = 13.sp)
    }
}

@Composable
private fun ProfileDetail(
    page: String,
    weight: String,
    height: String,
    rest: Int,
    synced: Boolean,
    onWeight: (String) -> Unit,
    onHeight: (String) -> Unit,
    onRest: (Int) -> Unit,
    onSync: () -> Unit,
    onBack: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text("Voltar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onBack))
        Spacer(Modifier.height(12.dp))
        when (page) {
            "evolution" -> {
                Text("Evolução corporal", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Text("Comparativo de 30 dias. As fotos ficam só neste aparelho.", color = HealthFitColors.TextSecondary)
                DarkCard(modifier = Modifier.padding(top = 12.dp)) {
                    Text("Acompanhamento iniciado", color = Color.White, fontWeight = FontWeight.SemiBold)
                    Text("Frente, lado e costas. Próxima foto sugerida em 30 dias.", color = Color(0xFF8E989F), fontSize = 13.sp)
                }
            }
            "body" -> {
                Text("Seus dados", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Text("Peso e altura alimentam o TDEE da Nutrição.", color = HealthFitColors.TextSecondary)
                listOf("60", "75", "90", "120").forEach { option ->
                    Text(
                        "Descanso $option s",
                        color = if (rest == option.toInt()) Color.Black else Color.White,
                        modifier = Modifier
                            .padding(top = 8.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (rest == option.toInt()) HealthFitColors.Accent else HealthFitColors.CardBackground)
                            .clickable { onRest(option.toInt()) }
                            .padding(12.dp),
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 12.dp)) {
                    listOf("80", "92", "100").forEach { kg ->
                        Text(
                            "$kg kg",
                            color = if (weight == kg) Color.Black else Color.White,
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(if (weight == kg) HealthFitColors.Accent else HealthFitColors.CardBackground)
                                .clickable { onWeight(kg) }
                                .padding(12.dp),
                        )
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                    listOf("165", "174", "182").forEach { cm ->
                        Text(
                            "$cm cm",
                            color = if (height == cm) Color.Black else Color.White,
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(if (height == cm) HealthFitColors.Accent else HealthFitColors.CardBackground)
                                .clickable { onHeight(cm) }
                                .padding(12.dp),
                        )
                    }
                }
            }
            else -> {
                Text("Integrações", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Text(
                    if (synced) "Galaxy Watch7 sincronizado. Passos e batimentos entram pelo Health Connect." else "Health Connect disponível. O Galaxy Watch7 sincroniza treino e BPM.",
                    color = HealthFitColors.TextSecondary,
                )
                Text(
                    if (synced) "Sincronizado" else "Sincronizar Galaxy Watch7",
                    color = if (synced) Color.Black else Color.White,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .padding(top = 16.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (synced) HealthFitColors.Accent else HealthFitColors.CardBackground)
                        .clickable(onClick = onSync)
                        .padding(14.dp),
                )
            }
        }
    }
}

@Composable
private fun IntegrationRow(icon: ImageVector, title: String, status: String, statusColor: Color) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = HealthFitColors.Accent)
        Text(title, color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f).padding(start = 10.dp))
        Text(status, color = statusColor, fontSize = 13.sp)
    }
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onChecked: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Text(label, color = Color.White, modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onChecked,
            colors = SwitchDefaults.colors(
                checkedTrackColor = HealthFitColors.Accent,
                checkedThumbColor = Color.White,
            ),
        )
    }
}
