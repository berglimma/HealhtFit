package com.healthfit.android.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.auth.FirebaseAuth
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.android.ui.components.GradientButton
import com.healthfit.core.coach.AppConfigAndroid
import com.healthfit.core.directory.DirectoryPerson
import com.healthfit.core.directory.DirectoryProfessional
import com.healthfit.core.directory.DirectorySearch
import com.healthfit.core.directory.ProfessionFilter
import com.healthfit.designsystem.HealthFitColors
import kotlinx.coroutines.launch

enum class DirectorySearchMode {
    /** Personal, nutricionista e pessoas no mesmo banco do iPhone. */
    Region,
    /** Alunos: `userDirectory`, igual a `CoachService.searchStudents` no iOS. */
    Students,
}

@Composable
fun DirectorySearchScreen(onBack: () -> Unit, mode: DirectorySearchMode) {
    var query by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("") }
    var stateCode by remember { mutableStateOf("") }
    var filter by remember {
        mutableStateOf(
            if (mode == DirectorySearchMode.Students) ResultKind.People else ResultKind.Personal,
        )
    }
    var people by remember { mutableStateOf<List<DirectoryPerson>>(emptyList()) }
    var professionals by remember { mutableStateOf<List<DirectoryProfessional>>(emptyList()) }
    var status by remember { mutableStateOf<String?>(null) }
    var searching by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val firebaseReady = remember { AppConfigAndroid.isFirebaseReady() }

    fun runSearch() {
        if (!firebaseReady) {
            status = "Entre com a mesma conta do iPhone. O Firebase deste aparelho ainda não está ligado."
            return
        }
        scope.launch {
            searching = true
            status = null
            val uid = runCatching { FirebaseAuth.getInstance().currentUser?.uid }.getOrNull()
            runCatching {
                when {
                    mode == DirectorySearchMode.Students || filter == ResultKind.People -> {
                        professionals = emptyList()
                        people = DirectorySearch.searchPeople(query, excludingUid = uid)
                    }
                    else -> {
                        people = emptyList()
                        professionals = DirectorySearch.searchProfessionals(
                            name = query,
                            profession = if (filter == ResultKind.Nutritionist) {
                                ProfessionFilter.Nutritionist
                            } else {
                                ProfessionFilter.Personal
                            },
                            city = city,
                            stateCode = stateCode,
                        )
                    }
                }
            }.onFailure {
                status = it.message ?: "Não foi possível buscar agora."
            }
            searching = false
        }
    }

    LaunchedEffect(mode) {
        if (firebaseReady && mode == DirectorySearchMode.Region) runSearch()
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.clickable(onClick = onBack).padding(bottom = 8.dp),
        ) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, tint = HealthFitColors.Accent)
            Text(" Voltar", color = HealthFitColors.Accent, fontWeight = FontWeight.SemiBold)
        }
        Text(
            if (mode == DirectorySearchMode.Students) "Buscar alunos" else "Buscar na região",
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
        )
        Text(
            "Mesmo banco do iPhone: diretório de pessoas e perfis de personal e nutricionista.",
            color = HealthFitColors.TextSecondary,
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
        )
        if (mode == DirectorySearchMode.Region) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip("Personal", filter == ResultKind.Personal) { filter = ResultKind.Personal }
                FilterChip("Nutri", filter == ResultKind.Nutritionist) { filter = ResultKind.Nutritionist }
                FilterChip("Pessoas", filter == ResultKind.People) { filter = ResultKind.People }
            }
            Spacer(Modifier.height(12.dp))
        }
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            label = {
                Text(
                    if (mode == DirectorySearchMode.Students || filter == ResultKind.People) {
                        "Nome, apelido ou e-mail"
                    } else {
                        "Nome do profissional"
                    },
                )
            },
            colors = searchFieldColors(),
            modifier = Modifier.fillMaxWidth(),
        )
        if (mode == DirectorySearchMode.Region && filter != ResultKind.People) {
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = city,
                    onValueChange = { city = it },
                    label = { Text("Cidade") },
                    colors = searchFieldColors(),
                    modifier = Modifier.weight(1f),
                )
                OutlinedTextField(
                    value = stateCode,
                    onValueChange = { stateCode = it.take(2).uppercase() },
                    label = { Text("UF") },
                    colors = searchFieldColors(),
                    modifier = Modifier.weight(0.4f),
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        GradientButton(if (searching) "Buscando…" else "Buscar", onClick = { if (!searching) runSearch() })
        status?.let {
            Text(it, color = HealthFitColors.TextSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 12.dp))
        }
        Spacer(Modifier.height(12.dp))
        if (people.isEmpty() && professionals.isEmpty() && !searching && status == null && query.isNotBlank()) {
            Text("Nenhum resultado.", color = HealthFitColors.TextSecondary, fontSize = 13.sp)
        }
        professionals.forEach { pro ->
            DarkCard {
                Text(pro.displayName.ifBlank { "Profissional" }, color = Color.White, fontWeight = FontWeight.SemiBold)
                Text(pro.roleLabel, color = HealthFitColors.Accent, fontSize = 12.sp)
                if (pro.placeLabel.isNotBlank()) {
                    Text(pro.placeLabel, color = Color(0xFFB7C0C8), fontSize = 12.sp)
                }
                val credential = listOfNotNull(
                    pro.cref?.takeIf { it.isNotBlank() }?.let { "CREF $it" },
                    pro.crn?.takeIf { it.isNotBlank() }?.let { "CRN $it" },
                ).joinToString(" · ")
                if (credential.isNotBlank()) {
                    Text(credential, color = Color(0xFFB7C0C8), fontSize = 12.sp)
                }
                if (pro.bio.isNotBlank()) {
                    Text(pro.bio, color = HealthFitColors.TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
                }
            }
            Spacer(Modifier.height(8.dp))
        }
        people.forEach { person ->
            DarkCard {
                Text(person.shownName.ifBlank { "Pessoa" }, color = Color.White, fontWeight = FontWeight.SemiBold)
                if (person.name.isNotBlank() && person.name != person.shownName) {
                    Text(person.name, color = Color(0xFFB7C0C8), fontSize = 12.sp)
                }
                Text(
                    if (person.hasPersonalTrainer) "Já tem personal" else "Sem personal no perfil",
                    color = HealthFitColors.TextSecondary,
                    fontSize = 12.sp,
                )
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

private enum class ResultKind { Personal, Nutritionist, People }

@Composable
private fun FilterChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        label,
        color = if (selected) Color.Black else Color.White,
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) HealthFitColors.Accent else Color(0xFF2A3138))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
    )
}

@Composable
private fun searchFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = Color.White,
    unfocusedTextColor = Color.White,
    focusedBorderColor = HealthFitColors.Accent,
    unfocusedBorderColor = Color(0xFF3A4148),
    cursorColor = HealthFitColors.Accent,
    focusedLabelColor = HealthFitColors.Accent,
    unfocusedLabelColor = Color(0xFF8E989F),
)
