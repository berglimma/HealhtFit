package com.healthfit.android.ui.home

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

enum class ReportKind { Weekly, Monthly }

data class ReportStat(val value: String, val label: String)

data class ReportLine(val title: String, val detail: String)

data class ReportSection(val title: String, val lines: List<ReportLine>)

data class ProgressReport(
    val kind: ReportKind,
    val title: String,
    val period: String,
    val score: Int,
    val message: String,
    val stats: List<ReportStat>,
    val sections: List<ReportSection>,
)

fun buildReport(kind: ReportKind, athlete: String, wellness: DailyWellness): ProgressReport {
    val today = LocalDate.now()
    val day = DateTimeFormatter.ofPattern("d MMM", Locale("pt", "BR"))
    return when (kind) {
        ReportKind.Weekly -> {
            val start = today.minusDays(6)
            ProgressReport(
                kind = kind,
                title = "Relatório Semanal",
                period = "${start.format(day)} – ${today.format(day)} · $athlete",
                score = 74,
                message = "Bom progresso. Veja abaixo o que pode melhorar.",
                stats = listOf(
                    ReportStat("3", "Treinos"),
                    ReportStat("114", "Minutos"),
                    ReportStat("3.860", "Calorias"),
                    ReportStat("3/7", "Dias ativos"),
                    ReportStat("2", "Meditação"),
                    ReportStat("22 min", "Min. meditação"),
                    ReportStat("7,4/10", "Intensidade"),
                    ReportStat("${wellness.waterMl} ml", "Água hoje"),
                ),
                sections = listOf(
                    ReportSection(
                        "Comparado à semana anterior",
                        listOf(
                            ReportLine("Treinos", "3 agora · antes 2 · subiu"),
                            ReportLine("Minutos", "114 agora · antes 96 · subiu"),
                            ReportLine("Calorias", "3.860 agora · antes 3.210 · subiu"),
                        ),
                    ),
                    ReportSection(
                        "Treinos da semana",
                        listOf(
                            ReportLine("Militar Masculino E", "8 de out. · 84 min · peito, ombros e tríceps"),
                            ReportLine("Caminhada livre", "8 de out. · 13 min · 52 kcal"),
                            ReportLine("Caminhada livre", "7 de out. · 17 min · 102 kcal"),
                        ),
                    ),
                    ReportSection(
                        "Meditação",
                        listOf(
                            ReportLine("2 sessões · 22 min", "Respiração consciente e foco"),
                            ReportLine("Semana anterior", "12 min · +10 min nesta semana"),
                        ),
                    ),
                    ReportSection(
                        "Intensidade",
                        listOf(
                            ReportLine("Média da semana", "7,4/10 em 3 treinos avaliados"),
                            ReportLine("Qui", "8/10 · Militar Masculino E"),
                        ),
                    ),
                    ReportSection(
                        "Destaques",
                        listOf(
                            ReportLine("Constância", "Três dias seguidos com movimento."),
                            ReportLine("Sono", "${"%.1f".format(wellness.sleepHours)} h registrados hoje."),
                        ),
                    ),
                    ReportSection(
                        "O que melhorar",
                        listOf(
                            ReportLine("Dias ativos", "Faltam 4 dias para fechar a semana em 7/7."),
                            ReportLine("Hidratação", "${wellness.waterMl} de ${wellness.goalMl} ml da meta de hoje."),
                        ),
                    ),
                ),
            )
        }
        ReportKind.Monthly -> {
            val start = today.minusDays(29)
            ProgressReport(
                kind = kind,
                title = "Relatório Mensal",
                period = "${start.format(day)} – ${today.format(day)} · últimos 30 dias · $athlete",
                score = 78,
                message = "Resumo dos últimos 30 dias. O próximo envio automático chega em 2 dias.",
                stats = listOf(
                    ReportStat("12", "Treinos"),
                    ReportStat("640", "Minutos"),
                    ReportStat("${"%.1f".format(wellness.sleepHours)} h", "Sono médio"),
                    ReportStat("18", "Suplementos"),
                    ReportStat("7,2/10", "Intensidade"),
                    ReportStat("${wellness.weightKg} kg", "Peso"),
                ),
                sections = listOf(
                    ReportSection(
                        "Sono",
                        listOf(
                            ReportLine("Noites no ideal", "18 de 30 entre 7 h e 9 h"),
                            ReportLine("Hoje", "${"%.1f".format(wellness.sleepHours)} h · meta 8 h"),
                        ),
                    ),
                    ReportSection(
                        "Hidratação",
                        listOf(
                            ReportLine("Meta", "${wellness.goalMl} ml · 35 ml por kg"),
                            ReportLine("Hoje", "${wellness.waterMl} ml já registrados"),
                        ),
                    ),
                    ReportSection(
                        "Medidas corporais",
                        listOf(
                            ReportLine("Peso", "${wellness.weightKg} kg"),
                            ReportLine("Evolução", "Atualize cintura e quadril em Perfil → Medidas."),
                        ),
                    ),
                    ReportSection(
                        "Suplementos",
                        listOf(
                            ReportLine("18 registros", "em 14 dias do período"),
                            ReportLine("Mais usados", "Whey 8× · Creatina 6× · Ômega-3 4×"),
                        ),
                    ),
                    ReportSection(
                        "Destaques",
                        listOf(
                            ReportLine("Volume", "12 treinos e 640 minutos no período."),
                            ReportLine("Cardio", "Caminhadas livres mantiveram a frequência."),
                        ),
                    ),
                ),
            )
        }
    }
}
