package com.healthfit.android.ui.profile

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.ConfirmationNumber
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import java.io.File
import com.healthfit.android.R
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.android.ui.nutrition.NutritionCareStore
import com.healthfit.core.coach.CoachCloudRepository
import com.healthfit.core.coach.CoachCloudState
import com.healthfit.core.coach.CoachLinkSnapshot
import com.healthfit.designsystem.HealthFitColors

/** Papel da conta — espelha UserAccountRole do iOS. */
enum class CoachAccountRole {
    Student,
    Personal,
    Nutritionist,
    PersonalAndNutritionist,
    ;

    val isPro: Boolean
        get() = this == Personal || this == Nutritionist || this == PersonalAndNutritionist

    companion object {
        fun fromProfileLabel(label: String): CoachAccountRole = when (label) {
            "Personal" -> Personal
            "Nutricionista" -> Nutritionist
            "Personal e Nutrição" -> PersonalAndNutritionist
            else -> Student
        }
    }
}

@Composable
fun CoachEntryCard(
    role: CoachAccountRole,
    uid: String,
    hasTrainerOnProfile: Boolean = false,
    trainerName: String = "",
    onClick: () -> Unit,
) {
    LaunchedEffect(uid) { CoachCloudRepository.start(uid) }
    val cloud by CoachCloudRepository.state.collectAsState()
    val eyebrow = when {
        role.isPro -> "PAINEL PROFISSIONAL"
        else -> "ALUNO · PERSONAL E NUTRI"
    }
    val title = when (role) {
        CoachAccountRole.Nutritionist -> "HealthFit Coach · Nutrição"
        CoachAccountRole.Personal -> "HealthFit Coach · Personal"
        CoachAccountRole.PersonalAndNutritionist -> "HealthFit Coach · Personal e Nutri"
        else -> "Seu personal e nutrição"
    }
    val subtitle = coachEntrySubtitle(role, cloud, hasTrainerOnProfile, trainerName)
    val chips = coachEntryChips(role, cloud, hasTrainerOnProfile, trainerName)

    // Mesma foto realista do iOS (`CoachCover` / `coachcover.jpg`, bytes idênticos).
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 180.dp)
            .shadow(10.dp, RoundedCornerShape(16.dp), spotColor = Color.Black.copy(alpha = 0.28f))
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick),
    ) {
        Image(
            painter = painterResource(R.drawable.coachcover),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            alignment = Alignment.Center,
            modifier = Modifier.fillMaxSize(),
        )
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Black.copy(alpha = 0.08f), Color.Black.copy(alpha = 0.72f)),
                    ),
                ),
        )
        Column(
            Modifier
                .fillMaxWidth()
                .align(Alignment.BottomStart)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(verticalAlignment = Alignment.Top) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(Color.Black.copy(alpha = 0.35f))
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                ) {
                    Icon(
                        Icons.Filled.Shield,
                        contentDescription = null,
                        tint = HealthFitColors.Accent,
                        modifier = Modifier.size(12.dp),
                    )
                    Text(
                        " $eyebrow",
                        color = HealthFitColors.Accent,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
                Spacer(Modifier.weight(1f))
                Icon(
                    Icons.Filled.ChevronRight,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.85f),
                    modifier = Modifier.size(22.dp),
                )
            }
            Text(title, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Text(
                subtitle,
                color = Color.White.copy(alpha = 0.88f),
                fontSize = 12.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                chips.take(3).forEach { Chip(it) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                if (role.isPro) {
                    Mini(Icons.Filled.Groups, "Alunos")
                    Mini(Icons.Filled.FitnessCenter, "Prescrever")
                } else {
                    Mini(Icons.Filled.FitnessCenter, "Fichas")
                    Mini(Icons.Filled.Restaurant, "Dieta")
                }
                Mini(Icons.Filled.Chat, "Chat")
            }
        }
    }
}

