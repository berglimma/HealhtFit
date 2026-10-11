package com.healthfit.android.ui.nutrition

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.healthfit.android.ui.components.DarkCard
import com.healthfit.designsystem.HealthFitColors
import java.util.UUID

private enum class ShoppingCategory(val title: String) {
    Proteins("Proteínas"),
    Vegetables("Vegetais"),
    Fruits("Frutas"),
    Grains("Grãos"),
    Dairy("Laticínios"),
    Supplements("Suplementos"),
    Other("Outros"),
}

private data class ShoppingItem(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val quantity: String,
    val category: ShoppingCategory,
    var purchased: Boolean = false,
)

private val WhoEnergyDrinkWarning =
    "A OMS recomenda limitar bebidas energéticas e açucaradas. Em adultos saudáveis, a cafeína total não deve ultrapassar cerca de 400 mg por dia. A ingestão de açúcares livres deve ficar abaixo de 10% das calorias diárias (idealmente 5%). Mais de 2 energéticos por semana pode elevar cafeína e açúcar acima do recomendado, com riscos para sono, pressão arterial e coração."

@Composable
fun ShoppingListScreen(onBack: () -> Unit) {
    BackHandler(onBack = onBack)

    val items = remember {
        mutableStateListOf<ShoppingItem>().also { list ->
            list.addAll(defaultShoppingList())
        }
    }
    var search by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf<ShoppingCategory?>(null) }
    var energyDrinks by remember { mutableIntStateOf(0) }
    var showReport by remember { mutableStateOf(false) }
    var showAddCustom by remember { mutableStateOf(false) }
    var customName by remember { mutableStateOf("") }

    fun syncEnergyItem(count: Int) {
        items.removeAll { it.name.equals("Energético", ignoreCase = true) }
        if (count > 0) {
            items.add(
                0,
                ShoppingItem(
                    name = "Energético",
                    quantity = "$count un/semana",
                    category = ShoppingCategory.Other,
                ),
            )
        }
    }

    fun regenerate() {
        val purchasedNames = items.filter { it.purchased }.map { it.name.lowercase() }.toSet()
        items.clear()
        items.addAll(
            defaultShoppingList().map { item ->
                item.copy(purchased = item.name.lowercase() in purchasedNames)
            },
        )
        syncEnergyItem(energyDrinks)
    }

    val query = search.trim().lowercase()
    val filtered = items.filter { item ->
        val catOk = selectedCategory == null || item.category == selectedCategory
        val searchOk = query.isEmpty() ||
            item.name.lowercase().contains(query) ||
            item.category.title.lowercase().contains(query)
        catOk && searchOk
    }
    val purchasedCount = items.count { it.purchased }
    val grouped = ShoppingCategory.entries.mapNotNull { cat ->
        val group = filtered.filter { it.category == cat }
        if (group.isEmpty()) null else cat to group
    }

    if (showReport) {
        ShoppingWeeklyReport(
            items = items.toList(),
            energyDrinks = energyDrinks,
            onClose = { showReport = false },
        )
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background),
    ) {
        // Top bar — voltar + título + ações (como toolbar iOS)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .clickable(onClick = onBack),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Voltar",
                    tint = HealthFitColors.Accent,
                )
            }
            Text(
                "Lista de Compras",
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .clickable {
                        customName = ""
                        showAddCustom = true
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Add, contentDescription = "Adicionar", tint = HealthFitColors.Accent)
            }
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .clickable { regenerate() },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Refresh, contentDescription = "Regenerar lista", tint = HealthFitColors.Accent)
            }
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 20.dp),
        ) {
            // Search
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(HealthFitColors.CardBackground)
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Search, contentDescription = null, tint = Color(0xFF8E989F), modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                BasicTextField(
                    value = search,
                    onValueChange = { search = it },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    textStyle = TextStyle(color = Color.White, fontSize = 14.sp),
                    cursorBrush = SolidColor(HealthFitColors.Accent),
                    decorationBox = { inner ->
                        if (search.isEmpty()) {
                            Text("Buscar proteínas, vegetais, frutas...", color = Color(0xFF8E989F), fontSize = 14.sp)
                        }
                        inner()
                    },
                )
            }

            if (query.isNotEmpty() || selectedCategory != null) {
                Spacer(Modifier.height(10.dp))
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    CategoryChip("Todos", selectedCategory == null) { selectedCategory = null }
                    ShoppingCategory.entries.filter { it != ShoppingCategory.Other }.forEach { cat ->
                        CategoryChip(cat.title, selectedCategory == cat) {
                            selectedCategory = if (selectedCategory == cat) null else cat
                        }
                    }
                }
            }

            Spacer(Modifier.height(14.dp))

            // Summary — Lista Semanal
            DarkCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Lista Semanal", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                        Text(
                            "$purchasedCount/${items.size} itens comprados",
                            color = Color(0xFF8E989F),
                            fontSize = 12.sp,
                            modifier = Modifier.padding(top = 2.dp),
                        )
                    }
                    Icon(Icons.Filled.ShoppingCart, contentDescription = null, tint = HealthFitColors.Accent)
                }
                Spacer(Modifier.height(10.dp))
                LinearProgressIndicator(
                    progress = { if (items.isEmpty()) 0f else purchasedCount / items.size.toFloat() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(RoundedCornerShape(4.dp)),
                    color = HealthFitColors.Accent,
                    trackColor = Color(0xFF2A3238),
                )
                Spacer(Modifier.height(12.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color(0xFF15241C))
                        .clickable { showReport = true }
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Description, contentDescription = null, tint = HealthFitColors.Accent, modifier = Modifier.size(18.dp))
                    Text(
                        "Relatório de compras da semana",
                        color = HealthFitColors.Accent,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 13.sp,
                        modifier = Modifier.padding(start = 8.dp),
                    )
                }
            }

            Spacer(Modifier.height(14.dp))

            // Energy drinks — Bebidas
            DarkCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Bolt, contentDescription = null, tint = HealthFitColors.Accent)
                    Text(
                        "Bebidas",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        modifier = Modifier.padding(start = 8.dp),
                    )
                }
                Spacer(Modifier.height(10.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Energéticos por semana", color = Color.White, fontWeight = FontWeight.Medium, fontSize = 14.sp)
                        Text(
                            if (energyDrinks == 0) "Toque em + para incluir na lista"
                            else "$energyDrinks un na lista de compras",
                            color = Color(0xFF8E989F),
                            fontSize = 12.sp,
                        )
                    }
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .clickable(enabled = energyDrinks > 0) {
                                energyDrinks = (energyDrinks - 1).coerceAtLeast(0)
                                syncEnergyItem(energyDrinks)
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Filled.Remove,
                            contentDescription = "Menos",
                            tint = if (energyDrinks > 0) HealthFitColors.Accent else Color(0xFF555555),
                        )
                    }
                    Text(
                        "$energyDrinks",
                        color = HealthFitColors.Accent,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 10.dp),
                    )
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .clickable(enabled = energyDrinks < 14) {
                                energyDrinks = (energyDrinks + 1).coerceAtMost(14)
                                syncEnergyItem(energyDrinks)
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Filled.Add,
                            contentDescription = "Mais",
                            tint = if (energyDrinks < 14) HealthFitColors.Accent else Color(0xFF555555),
                        )
                    }
                }
                if (energyDrinks > 2) {
                    Spacer(Modifier.height(10.dp))
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color(0xFF3A2818))
                            .padding(12.dp),
                    ) {
                        Text("Alerta OMS", color = Color(0xFFFF9A3C), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text(
                            WhoEnergyDrinkWarning,
                            color = Color(0xFFB7C0C8),
                            fontSize = 12.sp,
                            modifier = Modifier.padding(top = 6.dp),
                        )
                    }
                }
                Text(
                    "Use + e − para ajustar a quantidade. O número entra na lista de compras.",
                    color = Color(0xFF8E989F),
                    fontSize = 11.sp,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }

            Spacer(Modifier.height(16.dp))

            if (grouped.isEmpty()) {
                Text(
                    "Nenhum item na lista. Use + para adicionar ou toque em regenerar.",
                    color = Color(0xFF8E989F),
                    fontSize = 13.sp,
                )
            } else {
                grouped.forEach { (category, group) ->
                    Text(
                        category.title,
                        color = HealthFitColors.Accent,
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp,
                        modifier = Modifier.padding(bottom = 8.dp, top = 4.dp),
                    )
                    group.forEach { item ->
                        val index = items.indexOfFirst { it.id == item.id }
                        ShoppingRow(
                            item = item,
                            onToggle = {
                                if (index >= 0) {
                                    items[index] = items[index].copy(purchased = !items[index].purchased)
                                }
                            },
                        )
                        Spacer(Modifier.height(8.dp))
                    }
                    if (category == ShoppingCategory.Supplements) {
                        Text(
                            "Pré-treino: limite de cafeína até ~400 mg/dia.",
                            color = Color(0xFF8E989F),
                            fontSize = 11.sp,
                            modifier = Modifier.padding(bottom = 10.dp),
                        )
                    }
                }
            }
        }
    }

    if (showAddCustom) {
        AddCustomItemDialog(
            name = customName,
            onNameChange = { customName = it },
            onDismiss = { showAddCustom = false },
            onConfirm = {
                val clean = customName.trim()
                if (clean.isNotEmpty()) {
                    items.add(
                        ShoppingItem(
                            name = clean,
                            quantity = "1 un",
                            category = ShoppingCategory.Other,
                        ),
                    )
                }
                showAddCustom = false
            },
        )
    }
}

