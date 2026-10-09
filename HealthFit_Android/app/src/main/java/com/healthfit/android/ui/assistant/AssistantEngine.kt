package com.healthfit.android.ui.assistant

import com.healthfit.android.ui.home.AthleteProfile
import com.healthfit.android.ui.home.BodyType
import com.healthfit.android.ui.home.DailyWellness
import java.text.Normalizer
import kotlin.math.roundToInt

object AssistantEngine {
    const val Disclaimer =
        "Importante: em caso de qualquer dúvida, desconforto ou dor no exercício, procure um profissional de saúde qualificado e habilitado. Se sentir dor, mal-estar, tontura ou sintoma preocupante, busque atendimento imediatamente. Não use ferramentas de IA (incluindo este assistente) para diagnóstico, tratamento ou decisão médica."

    val suggestions = listOf(
        "Montar cardápio personalizado",
        "Montar treino sem personal",
        "Treino em casa funciona?",
        "Qual é meu IMC?",
        "O que é ectomorfo?",
        "O que é mesomorfo?",
        "O que é endomorfo?",
        "Como dormir corretamente?",
        "Quanto de proteína comer?",
        "Quantas séries e repetições?",
        "O que fazer no déficit calórico?",
        "Posso beber álcool ou cerveja?",
        "Cerveja zero álcool é liberada?",
        "Treino, cardio ou meditação?",
        "Por que descansar é importante?",
        "Quais suplementos devo tomar?",
        "Para que serve a creatina?",
        "Whey protein faz mal?",
        "Como está minha evolução corporal?",
        "O que preciso melhorar?",
        "Horários livres para consulta",
        "Estou ótimo!",
        "Me sinto bem",
        "Mais ou menos",
        "Estou cansado",
        "Sinto dor",
    )

    fun welcome(name: String, wellness: DailyWellness, athlete: AthleteProfile): String {
        val alerts = alerts(wellness)
        val lines = mutableListOf("Boa tarde, $name. Sou o assistente HealthFit.", "")
        if (alerts.isEmpty()) {
            lines += "Seu dia está no eixo: sono, água e treino dentro do combinado."
        } else {
            lines += "Atenção ao seu dia:"
            alerts.forEach { lines += "• $it" }
        }
        lines += ""
        lines += "Biotipo ${athlete.bodyType.title.lowercase()} e objetivo ${athlete.objective.lowercase()} valem aqui e em Nutrição."
        lines += "Posso montar cardápio, treino, falar de IMC, sono, proteína, suplemento, cardio, meditação e descanso."
        lines += ""
        lines += Disclaimer
        lines += ""
        lines += "Toque em uma sugestão ou escreva sua pergunta."
        return lines.joinToString("\n")
    }

    fun alerts(wellness: DailyWellness): List<String> {
        val notes = mutableListOf<String>()
        val hours = wellness.sleepHours
        when {
            hours < 6f -> notes += "Sono curto: ${formatHours(hours)} registradas. O ideal é 7–9 h para recuperar o treino."
            hours < 7f -> notes += "Sono abaixo do ideal: ${formatHours(hours)}. Tente chegar entre 7 e 9 horas."
            hours > 9f -> notes += "Sono acima do recomendado: ${formatHours(hours)}. O ideal continua 7–9 h."
        }
        val goal = wellness.goalMl
        if (wellness.waterMl < goal) {
            val pct = (wellness.waterMl * 100 / goal).coerceAtLeast(0)
            val missing = goal - wellness.waterMl
            notes += if (pct < 50) {
                "Hidratação baixa: ${wellness.waterMl} ml de $goal ml ($pct% da meta). Beba água ao longo do dia."
            } else {
                "Meta de água não atingida: ${wellness.waterMl} ml de $goal ml. Faltam $missing ml."
            }
        }
        return notes
    }

