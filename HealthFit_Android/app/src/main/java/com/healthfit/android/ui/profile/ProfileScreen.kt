package com.healthfit.android.ui.profile

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import com.healthfit.android.core.AppLanguageStore
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.R
import com.healthfit.android.ui.components.BiotypeSection
import com.healthfit.android.ui.home.ConstancyStore
import com.healthfit.android.ui.home.DailyWellness
import com.healthfit.android.ui.home.SleepCard
import com.healthfit.android.ui.home.WaterCard
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.core.billing.BillingGateway
import com.healthfit.core.model.UserProfile
import com.healthfit.designsystem.HealthFitColors
import androidx.compose.material.icons.filled.SportsTennis

private data class Modality(val title: String, val subtitle: String, val icon: ImageVector, val group: String)

@Composable
fun ProfileScreen(
    profile: UserProfile,
    wellness: DailyWellness,
    athlete: com.healthfit.android.ui.home.AthleteProfile,
    billingGateway: BillingGateway,
    onSignOut: () -> Unit,
    onDeleteAccount: suspend (password: String) -> Result<Unit>,
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
            Modality("Tênis", "Partida ou treino · placar, zonas de FC, picos e carga", Icons.Filled.SportsTennis, "CARDIO"),
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
    val language by AppLanguageStore.language.collectAsState()
    var feedbackKind by remember { mutableStateOf("Sugestão") }
    var feedbackText by remember { mutableStateOf("") }
    var feedbackSent by remember { mutableStateOf(false) }
    var showDelete by remember { mutableStateOf(false) }
    var deletePassword by remember { mutableStateOf("") }
    var deleteError by remember { mutableStateOf<String?>(null) }
    var deletingAccount by remember { mutableStateOf(false) }
    val deleteScope = rememberCoroutineScope()
    val measures = remember {
        mutableStateMapOf<String, String>().also { map ->
            map.putAll(BodyMeasurementsStore.asEditableMap(context))
        }
    }
    val evolutionStatus = remember(page) { BodyEvolutionStore.statusLabel(context) }
    if (page != "main") {
        when (page) {
            "plan" -> PlanPage(
                billingGateway = billingGateway,
                onPlanName = { plan = it },
                onBack = { page = "main" },
            )
            "measures" -> MeasuresPage(
                values = measures,
                onBack = {
                    BodyMeasurementsStore.saveCurrent(context, measures)
                    page = "main"
                },
            )
            "evolution" -> BodyEvolutionScreen(
                athleteName = nickname.ifBlank { profile.displayName },
                onBack = { page = "main" },
            )
            "privacy" -> InfoPage(
                "Política de Privacidade",
                "O HealthFit guarda sono, água, treinos e medidas neste aparelho. Fotos de evolução ficam privadas. Passos e batimentos entram pelo Health Connect quando você autoriza.",
                { page = "main" },
                url = "https://healthfit-30d87.web.app/privacidade/",
            )
            "terms" -> InfoPage(
                "Termos de Uso",
                "O HealthFit é um diário de treino e nutrição. Não substitui personal, nutricionista ou médico. Assinaturas, quando ativas, são cobradas pela Google Play.",
                { page = "main" },
                url = "https://healthfit-30d87.web.app/termos/",
            )
            "coach" -> CoachHubScreen(
                role = CoachAccountRole.fromProfileLabel(role),
                uid = profile.uid,
                hasTrainerOnProfile = hasTrainer,
                trainerName = trainerName,
                onBack = { page = "main" },
                onOpen = { page = it },
                sent = prescribed,
            )
            "coach-alunos" -> CoachStudentsScreen(onBack = { page = "coach" }, onOpenSheet = { page = "coach-fichas" })
            "coach-anamnesis" -> com.healthfit.android.ui.nutrition.NutritionAnamnesisEditorScreen(
                isCoachMode = true,
                onBack = { page = "coach" },
            )
            "coach-prescribe" -> CoachPrescribeScreen(onBack = { page = "coach" }) {
                prescribed = true
                page = "coach"
            }
            "coach-chat" -> CoachChatScreen(onBack = { page = "coach" })
            "coach-fichas" -> CoachSheetScreen(onBack = { page = "coach" })
            "coach-invite" -> CoachInviteScreen(onBack = { page = "coach" })
            "coach-join" -> CoachJoinScreen(onBack = { page = "coach" })
            "coach-search" -> DirectorySearchScreen(
                onBack = { page = "coach" },
                mode = DirectorySearchMode.Region,
            )
            "coach-student-search" -> DirectorySearchScreen(
                onBack = { page = "coach" },
                mode = DirectorySearchMode.Students,
            )
            "coach-profile-setup" -> CoachSearchPlaceholder(
                onBack = { page = "coach" },
                title = "Perfil profissional",
                body = "Cadastro CREF/CRN e visibilidade na busca — em breve com sync Firestore.",
            )
            "coach-agenda" -> CoachSearchPlaceholder(
                onBack = { page = "coach" },
                title = "Agenda de consultas",
                body = "Disponibilidade e consultas do aluno vinculado — em breve.",
            )
            "modalities" -> ModalitiesPage(
                modalities = modalities,
                active = active,
                onBack = { page = "main" },
            )
            "support" -> InfoPage(
                "Suporte",
                "Escreva para o suporte pelo formulário de feedback nesta tela, com o tipo Dúvida. A resposta usa o e-mail da sua conta.",
                { page = "main" },
                url = "https://healthfit-30d87.web.app/suporte/",
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
            stringResource(R.string.tab_profile),
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
        Text(stringResource(R.string.profile_you_are), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            RoleCard(stringResource(R.string.profile_role_student), Icons.Filled.DirectionsRun, Color(0xFF1F6B32), Modifier.weight(1f), role == "Aluno") { role = "Aluno" }
            RoleCard(stringResource(R.string.profile_role_personal), Icons.Filled.FitnessCenter, Color(0xFF1A3A6A), Modifier.weight(1f), role == "Personal") { role = "Personal" }
        }
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            RoleCard(stringResource(R.string.profile_role_nutritionist), Icons.Filled.Spa, Color(0xFF8A5A2A), Modifier.weight(1f), role == "Nutricionista") { role = "Nutricionista" }
            RoleCard(stringResource(R.string.profile_role_both), Icons.Filled.Groups, Color(0xFFB4232C), Modifier.weight(1f), role == "Personal e Nutrição") { role = "Personal e Nutrição" }
        }
        Text(
            "Aluno treina com o app. Personal e nutricionista usam como profissionais — dá para marcar os dois.",
            color = Color(0xFFB7C0C8),
            fontSize = 13.sp,
            modifier = Modifier.padding(vertical = 8.dp),
        )
        CoachEntryCard(
            role = CoachAccountRole.fromProfileLabel(role),
            uid = profile.uid,
            hasTrainerOnProfile = hasTrainer,
            trainerName = trainerName,
            onClick = { page = "coach" },
        )
        Spacer(Modifier.height(16.dp))
        BiotypeSection(athlete.bodyType) { athlete.bodyType = it }
        Spacer(Modifier.height(18.dp))
        val modalityPreview = active.take(3).joinToString(" · ").ifBlank { "Toque para escolher" }
        val extraModalities = (active.size - 3).coerceAtLeast(0)
        PracticedModalitiesCard(
            activeCount = active.size,
            preview = if (extraModalities > 0) "$modalityPreview +$extraModalities" else modalityPreview,
            onClick = { page = "modalities" },
        )
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
            stringResource(R.string.profile_sleep_hydration),
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
        SleepCard(hours = wellness.sleepHours, onHours = { wellness.updateSleep(it) })
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
        Text(stringResource(R.string.profile_body_evolution), color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        DarkCard(onClick = { page = "evolution" }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.CameraAlt, contentDescription = null, tint = HealthFitColors.Accent)
                Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
                    Text(stringResource(R.string.profile_photos_compare), color = Color.White, fontWeight = FontWeight.SemiBold)
                    Text(
                        evolutionStatus,
                        color = Color(0xFF8E989F),
                        fontSize = 12.sp,
                    )
                }
                Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = Color(0xFF8E989F))
            }
        }
        Spacer(Modifier.height(10.dp))
        DarkCard {
            Text(stringResource(R.string.profile_your_data), color = Color.White, fontWeight = FontWeight.SemiBold)
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
                "Ajustar descanso entre séries",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 8.dp).clickable { page = "body" },
            )
        }
        Spacer(Modifier.height(10.dp))
        var todayRest by remember { mutableStateOf(ConstancyStore.isTodayRestDay(context)) }
        DarkCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.profile_rest_today), color = Color.White, fontWeight = FontWeight.SemiBold)
                    Text(
                        "Aparece no calendário de Constância no Início",
                        color = Color(0xFF8E989F),
                        fontSize = 12.sp,
                    )
                }
                Switch(
                    checked = todayRest,
                    onCheckedChange = {
                        todayRest = it
                        ConstancyStore.setTodayRestDay(context, it)
                    },
                    colors = SwitchDefaults.colors(checkedTrackColor = HealthFitColors.Accent),
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        DarkCard(onClick = { page = "measures" }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.profile_body_measures), color = Color.White, fontWeight = FontWeight.SemiBold)
                    Text("Pescoço, cintura, quadril e demais circunferências", color = Color(0xFF8E989F), fontSize = 12.sp)
                }
                Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = Color(0xFF8E989F))
            }
        }
        Spacer(Modifier.height(16.dp))
        Text(stringResource(R.string.profile_integrations), color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
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
        Text(stringResource(R.string.profile_nutrition_notifications), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
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
        Text(stringResource(R.string.profile_about), color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
        Spacer(Modifier.height(8.dp))
        DarkCard {
            Text(stringResource(R.string.profile_app), color = Color(0xFF8E989F), fontSize = 12.sp)
            Text("HealthFit", color = Color.White, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.profile_version), color = Color(0xFFB7C0C8), fontSize = 13.sp)
        }
        Text(stringResource(R.string.profile_legal), color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
        Spacer(Modifier.height(8.dp))
        DarkCard(onClick = { page = "privacy" }) {
            Text(stringResource(R.string.legal_privacy), color = Color.White, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(8.dp))
        DarkCard(onClick = { page = "terms" }) {
            Text(stringResource(R.string.legal_terms), color = Color.White, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(8.dp))
        DarkCard(onClick = { page = "support" }) {
            Text(stringResource(R.string.legal_support), color = Color.White, fontWeight = FontWeight.SemiBold)
        }
        Text(stringResource(R.string.profile_feedback), color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp))
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
        LanguageSection(selected = language)
        Text(
            stringResource(R.string.profile_delete_account),
            color = HealthFitColors.Danger,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .padding(top = 16.dp)
                .clickable { showDelete = true },
        )
        Text(
            stringResource(R.string.profile_sign_out),
            color = HealthFitColors.Danger,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .padding(vertical = 16.dp)
                .clickable(onClick = onSignOut),
        )
        if (showDelete) {
            AlertDialog(
                onDismissRequest = { if (!deletingAccount) showDelete = false },
                containerColor = HealthFitColors.CardBackground,
                title = { Text(stringResource(R.string.profile_delete_account), color = Color.White) },
                text = {
                    Column {
                        Text(
                            "Apaga a conta e os dados desta pessoa no mesmo banco do iPhone: diretório, treinos, nutrição, Pulse e perfil profissional. Esta ação não desfaz.",
                            color = Color(0xFFD5DDE3),
                        )
                        OutlinedTextField(
                            value = deletePassword,
                            onValueChange = { deletePassword = it },
                            label = { Text("Senha da conta") },
                            visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation(),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = Color.White,
                                unfocusedTextColor = Color.White,
                                focusedBorderColor = HealthFitColors.Accent,
                                unfocusedBorderColor = Color(0xFF3A4148),
                                cursorColor = HealthFitColors.Accent,
                                focusedLabelColor = HealthFitColors.Accent,
                                unfocusedLabelColor = Color(0xFF8E989F),
                            ),
                            modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                        )
                        deleteError?.let {
                            Text(it, color = HealthFitColors.Danger, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
                        }
                    }
                },
                confirmButton = {
                    TextButton(
                        enabled = !deletingAccount,
                        onClick = {
                            deletingAccount = true
                            deleteError = null
                            deleteScope.launch {
                                val result = onDeleteAccount(deletePassword)
                                deletingAccount = false
                                result.onSuccess {
                                    LocalAccountWipe.clear(context)
                                    showDelete = false
                                    deletePassword = ""
                                }.onFailure { error ->
                                    deleteError = error.message ?: "Não foi possível excluir a conta."
                                }
                            }
                        },
                    ) { Text(if (deletingAccount) "Excluindo…" else "Excluir", color = HealthFitColors.Danger) }
                },
                dismissButton = {
                    TextButton(onClick = { if (!deletingAccount) showDelete = false }) {
                        Text(stringResource(R.string.common_cancel), color = HealthFitColors.Accent)
                    }
                },
            )
        }
    }
}

@Composable
private fun PracticedModalitiesCard(
    activeCount: Int,
    preview: String,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(168.dp)
            .clip(RoundedCornerShape(22.dp))
            .clickable(onClick = onClick),
    ) {
        Row(Modifier.matchParentSize()) {
            Image(
                painter = painterResource(R.drawable.cardiocovercorrida),
                contentDescription = null,
                modifier = Modifier.weight(0.55f).fillMaxHeight(),
                contentScale = ContentScale.Crop,
            )
            Column(Modifier.weight(0.45f).fillMaxHeight()) {
                Image(
                    painter = painterResource(R.drawable.cardiocoverkitesurf),
                    contentDescription = null,
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentScale = ContentScale.Crop,
                )
                Row(Modifier.weight(1f).fillMaxWidth()) {
                    Image(
                        painter = painterResource(R.drawable.fightcoverluta),
                        contentDescription = null,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
                        contentScale = ContentScale.Crop,
                    )
                    Image(
                        painter = painterResource(R.drawable.meditacaocoverfoco),
                        contentDescription = null,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
                        contentScale = ContentScale.Crop,
                    )
                }
            }
        }
        Box(
            Modifier
                .matchParentSize()
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Black.copy(alpha = 0.05f), Color.Black.copy(alpha = 0.78f)),
                    ),
                ),
        )
        Column(Modifier.align(Alignment.BottomStart).padding(16.dp)) {
            Text("PERFIL", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, fontSize = 11.sp)
            Text("Modalidades que pratico", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 22.sp)
            Text(
                "$activeCount ativas · $preview",
                color = Color.White.copy(alpha = 0.88f),
                fontSize = 13.sp,
                maxLines = 2,
            )
        }
    }
}

@Composable
private fun ModalitiesPage(
    modalities: List<Modality>,
    active: MutableList<String>,
    onBack: () -> Unit,
) {
    BackHandler(onBack = onBack)
    Column(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp, bottom = 12.dp)) {
            Text(
                "Fechar",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable(onClick = onBack).padding(8.dp),
            )
            Text(
                "Modalidades que pratico",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                modifier = Modifier.padding(start = 8.dp),
            )
        }
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
        Spacer(Modifier.height(24.dp))
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
        Text(stringResource(R.string.common_back), color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onBack))
        Spacer(Modifier.height(12.dp))
        when (page) {
            "body" -> {
                Text(stringResource(R.string.profile_your_data), color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
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
                Text(stringResource(R.string.profile_integrations), color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
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