@Composable
private fun CategoryChip(title: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        title,
        color = if (selected) Color.Black else Color.White,
        fontWeight = FontWeight.SemiBold,
        fontSize = 12.sp,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(if (selected) HealthFitColors.Accent else HealthFitColors.CardBackground)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
    )
}

@Composable
private fun ShoppingRow(item: ShoppingItem, onToggle: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(HealthFitColors.CardBackground)
            .clickable(onClick = onToggle)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (item.purchased) {
            Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = HealthFitColors.Accent)
        } else {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .border(1.5.dp, Color(0xFF8E989F), CircleShape),
            )
        }
        Column(modifier = Modifier.padding(start = 12.dp).weight(1f)) {
            Text(
                item.name,
                color = if (item.purchased) Color(0xFF8E989F) else Color.White,
                fontWeight = FontWeight.Medium,
                textDecoration = if (item.purchased) TextDecoration.LineThrough else null,
            )
            Text(item.quantity, color = Color(0xFF8E989F), fontSize = 12.sp)
        }
    }
}

@Composable
private fun AddCustomItemDialog(
    name: String,
    onNameChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.55f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth(0.9f)
                .clip(RoundedCornerShape(18.dp))
                .background(HealthFitColors.CardBackground)
                .clickable(enabled = false) {}
                .padding(18.dp),
        ) {
            Text("Item personalizado", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            Spacer(Modifier.height(12.dp))
            BasicTextField(
                value = name,
                onValueChange = onNameChange,
                singleLine = true,
                textStyle = TextStyle(color = Color.White, fontSize = 15.sp),
                cursorBrush = SolidColor(HealthFitColors.Accent),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFF12181C))
                    .padding(14.dp),
                decorationBox = { inner ->
                    if (name.isEmpty()) Text("Nome do item", color = Color(0xFF8E989F))
                    inner()
                },
            )
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "Cancelar",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color(0xFF2A3238))
                        .clickable(onClick = onDismiss)
                        .padding(vertical = 12.dp),
                    textAlign = TextAlign.Center,
                )
                Text(
                    "Adicionar",
                    color = Color.Black,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .background(HealthFitColors.Accent)
                        .clickable(onClick = onConfirm)
                        .padding(vertical = 12.dp),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun ShoppingWeeklyReport(
    items: List<ShoppingItem>,
    energyDrinks: Int,
    onClose: () -> Unit,
) {
    BackHandler(onBack = onClose)
    val purchased = items.filter { it.purchased }
    val pending = items.filter { !it.purchased }
    val pct = if (items.isEmpty()) 0 else purchased.size * 100 / items.size

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(HealthFitColors.Background),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .clickable(onClick = onClose),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Voltar", tint = HealthFitColors.Accent)
            }
            Text(
                "Relatório Semanal",
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            DarkCard {
                Text("Esta semana", color = Color.White, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    ReportMetric("${purchased.size}/${items.size}", "Comprados")
                    ReportMetric("$pct%", "Progresso")
                    ReportMetric("$energyDrinks", "Energéticos")
                }
            }
            if (purchased.isNotEmpty()) {
                Spacer(Modifier.height(14.dp))
                Text("Comprados", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                purchased.forEach {
                    Text("• ${it.name} — ${it.quantity}", color = Color.White, fontSize = 13.sp, modifier = Modifier.padding(bottom = 4.dp))
                }
            }
            if (pending.isNotEmpty()) {
                Spacer(Modifier.height(14.dp))
                Text("Pendentes", color = HealthFitColors.Accent, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                pending.forEach {
                    Text("• ${it.name} — ${it.quantity}", color = Color(0xFFB7C0C8), fontSize = 13.sp, modifier = Modifier.padding(bottom = 4.dp))
                }
            }
        }
    }
}

@Composable
private fun ReportMetric(value: String, label: String) {
    Column {
        Text(value, color = HealthFitColors.Accent, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(label, color = Color(0xFF8E989F), fontSize = 11.sp)
    }
}

private fun defaultShoppingList(): List<ShoppingItem> = listOf(
    // Proteínas
    ShoppingItem(name = "Peito de frango", quantity = "1 kg", category = ShoppingCategory.Proteins),
    ShoppingItem(name = "Ovos", quantity = "1 dúzia", category = ShoppingCategory.Proteins),
    ShoppingItem(name = "Claras", quantity = "500 ml", category = ShoppingCategory.Proteins),
    ShoppingItem(name = "Carne magra", quantity = "500 g", category = ShoppingCategory.Proteins),
    ShoppingItem(name = "Atum em lata", quantity = "2 un", category = ShoppingCategory.Proteins),
    // Vegetais
    ShoppingItem(name = "Alface", quantity = "1 un", category = ShoppingCategory.Vegetables),
    ShoppingItem(name = "Tomate", quantity = "4 un", category = ShoppingCategory.Vegetables),
    ShoppingItem(name = "Cenoura", quantity = "500 g", category = ShoppingCategory.Vegetables),
    // Frutas
    ShoppingItem(name = "Banana", quantity = "1 cacho", category = ShoppingCategory.Fruits),
    ShoppingItem(name = "Maçã", quantity = "6 un", category = ShoppingCategory.Fruits),
    ShoppingItem(name = "Morango", quantity = "1 pote", category = ShoppingCategory.Fruits),
    // Grãos
    ShoppingItem(name = "Arroz integral", quantity = "1 kg", category = ShoppingCategory.Grains),
    ShoppingItem(name = "Aveia", quantity = "500 g", category = ShoppingCategory.Grains),
    ShoppingItem(name = "Feijão preto", quantity = "500 g", category = ShoppingCategory.Grains),
    ShoppingItem(name = "Goma de tapioca", quantity = "500 g", category = ShoppingCategory.Grains),
    ShoppingItem(name = "Batata doce", quantity = "1 kg", category = ShoppingCategory.Grains),
    // Laticínios
    ShoppingItem(name = "Queijo", quantity = "200 g", category = ShoppingCategory.Dairy),
    ShoppingItem(name = "Iogurte de coco", quantity = "4 un", category = ShoppingCategory.Dairy),
    ShoppingItem(name = "Pasta de amendoim", quantity = "1 pote", category = ShoppingCategory.Other),
    // Suplementos
    ShoppingItem(name = "Whey Protein", quantity = "1 kg", category = ShoppingCategory.Supplements),
    ShoppingItem(name = "Creatina", quantity = "300 g", category = ShoppingCategory.Supplements),
    ShoppingItem(name = "Ômega 3", quantity = "1 frasco", category = ShoppingCategory.Supplements),
    ShoppingItem(name = "Pré-treino (até 400 mg cafeína)", quantity = "1 un", category = ShoppingCategory.Supplements),
)