@Composable
fun CoachHubScreen(
    role: CoachAccountRole,
    uid: String,
    hasTrainerOnProfile: Boolean = false,
    trainerName: String = "",
    onBack: () -> Unit,
    onOpen: (String) -> Unit,
    sent: Boolean = false,
) {
    LaunchedEffect(uid) { CoachCloudRepository.start(uid) }
    val cloud by CoachCloudRepository.state.collectAsState()
    val context = LocalContext.current
    val anamnesis = NutritionCareStore.loadAnamnesis(context)
    val headerTitle = if (role.isPro) "Painel do profissional" else "Seu personal e nutrição"
    val headerSubtitle = when (role) {
        CoachAccountRole.Nutritionist ->
            "Cadastre alunos, envie cardápios atualizados, anamnese, metas e acompanhe check-ins. Chat e PDF de medidas inclusos."
        CoachAccountRole.Personal ->
            "Cadastre alunos, envie fichas de treino, avaliações e converse no chat."
        CoachAccountRole.PersonalAndNutritionist ->
            "Cadastre alunos, envie fichas e avaliações, cardápios e acompanhamento nutricional."
        else ->
            "Com plano Fit ou superior, receba fichas do personal, dietas e chat 1:1. Cardio continua livre."
    }

    HubColumn(onBack, "HealthFit Coach") {
        if (sent) {
            Text(
                "Ficha enviada ao aluno.",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(bottom = 8.dp),
            )
        }
        Text(headerTitle, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(
            headerSubtitle,
            color = HealthFitColors.TextSecondary,
            fontSize = 14.sp,
            modifier = Modifier.padding(top = 6.dp, bottom = 12.dp),
        )
        CloudSyncBanner(cloud)

        if (role.isPro) {
            ProfessionalHubSections(
                role = role,
                uid = uid,
                cloud = cloud,
                anamnesisPercent = anamnesis.completionPercent,
                onOpen = onOpen,
            )
        } else {
            StudentHubSections(
                uid = uid,
                cloud = cloud,
                hasTrainerOnProfile = hasTrainerOnProfile,
                trainerName = trainerName,
                onOpen = onOpen,
            )
        }
    }
}

@Composable
private fun CloudSyncBanner(cloud: CoachCloudState) {
    val line = when {
        !cloud.firebaseReady ->
            "Leitura na nuvem: aguarde google-services.json (Auth real). Sem writes — iOS intacto."
        cloud.writeEnabled ->
            "Sync ativo (leitura + writes)." // unreachable while WRITES_HARD_DISABLED
        cloud.readEnabled && cloud.links.isNotEmpty() ->
            "Sincronizado com iOS · só leitura · ${cloud.links.size} vínculo(s)."
        cloud.readEnabled ->
            cloud.statusMessage ?: "Leitura Coach ativa · sem vínculos neste UID."
        else ->
            cloud.statusMessage ?: "Leitura Coach desligada."
    }
    Text(
        line,
        color = HealthFitColors.Accent,
        fontSize = 12.sp,
        modifier = Modifier.padding(bottom = 12.dp),
    )
}

@Composable
private fun ProfessionalHubSections(
    role: CoachAccountRole,
    uid: String,
    cloud: CoachCloudState,
    anamnesisPercent: Int,
    onOpen: (String) -> Unit,
) {
    DarkCard {
        Text("Completar perfil profissional", color = Color.White, fontWeight = FontWeight.Bold)
        Text(
            "CREF / CRN · localização · visibilidade na busca",
            color = HealthFitColors.TextSecondary,
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 4.dp),
        )
        Text(
            "Cadastro profissional na nuvem: só leitura por enquanto (sem writes).",
            color = HealthFitColors.Accent,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
    Spacer(Modifier.height(12.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        GradientButton(
            text = "Convidar aluno",
            onClick = { onOpen("coach-invite") },
            icon = Icons.Filled.PersonAdd,
            modifier = Modifier.weight(1f),
        )
    }
    Spacer(Modifier.height(10.dp))
    OutlinedAction("Buscar alunos", Icons.Filled.Search) { onOpen("coach-student-search") }
    Spacer(Modifier.height(8.dp))
    OutlinedAction("Editar perfil profissional", Icons.Filled.Edit) { onOpen("coach-profile-setup") }
    Spacer(Modifier.height(8.dp))
    OutlinedAction(
        if (role == CoachAccountRole.Nutritionist) "Agenda de consultas (nutrição)" else "Agenda de consultas",
        Icons.Filled.CalendarMonth,
    ) { onOpen("coach-agenda") }

    Spacer(Modifier.height(18.dp))
    val myStudents = cloud.links.filter { it.coachUid == uid }
    Text(
        if (role == CoachAccountRole.Nutritionist) "Meus pacientes (nutrição)" else "Meus alunos",
        color = Color.White,
        fontWeight = FontWeight.Bold,
        fontSize = 17.sp,
    )
    if (myStudents.isEmpty()) {
        Text(
            if (role == CoachAccountRole.Nutritionist) {
                "Nenhum paciente vinculado. Gere um código de convite como nutricionista."
            } else {
                "Nenhum aluno vinculado ainda. Gere um código de convite."
            },
            color = HealthFitColors.TextSecondary,
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 6.dp, bottom = 10.dp),
        )
    } else {
        Spacer(Modifier.height(8.dp))
        myStudents.forEach { link -> LinkCard(link, cloud, asCoach = true) }
    }

    Action("Anamnese", "$anamnesisPercent% preenchida · local neste aparelho") {
        onOpen("coach-anamnesis")
    }
    Action("Prescrever", "Rascunho local · publish na nuvem ainda desligado") { onOpen("coach-prescribe") }
    Action("Chat", "Local · sync de mensagens ainda desligado") { onOpen("coach-chat") }
}

@Composable
private fun StudentHubSections(
    uid: String,
    cloud: CoachCloudState,
    hasTrainerOnProfile: Boolean,
    trainerName: String,
    onOpen: (String) -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        GradientButton(
            text = "Entrar com código",
            onClick = { onOpen("coach-join") },
            icon = Icons.Filled.ConfirmationNumber,
            modifier = Modifier.weight(1f),
        )
    }
    Spacer(Modifier.height(10.dp))
    OutlinedAction("Buscar na região", Icons.Filled.LocationOn) { onOpen("coach-search") }

    Spacer(Modifier.height(18.dp))
    Text("Meus profissionais", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 17.sp)
    val myPros = cloud.links.filter { it.studentUid == uid }
    if (myPros.isEmpty()) {
        val empty = when {
            hasTrainerOnProfile ->
                "Seu personal/nutri está no perfil. Vincule também pelo HealthFit Coach para fichas e chat no app."
            else ->
                "Você ainda não tem personal ou nutricionista vinculado no app."
        }
        Text(
            empty,
            color = HealthFitColors.TextSecondary,
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 6.dp, bottom = 10.dp),
        )
        if (hasTrainerOnProfile) {
            DarkCard(modifier = Modifier.padding(bottom = 10.dp)) {
                Text(
                    if (trainerName.isNotBlank()) trainerName else "Personal no perfil",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    "Cadastrado no Perfil · vincule no Coach para fichas e chat",
                    color = HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    } else {
        Spacer(Modifier.height(8.dp))
        myPros.forEach { link -> LinkCard(link, cloud, asCoach = false) }
    }
    DarkCard {
        Text(
            "Antes de vincular, confira no Brasil se o CREF (CONFEF) ou o CRN (CFN) do profissional está ativo. O HealthFit não substitui a consulta oficial nos conselhos.",
            color = HealthFitColors.TextSecondary,
            fontSize = 12.sp,
        )
    }
}

@Composable
private fun LinkCard(link: CoachLinkSnapshot, cloud: CoachCloudState, asCoach: Boolean) {
    val title = if (asCoach) link.studentName else link.coachName
    val sheets = cloud.assignedFor(link.id)
    val meal = cloud.mealPlanFor(link.id)
    DarkCard(modifier = Modifier.padding(bottom = 10.dp)) {
        Text(title, color = Color.White, fontWeight = FontWeight.Bold)
        Text(
            "${link.professionLabel} · ${link.statusLabel}",
            color = HealthFitColors.Accent,
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 2.dp),
        )
        if (sheets.isNotEmpty()) {
            Text(
                sheets.joinToString(" · ") { it.sheetTitle }.take(120),
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
                maxLines = 2,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
        if (meal?.hasWeeklyPlan == true) {
            Text(
                "Cardápio prescrito${meal.coachName?.let { " · $it" }.orEmpty()}",
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
        if (sheets.isEmpty() && meal?.hasWeeklyPlan != true) {
            Text(
                if (asCoach) "Sem ficha/cardápio publicado neste vínculo."
                else "Aguardando ficha ou cardápio do profissional.",
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
    }
}

private fun coachEntrySubtitle(
    role: CoachAccountRole,
    cloud: CoachCloudState,
    hasTrainerOnProfile: Boolean,
    trainerName: String,
): String {
    if (role.isPro) {
        val count = cloud.links.count { it.isActiveLike }
        return when (role) {
            CoachAccountRole.PersonalAndNutritionist ->
                if (count == 0) "Cadastre alunos, envie fichas, avaliações e cardápios."
                else "$count aluno(s) · treinos, avaliações e nutrição"
            CoachAccountRole.Personal ->
                if (count == 0) "Cadastre alunos, envie fichas e avaliações físicas."
                else "$count aluno(s) · fichas, medidas e PDF"
            CoachAccountRole.Nutritionist ->
                if (count == 0) "Cadastre alunos, envie cardápios e acompanhe em Nutrição."
                else "$count aluno(s) · cardápio, anamnese e check-in"
            else -> "Cadastre alunos, envie fichas e cardápios."
        }
    }
    val personal = cloud.activePersonal
    val nutri = cloud.activeNutrition
    if (personal != null && nutri != null) return "${personal.coachName} · ${nutri.coachName}"
    if (personal != null) return "Personal: ${personal.coachName} · ${personal.statusLabel}"
    if (nutri != null) return "Nutri: ${nutri.coachName} · ${nutri.statusLabel}"
    if (hasTrainerOnProfile && trainerName.isNotBlank()) return "Personal no perfil: $trainerName"
    if (hasTrainerOnProfile) return "Personal cadastrado no perfil."
    return "Vincule personal ou nutri com código ou busca regional."
}

private fun coachEntryChips(
    role: CoachAccountRole,
    cloud: CoachCloudState,
    hasTrainerOnProfile: Boolean,
    trainerName: String,
): List<String> {
    if (role.isPro) {
        val students = cloud.links.count { it.isActiveLike }
        return listOf(
            if (students == 0) "Sem alunos" else "$students aluno${if (students == 1) "" else "s"}",
            if (cloud.readEnabled) "Nuvem · leitura" else "Local",
        )
    }
    val chips = mutableListOf<String>()
    val personal = cloud.activePersonal
    if (personal != null) {
        chips += "Personal · ${personal.statusLabel}"
    } else if (hasTrainerOnProfile) {
        chips += if (trainerName.isNotBlank()) "Personal · $trainerName" else "Personal no perfil"
    }
    cloud.activeNutrition?.let { chips += "Nutri · ${it.statusLabel}" }
    if (chips.isEmpty()) chips += if (cloud.readEnabled) "Pronto para vincular" else "Local"
    return chips
}

@Composable
fun CoachInviteScreen(onBack: () -> Unit) {
    HubColumn(onBack, "Convidar aluno") {
        Text(
            "Gere um código para o aluno entrar no HealthFit Coach.",
            color = HealthFitColors.TextSecondary,
            fontSize = 14.sp,
        )
        Spacer(Modifier.height(12.dp))
        DarkCard {
            Text("Código", color = HealthFitColors.TextSecondary, fontSize = 12.sp)
            Text("HF-DEMO1", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Text(
                "Compartilhe com o aluno. Sync Firestore em breve — por enquanto é demonstração.",
                color = HealthFitColors.TextSecondary,
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

@Composable
fun CoachJoinScreen(onBack: () -> Unit) {
    var code by remember { mutableStateOf("") }
    HubColumn(onBack, "Entrar com código") {
        Text(
            "Digite o código que o personal ou nutricionista compartilhou.",
            color = HealthFitColors.TextSecondary,
            fontSize = 14.sp,
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            code,
            { code = it },
            label = { Text("Código") },
            colors = fieldColors(),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        GradientButton("Vincular", onClick = onBack)
    }
}

@Composable
fun CoachSearchPlaceholder(onBack: () -> Unit, title: String, body: String) {
    HubColumn(onBack, title) {
        Text(body, color = HealthFitColors.TextSecondary, fontSize = 14.sp)
        Spacer(Modifier.height(12.dp))
        DarkCard {
            Text(
                "Busca regional e vínculos na nuvem chegam com o sync Firestore (igual ao iOS).",
                color = HealthFitColors.TextSecondary,
                fontSize = 13.sp,
            )
        }
    }
}

@Composable
fun CoachStudentsScreen(onBack: () -> Unit, onOpenSheet: () -> Unit) {
    HubColumn(onBack, "Alunos") {
        DarkCard(onClick = onOpenSheet) {
            Text("Aluno vinculado", color = Color.White, fontWeight = FontWeight.Bold)
            Text("Ficha ativa: Treino — Peito + Tríceps", color = Color(0xFFB7C0C8), fontSize = 13.sp)
            Text("Toque para abrir a ficha", color = HealthFitColors.Accent, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
        }
    }
}

@Composable
fun CoachPrescribeScreen(onBack: () -> Unit, onSent: () -> Unit) {
    var name by remember { mutableStateOf("Treino — Peito + Tríceps") }
    HubColumn(onBack, "Prescrever") {
        OutlinedTextField(
            name,
            { name = it },
            label = { Text("Nome da ficha") },
            colors = fieldColors(),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        GradientButton("Enviar ao aluno", onClick = onSent)
    }
}

@Composable
fun CoachChatScreen(onBack: () -> Unit) {
    val messages = remember { mutableStateListOf("Berg: Ficha de peito enviada.") }
    var draft by remember { mutableStateOf("") }
    HubColumn(onBack, "Chat") {
        messages.forEach { line ->
            Text(line, color = Color.White, modifier = Modifier.padding(vertical = 4.dp))
        }
        OutlinedTextField(
            draft,
            { draft = it },
            label = { Text("Mensagem") },
            colors = fieldColors(),
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        )
        Spacer(Modifier.height(8.dp))
        GradientButton("Enviar", {
            if (draft.isNotBlank()) {
                messages.add("Você: ${draft.trim()}")
                draft = ""
            }
        })
    }
}

@Composable
fun CoachSheetScreen(onBack: () -> Unit) {
    val moves = listOf("Supino reto", "Supino inclinado", "Crucifixo", "Tríceps pulley", "Tríceps testa")
    HubColumn(onBack, "Treino — Peito + Tríceps") {
        Text("Prescrita por Berg Limma · 13 exercícios · ~73 min", color = Color(0xFFB7C0C8))
        moves.forEach { move ->
            DarkCard(modifier = Modifier.padding(top = 8.dp)) {
                Text(move, color = Color.White, fontWeight = FontWeight.SemiBold)
                Text("4 séries · GIF no treino", color = Color(0xFF8E989F), fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun ProfileCover(
    coverFile: File?,
    avatarFile: File?,
    name: String,
    email: String,
    onChangeCover: () -> Unit,
    onChangeAvatar: () -> Unit,
    onClearCover: () -> Unit,
    onClearAvatar: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(168.dp)
            .clip(RoundedCornerShape(18.dp))
            .clickable(onClick = onChangeCover),
    ) {
        if (coverFile != null) {
            AsyncImage(
                model = coverFile,
                contentDescription = "Foto de fundo",
                modifier = Modifier.matchParentSize(),
                contentScale = ContentScale.Crop,
            )
        } else {
            androidx.compose.foundation.Image(
                painter = painterResource(R.drawable.cardiocovercaminhada),
                contentDescription = "Foto de fundo",
                modifier = Modifier.matchParentSize(),
                contentScale = ContentScale.Crop,
            )
        }
        Text(
            if (coverFile == null) "Toque para foto de fundo" else "Alterar fundo",
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(10.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black.copy(alpha = 0.45f))
                .padding(horizontal = 10.dp, vertical = 6.dp),
        )
        if (coverFile != null) {
            Text(
                "✕",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(8.dp)
                    .clip(CircleShape)
                    .background(Color.Black.copy(alpha = 0.45f))
                    .clickable(onClick = onClearCover)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            )
        }
    }
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 10.dp, bottom = 8.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF1F6B32))
                    .clickable(onClick = onChangeAvatar),
                contentAlignment = Alignment.Center,
            ) {
                if (avatarFile != null) {
                    AsyncImage(
                        model = avatarFile,
                        contentDescription = "Foto do perfil",
                        modifier = Modifier.matchParentSize(),
                        contentScale = ContentScale.Crop,
                    )
                } else {
                    Text(
                        name.firstOrNull()?.uppercase().orEmpty(),
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 28.sp,
                    )
                }
            }
            Text(
                if (avatarFile == null) "Foto" else "Remover",
                color = if (avatarFile == null) HealthFitColors.Accent else Color(0xFFFF6B6B),
                fontSize = 11.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(top = 4.dp)
                    .clickable(onClick = if (avatarFile == null) onChangeAvatar else onClearAvatar),
            )
        }
        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Text(name, color = Color.White, fontWeight = FontWeight.Bold)
            Text(email, color = Color(0xFFB7C0C8), fontSize = 12.sp)
            Text("🇧🇷 Brasil", color = Color(0xFFB7C0C8), fontSize = 12.sp)
            Text("Toque no avatar ou no fundo para a galeria", color = HealthFitColors.Accent, fontSize = 12.sp)
        }
    }
}

@Composable
private fun HubColumn(onBack: () -> Unit, title: String, content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .clickable(onClick = onBack)
                .padding(bottom = 4.dp),
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = null,
                tint = HealthFitColors.Accent,
                modifier = Modifier.size(20.dp),
            )
            Text(
                " Voltar",
                color = HealthFitColors.Accent,
                fontWeight = FontWeight.SemiBold,
            )
        }
        Text(
            title,
            color = Color.White,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(vertical = 10.dp),
        )
        content()
    }
}

@Composable
private fun Action(title: String, subtitle: String, onClick: () -> Unit) {
    DarkCard(onClick = onClick, modifier = Modifier.padding(top = 10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(title, color = Color.White, fontWeight = FontWeight.Bold)
                Text(subtitle, color = Color(0xFFB7C0C8), fontSize = 13.sp)
            }
            Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = HealthFitColors.TextSecondary)
        }
    }
}

@Composable
private fun OutlinedAction(title: String, icon: ImageVector, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, Color(0xFF3A4148), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp, horizontal = 12.dp),
    ) {
        Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
        Text("  $title", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
    }
}

@Composable
private fun Chip(text: String) {
    Text(
        text,
        color = Color.White.copy(alpha = 0.95f),
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        maxLines = 1,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(Color.White.copy(alpha = 0.14f))
            .padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

@Composable
private fun Mini(icon: ImageVector, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = Color.White.copy(alpha = 0.9f), modifier = Modifier.size(14.dp))
        Text(" $label", color = Color.White.copy(alpha = 0.9f), fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun fieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = Color.White,
    unfocusedTextColor = Color.White,
    focusedBorderColor = HealthFitColors.Accent,
    unfocusedBorderColor = Color(0xFF3A4148),
    focusedLabelColor = HealthFitColors.Accent,
    unfocusedLabelColor = HealthFitColors.TextSecondary,
    cursorColor = HealthFitColors.Accent,
)