    fun reply(text: String, wellness: DailyWellness, athlete: AthleteProfile, name: String): String {
        val value = normalize(text)
        if (value.contains("dor") || value.contains("tontura") || value.contains("mal-estar") || value.contains("mal estar")) {
            return "Pare o exercício e procure um profissional de saúde habilitado. Este assistente não faz diagnóstico, tratamento ou decisão médica."
        }
        return when {
            value.contains("cardapio") || value.contains("montar card") -> menu(athlete, wellness)
            value.contains("montar treino") || value.contains("sem personal") -> workout(athlete, home = false)
            value.contains("em casa") || value.contains("sem equipamento") -> workout(athlete, home = true)
            value.contains("imc") || value.contains("indice de massa") -> imc(wellness, athlete)
            value.contains("ectomorfo") -> body(BodyType.Ectomorph, athlete)
            value.contains("mesomorfo") -> body(BodyType.Mesomorph, athlete)
            value.contains("endomorfo") -> body(BodyType.Endomorph, athlete)
            value.contains("dormir") || value.contains("sono") -> sleep(wellness)
            value.contains("proteina") || value.contains("proteína") -> protein(wellness, athlete)
            value.contains("serie") || value.contains("repetic") ->
                "Para ${athlete.bodyType.title.lowercase()} em ${athlete.objective.lowercase()}: 3 a 4 séries de 6–12 repetições nos compostos, 2–3 minutos de descanso na força e 60–90 s na hipertrofia. Suba a carga quando completar o topo da faixa com boa técnica."
            value.contains("deficit") || value.contains("emagrec") ->
                "No déficit, mantenha proteína alta, tire o doce líquido e preserve o treino de força. A meta em Nutrição parte do TDEE e do déficit que você escolhe. Perda saudável fica perto de 0,5 kg por semana."
            value.contains("cerveja zero") || value.contains("cerveja light") ->
                "Cerveja zero não traz o álcool, mas ainda pode ter calorias. A light reduz, não zera. No déficit, conte no cardápio do dia."
            value.contains("alcool") || value.contains("cerveja") ->
                "Álcool atrapalha sono, recuperação e o déficit. Se beber, faça longe do treino pesado, hidrate e não use isso como recompensa diária."
            value.contains("creatina") ->
                "Creatina ajuda força e volume de treino. A dose usual é 3–5 g por dia, todos os dias, com água. Não substitui comida nem sono."
            value.contains("whey") ->
                "Whey é só proteína prática. Não faz mal para quem tolera lactose na dose do rótulo. Se a refeição já cobre a proteína, o whey é opcional."
            value.contains("suplement") ->
                "Base: comida, sono e treino. Os mais úteis aqui são whey se faltar proteína e creatina 3–5 g. O restante só com orientação do nutricionista."
            value.contains("descans") || value.contains("repouso") ->
                "Descansar é parte do método. Músculo e sistema nervoso se recuperam fora da série. Um dia leve ou off evita lesão e mantém a semana de treinos."
            value.contains("meditacao") || value.contains("cardio") ->
                "Força constrói, cardio gasta e cuida do coração, meditação baixa o stress e melhora o sono. Na semana: musculação nos dias de ficha, cardio curto e uma meditação de 10 min quando o sono apertar."
            value.contains("evolucao") || value.contains("melhorar") -> improve(wellness, athlete)
            value.contains("consulta") || value.contains("horario") || value.contains("agendar") ->
                "A agenda do personal e a do nutricionista ficam em Perfil → HealthFit Coach. Sem vínculo, entre com o código do profissional no plano Fit+."
            value.contains("otimo") || value.contains("ótimo") || value.contains("bem") && !value.contains("mais ou menos") ->
                "Que bom, $name. Com essa energia, a ficha do método aberto em Treinos está pronta, com GIF em cada exercício."
            value.contains("cansado") || value.contains("mais ou menos") ->
                "$name, com energia baixa o melhor é sono, água e uma sessão leve: mobilidade ou caminhada. Se a fadiga continuar, fale com um profissional."
            value.contains("lactose") ->
                "Se não tolera lactose, troque leite e whey comum por versão sem lactose ou proteína vegetal. O cardápio em Nutrição pergunta isso antes de atualizar."
            else ->
                "Anotei, $name. Posso orientar treino, cardápio, biotipo, IMC, sono e suplemento. Dor ou sintoma preocupante: procure atendimento. Não use esta conversa para decisão médica."
        }
    }

    private fun menu(athlete: AthleteProfile, wellness: DailyWellness): String {
        val kcal = when (athlete.objective) {
            "Ganho de Massa" -> 3200
            "Manutenção", "Resistência" -> 2900
            else -> 2500
        }
        val protein = (wellness.weight * if (athlete.bodyType == BodyType.Endomorph) 2.0f else 1.8f).roundToInt()
        return """
            Cardápio para ${athlete.bodyType.title.lowercase()}, objetivo ${athlete.objective.lowercase()}, cerca de $kcal kcal e ${protein} g de proteína.
            
            • Café: ovos, fruta e aveia
            • Almoço: arroz, feijão, frango e salada
            • Lanche: iogurte ou whey e fruta
            • Jantar: batata, peixe ou carne magra e legumes
            
            Marque cada refeição em Nutrição quando comer. O biotipo escolhido aqui é o mesmo do Perfil.
        """.trimIndent()
    }

    private fun workout(athlete: AthleteProfile, home: Boolean): String {
        val place = if (home) "em casa, peso corporal" else "na academia"
        val method = when (athlete.objective) {
            "Ganho de Massa" -> "Foco no Shape · Nível 1"
            "Perda de Gordura" -> "Método Militar · Soldado"
            else -> "Série por nível · Iniciantes"
        }
        return if (home) {
            "Treino em casa funciona quando a série é completa. Abra Treinos → Treine em Casa, fichas A–F, 3 dias por semana. Método: $method, $place, alinhado a ${athlete.bodyType.title.lowercase()}."
        } else {
            "Sem personal, comece pelo método $method em Treinos. Três dias: empurrar, puxar e pernas. O nome do método aparece no card da ficha."
        }
    }

    private fun imc(wellness: DailyWellness, athlete: AthleteProfile): String {
        val height = athlete.heightCm.toFloatOrNull()?.takeIf { it in 120f..230f } ?: 176f
        val meters = height / 100f
        val imc = wellness.weight / (meters * meters)
        val label = when {
            imc < 18.5 -> "abaixo do peso"
            imc < 25 -> "peso adequado"
            imc < 30 -> "sobrepeso"
            else -> "obesidade"
        }
        return "IMC ${"%.1f".format(imc)} com ${wellness.weightKg} kg e ${height.toInt()} cm: $label. Isso não é diagnóstico. O plano de ${athlete.objective.lowercase()} em Nutrição usa o mesmo peso do Perfil."
    }

    private fun body(type: BodyType, athlete: AthleteProfile): String {
        val yours = if (athlete.bodyType == type) " Este é o biotipo marcado no Perfil e em Nutrição." else " O seu biotipo marcado agora é ${athlete.bodyType.title.lowercase()}."
        return type.detail + yours
    }

    private fun sleep(wellness: DailyWellness): String {
        val status = when {
            wellness.sleepHours in 7f..9f -> "dentro do ideal"
            wellness.sleepHours < 7f -> "abaixo do ideal"
            else -> "acima do recomendado"
        }
        return "Você registrou ${formatHours(wellness.sleepHours)}, $status. Durma 7–9 h, no escuro, sem tela na última hora. O card de sono do início e do perfil é o mesmo número."
    }

    private fun protein(wellness: DailyWellness, athlete: AthleteProfile): String {
        val perKg = if (athlete.objective == "Perda de Gordura") 1.8f else 1.6f
        val grams = (wellness.weight * perKg).roundToInt()
        return "Com ${wellness.weightKg} kg e objetivo ${athlete.objective.lowercase()}, mire cerca de ${grams} g de proteína no dia, espalhados nas refeições. Whey só completa o que a comida não cobriu."
    }

    private fun improve(wellness: DailyWellness, athlete: AthleteProfile): String {
        val water = if (wellness.waterMl < wellness.goalMl) "a água ainda está em ${wellness.waterMl} ml de ${wellness.goalMl} ml" else "a água do dia está na meta"
        return "Evolução: biotipo ${athlete.bodyType.title.lowercase()}, objetivo ${athlete.objective.lowercase()}, sono ${formatHours(wellness.sleepHours)} e $water. O que mais muda a semana é treinar 3 vezes, bater a proteína e dormir 7–9 h. Fotos e medidas ficam no Perfil."
    }

    private fun formatHours(hours: Float): String {
        val whole = hours.toInt()
        val minutes = ((hours - whole) * 60).roundToInt()
        return if (minutes == 0) "$whole h" else "$whole h ${minutes.toString().padStart(2, '0')} min"
    }

    private fun normalize(text: String): String {
        val stripped = Normalizer.normalize(text, Normalizer.Form.NFD).replace("\\p{Mn}+".toRegex(), "")
        return stripped.lowercase()
    }
}
