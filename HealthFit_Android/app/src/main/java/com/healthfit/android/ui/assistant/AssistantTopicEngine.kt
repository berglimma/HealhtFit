package com.healthfit.android.ui.assistant

import com.healthfit.android.ui.home.BodyType
import java.text.Normalizer
import kotlin.math.roundToInt

/**
 * Keyword-scored FAQ engine — port of iOS HealthAssistantEngine.answer() topics
 * (steroids, supplements, diet, IMC, evolution, workouts, biotypes, general).
 */
object AssistantTopicEngine {

    const val Disclaimer =
        "Importante: em caso de qualquer dúvida, desconforto ou dor no exercício, procure um profissional de saúde qualificado e habilitado. " +
            "Se sentir dor, mal-estar, tontura ou sintoma preocupante, busque atendimento imediatamente. " +
            "Não use ferramentas de IA (incluindo este assistente) para diagnóstico, tratamento ou decisão médica."

    private const val WorkoutProfessionalDisclaimer =
        "Vou montar uma sugestão com base nos seus dados, mas é essencial consultar um profissional de Educação Física " +
            "antes de iniciar ou alterar treinos — este assistente não substitui avaliação presencial nem prescrição profissional."

    fun answer(question: String, ctx: AssistantAnswerContext): String {
        if (AssistantGratitudeEngine.matches(question)) {
            return AssistantGratitudeEngine.answer(ctx)
        }
        if (AssistantImprovementAnalysisEngine.matches(question)) {
            return AssistantImprovementAnalysisEngine.answer(ctx)
        }
        if (AssistantRestDayEngine.matches(question)) {
            return AssistantRestDayEngine.answer(question, ctx)
        }

        val normalized = normalize(question)
        val best = allTopics
            .map { topic ->
                val score = topic.keywords.sumOf { keyword ->
                    val key = normalize(keyword)
                    if (key.isNotEmpty() && normalized.contains(key)) key.length else 0
                }
                topic to score
            }
            .maxByOrNull { it.second }

        if (best != null && best.second > 0) {
            return best.first.respond(ctx)
        }
        return fallbackAnswer(ctx)
    }

    private fun fallbackAnswer(ctx: AssistantAnswerContext): String {
        val lines = mutableListOf(
            "Não encontrei uma resposta exata, mas posso ajudar com estes temas:",
            "Seu objetivo: ${ctx.objective}. IMC: ${"%.1f".format(ctx.bmi)}. Meta: ${ctx.dailyCalorieTarget} kcal/dia.",
            "• Dieta: cardápio, macros, proteína, carboidrato, açúcar, lactose e álcool",
            "• IMC, peso, altura e composição corporal",
            "• Biotipos: ectomorfo, mesomorfo e endomorfo",
            "• Sono e recuperação",
            "• Treinos conforme orientação do personal",
            "• Suplementação: whey, creatina, pré-treino, ômega 3 e mais",
            "",
            Disclaimer,
            "",
            "Reformule a pergunta ou toque em uma sugestão abaixo.",
        )
        return lines.joinToString("\n")
    }

    // MARK: - Helpers

    internal fun normalize(text: String): String {
        val stripped = Normalizer.normalize(text, Normalizer.Form.NFD).replace("\\p{Mn}+".toRegex(), "")
        return stripped.lowercase()
    }

    private fun bmiInfo(bmi: Float): Pair<String, String> = when {
        bmi < 18.5f -> "Abaixo do peso" to
            "Priorize superávit calórico moderado, proteína adequada e treino de força para ganhar massa com saúde."
        bmi < 25f -> "Peso normal" to
            "Mantenha hábitos equilibrados. Ajuste calorias conforme objetivo (ganho, perda ou manutenção)."
        bmi < 30f -> "Sobrepeso" to
            "Déficit calórico moderado + treino de força ajudam a reduzir gordura preservando músculo."
        bmi < 35f -> "Obesidade grau I" to
            "Combine alimentação controlada, movimento regular e acompanhamento profissional se possível."
        bmi < 40f -> "Obesidade grau II" to
            "Priorize hábitos sustentáveis. Evite dietas extremas; busque orientação médica/nutricional."
        else -> "Obesidade grau III" to
            "Recomendamos acompanhamento de profissionais de saúde para um plano seguro e personalizado."
    }

    private fun proteinRecommendation(ctx: AssistantAnswerContext): String {
        val gramsPerKg = when {
            ctx.isMuscleGain -> 2.0
            ctx.isFatLoss -> 2.2
            ctx.isEndurance -> 1.6
            else -> 1.8
        }
        val grams = (ctx.weightKg * gramsPerKg).roundToInt()
        val kcal = grams * 4
        val pct = if (ctx.dailyCalorieTarget > 0) {
            (kcal * 100.0 / ctx.dailyCalorieTarget).roundToInt()
        } else {
            0
        }
        return "Sugestão: ~$grams g/dia (~$gramsPerKg g/kg). Isso representa cerca de $kcal kcal ($pct% da meta)."
    }

    private fun goalTrainingSummary(objective: String): String = when {
        objective.contains("Massa", ignoreCase = true) || objective.contains("Ganho", ignoreCase = true) ->
            "3–5 treinos de força/semana, progressão de carga, superávit calórico e proteína alta."
        objective.contains("Perda", ignoreCase = true) || objective.contains("gordura", ignoreCase = true) ->
            "3–4 treinos de força/semana + déficit calórico. Cardio 2–3x opcional."
        objective.contains("Resist", ignoreCase = true) ->
            "3–4 sessões de cardio/semana + 2 treinos de força para prevenir lesões."
        else ->
            "2–4 treinos/semana equilibrados entre força e cardio leve."
    }

    private fun sleepStatusLine(hours: Float?): String {
        if (hours == null) {
            return "Registre suas horas de sono no check-in diário para acompanhar."
        }
        val formatted = "%.1f".format(hours)
        val (title, message) = when {
            hours < 5f -> "Não regulado" to "Priorize descanso — hormônios e recuperação ficam prejudicados."
            hours < 7f -> "Abaixo do ideal" to "Tente dormir entre 7 e 9 horas por noite."
            hours <= 9f -> "Ideal" to "Mantenha essa faixa para treino e recuperação."
            else -> "Acima do recomendado" to "Avalie se há fadiga ou rotina irregular."
        }
        return "Hoje você registrou $formatted h — ${title.lowercase()}. $message"
    }

    private fun ectomorphDefinition(isUserType: Boolean): String {
        val prefix = if (isUserType) "Seu biotipo é ectomorfo.\n\n" else ""
        return """
            ${prefix}Ectomorfo — definição:
            Somatotipo caracterizado por estrutura corporal magra, ossatura fina e metabolismo acelerado. Tende a ter dificuldade em ganhar peso e massa muscular.

            Características:
            • Corpo esguio, ombros e quadris estreitos
            • Pulsos e tornozelos finos
            • Ganha pouco peso mesmo comendo bastante
            • Metabolismo acelerado (+10% no TDEE no app)

            Alimentação: superávit calórico moderado, proteína alta, refeições frequentes.
            Treino: musculação 3–5x/semana com progressão de carga; cardio leve e curto.
        """.trimIndent()
    }

    private fun mesomorphDefinition(isUserType: Boolean): String {
        val prefix = if (isUserType) "Seu biotipo é mesomorfo.\n\n" else ""
        return """
            ${prefix}Mesomorfo — definição:
            Somatotipo atlético, com facilidade natural para ganhar músculo e perder gordura. Estrutura corporal equilibrada e boa resposta ao treino.

            Características:
            • Ombros largos e cintura marcada
            • Estrutura muscular visível
            • Ganha músculo e perde gordura com relativa facilidade
            • TDEE padrão no app (sem ajuste extra)

            Alimentação: balanceada conforme objetivo (superávit para massa, déficit para cutting).
            Treino: responde bem a volume moderado-alto; combine força e cardio.
        """.trimIndent()
    }

    private fun endomorphDefinition(isUserType: Boolean): String {
        val prefix = if (isUserType) "Seu biotipo é endomorfo.\n\n" else ""
        return """
            ${prefix}Endomorfo — definição:
            Somatotipo com tendência a acumular gordura, estrutura mais arredondada e metabolismo mais lento. Ganha peso com mais facilidade.

            Características:
            • Estrutura arredondada, cintura e quadril mais largos
            • Acumula gordura com facilidade
            • Ganha peso mais rápido que os outros biotipos
            • Metabolismo mais lento (−10% no TDEE no app)

            Alimentação: controle calórico, proteína alta, menos ultraprocessados e frituras.
            Treino: musculação + cardio regular; consistência é chave.
        """.trimIndent()
    }

    private fun anabolicSteroidsWarning(): String = """
        ⚠️ ALERTA DE SAÚDE — ESTERÓIDES ANABOLIZANTES

        O HealthFit NÃO recomenda, NÃO orienta e NÃO incentiva o uso de esteróides anabolizantes.
        Jamais faça uso por conta própria. Isso prejudica o corpo de forma grave e, muitas vezes, irreversível.
        Procure um médico (endocrinologista ou médico do esporte) para qualquer dúvida sobre hormônios.

        O uso sem prescrição e acompanhamento médico é ilegal no Brasil e pode causar danos permanentes.

        Principais esteróides anabolizantes (todos com riscos sérios):
        • Testosterona e ésteres — enantato, cipionato, propionato, undecanoato, Sustanon/Durateston
        • Nandrolona — Deca-Durabolin (decanoato de nandrolona)
        • Trenbolona — acetato, enantato (Tren)
        • Boldenona — Equipoise
        • Stanozolol — Winstrol (oral e injetável)
        • Oxandrolona — Anavar
        • Metandienona — Dianabol (D-Bol)
        • Oximetolona — Hemogenin/Anadrol
        • Fluoximesterona — Halotestin
        • Mesterolona — Proviron
        • Turinabol (clorodehidrometiltestosterona)
        • Metenolona — Primobolan
        • Drostanolona — Masteron
        • Metiltestosterona
        • Metasterona — Superdrol
        • Outros andrógenos sintéticos e “designer steroids”

        Substâncias frequentemente associadas (também perigosas sem supervisão):
        • SARMs (ostarine, ligandrol, RAD-140, andarine, etc.)
        • Pro-hormônias
        • Hormônio do crescimento (HGH) usado de forma ilegal

        Riscos ao corpo:
        • Coração — hipertensão, arritmias, infarto, AVC, colesterol alterado
        • Fígado — hepatotoxicidade, icterícia, tumores
        • Hormônios — queda da produção natural de testosterona, infertilidade, ginecomastia
        • Pele e cabelo — acne severa, queda de cabelo, estrias
        • Psique — agressividade, ansiedade, depressão, dependência
        • Sistema reprodutor — atrofia testicular, queda de libido
        • Crescimento — fechamento precoce de placa óssea em jovens
        • Infecções — abscessos e contaminação por agulhas compartilhadas
        • Legal e esportivo — sanções, doping, prisão

        O que fazer em vez disso:
        • Treino progressivo com orientação profissional
        • Dieta adequada com proteína, carboidrato e gordura de qualidade
        • Sono de 7–9 horas por noite
        • Suplementos seguros (creatina, whey, ômega 3) com orientação profissional

        Repetindo: jamais use esteróides anabolizantes por conta própria. Procure um médico.
        Ganhos rápidos com hormônios não valem a saúde destruída.
    """.trimIndent()

    // MARK: - Topics

    private val steroidTopics: List<AssistantTopic> = listOf(
        AssistantTopic(
            keywords = listOf(
                "esteroides anabolizantes", "esteroides anabolicos",
                "anabolizante", "anabolizantes", "anabolico", "anabolico androgenico",
                "hormonio anabolico", "uso de esteroides", "ciclo de esteroides", "ciclo de hormonio",
                "ciclo de bomba", "fazer ciclo", "iniciar ciclo", "efetuar um ciclo", "efetuar ciclo",
                "quero efetuar um ciclo", "quero fazer um ciclo", "quero iniciar um ciclo", "quero comecar um ciclo",
                "montar um ciclo", "primeiro ciclo", "meu primeiro ciclo",
                "ciclar", "quero ciclar", "vou ciclar", "posso ciclar", "como ciclar", "ta ciclando",
                "ciclado", "ciclada", "to ciclando", "ciclo de bulking", "ciclo de cutting",
                "tomar suco", "quero tomar suco", "vou tomar suco", "tomei suco", "pegar suco", "usar suco",
                "suco anabolico", "suco hormonal", "suco de bomba", "suco no ciclo",
                "pct esteroide", "trt ilegal",
                "testosterona exogena", "testosterona sintetica",
                "testosterona", "testo enantato", "testo cipionato", "testo propionato", "enantato de testosterona",
                "cipionato de testosterona", "propionato de testosterona", "undecanoato de testosterona", "sustanon",
                "durateston", "nandrolona", "deca durabolin", "deca-durabolin", "deca",
                "decanoato de nandrolona", "trenbolona", "trenbolone", "acetato de trenbolona", "enantato de trenbolona",
                "tren ace", "tren e", "boldenona", "equipoise", "stanozolol", "winstrol", "oxandrolona", "anavar",
                "metandienona", "metandrostenolona", "dianabol", "d-bol", "dbol", "oximetolona", "hemogenin", "anadrol",
                "fluoxymesterone", "fluoximesterona", "halotestin", "mesterolona", "proviron", "turinabol",
                "clorodehidrometiltestosterona", "metenolona", "methenolone", "primobolan", "primo",
                "drostanolona", "masteron", "metiltestosterona", "superdrol", "metasterona",
                "stanozolol injetavel", "bomba de ferro", "bomba hormonal",
                "peptideo de crescimento ilegal", "hgh ilegal", "hormonio do crescimento ilegal", "sarm ilegal",
                "ostarine", "ligandrol", "rad 140", "rad-140", "cardarine", "yk-11", "andarine",
                "prohormona", "pro-hormona", "designer steroid", "esteroides orais", "esteroides injetaveis",
                "stack de esteroides", "stack anabolico",
            ),
            respond = { anabolicSteroidsWarning() },
        ),
    )

    private val dietTopics: List<AssistantTopic> = listOf(
        AssistantTopic(
            keywords = listOf(
                "cardapio", "refeicao", "dieta", "nutricao", "compras", "lista",
                "montar cardapio", "alimentacao",
            ),
            respond = { ctx ->
                val lactose = ctx.lactoseLabel ?: "não informada"
                """
                Seu cardápio no HealthFit é montado com base no objetivo (${ctx.objective}), biotipo, TMB e preferências.

                • 6 refeições: café, lanches, almoço, janta e ceia
                • Consumo de doces: ${ctx.sweetLabel}
                • Tolerância à lactose: $lactose
                • Meta calórica: ${ctx.dailyCalorieTarget} kcal/dia

                Na aba **Nutrição** você monta o cardápio e gera a lista de compras (proteínas, frutas, grãos e suplementos).

                Toque em “Montar cardápio personalizado” ou abra Nutrição para gerar seu plano.

                Para perda de gordura, há opções mais restritivas com menos carboidrato e sem frituras.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("proteina", "proteinas", "carne", "frango", "ovo", "ovos"),
            respond = { ctx ->
                """
                Proteína constrói e preserva músculo, aumenta saciedade e acelera recuperação pós-treino.

                ${proteinRecommendation(ctx)}

                Fontes no cardápio: frango, carne magra, peixe, ovos, iogurte (se tolera lactose), whey e leguminosas.

                Distribua ao longo do dia — café, almoço, janta e lanches.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("carboidrato", "carbo", "carbos", "arroz", "pao", "macarrao", "batata", "aveia"),
            respond = { ctx ->
                val advice = when {
                    ctx.isMuscleGain -> "Carboidratos são importantes para energia nos treinos e recuperação. Inclua arroz, batata, aveia e frutas."
                    ctx.isFatLoss -> "Carboidratos não são vilões — controle porções e priorize integrais. Reduza em jantar/ceia se necessário."
                    ctx.isEndurance -> "Carboidratos são sua principal fonte de energia para cardio e resistência."
                    else -> "Mantenha carboidratos equilibrados: integrais, frutas e legumes."
                }
                """
                Carboidratos fornecem energia para treinos e funções cerebrais.

                Objetivo (${ctx.objective}): $advice

                Meta calórica: ${ctx.dailyCalorieTarget} kcal/dia.
                Tipicamente 40–55% das calorias vêm de carboidratos, ajustados ao objetivo.

                Prefira: arroz integral, batata doce, aveia, frutas e pães integrais. Evite excesso de ultraprocessados e frituras.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("gordura", "gorduras", "lipidio", "oleo", "azeite", "abacate"),
            respond = { ctx ->
                val fatG = (ctx.dailyCalorieTarget * 0.25 / 9).toInt()
                """
                Gorduras são essenciais para hormônios, absorção de vitaminas e saúde cerebral.

                Tipos:
                • Insaturadas (azeite, abacate, castanhas, peixes) — priorize
                • Saturadas (carnes, manteiga) — moderação
                • Trans (industrializados, frituras) — evite

                Meta: cerca de 20–35% das calorias diárias (${ctx.dailyCalorieTarget} kcal → ~$fatG g/dia de gordura).

                No cardápio de perda de gordura, reduzimos frituras e opções muito gordurosas.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("macro", "macronutriente", "macronutrientes", "distribuicao"),
            respond = { ctx ->
                val cal = ctx.dailyCalorieTarget
                val proteinG = (ctx.weightKg * 2.0f).roundToInt()
                val proteinKcal = proteinG * 4
                val fatKcal = (cal * 0.25).toInt()
                val fatG = fatKcal / 9
                val carbKcal = maxOf(cal - proteinKcal - fatKcal, 0)
                val carbG = carbKcal / 4
                """
                Macronutrientes na sua meta ($cal kcal/dia):

                • Proteína: ~$proteinG g ($proteinKcal kcal)
                • Gordura: ~$fatG g ($fatKcal kcal)
                • Carboidrato: ~$carbG g ($carbKcal kcal)

                Objetivo: ${ctx.objective}.

                O cardápio do app distribui isso em 6 refeições. Ajuste doces e lactose em Nutrição.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("cafe da manha", "cafe", "breakfast"),
            respond = { ctx ->
                """
                Café da manhã (~20% das calorias ≈ ${(ctx.dailyCalorieTarget * 0.20).toInt()} kcal).

                Função: quebrar o jejum noturno, energia para o dia e proteína matinal.

                Opções no app: ovos, aveia, frutas, pão integral, iogurte (conforme lactose).

                Dica: inclua proteína no café — ajuda na saciedade e no ganho muscular.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("almoco", "lunch"),
            respond = { ctx ->
                """
                Almoço (~30% das calorias ≈ ${(ctx.dailyCalorieTarget * 0.30).toInt()} kcal) — refeição principal.

                Estrutura ideal:
                • Proteína (carne, frango, peixe, leguminosas)
                • Carboidrato (arroz, batata, macarrão integral)
                • Vegetais e salada
                • Gordura boa (azeite)

                No app, escolha opções alinhadas ao objetivo ${ctx.objective.lowercase()}.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("jantar", "janta", "ceia", "supper", "dinner"),
            respond = { ctx ->
                """
                Jantar (~22%) e ceia (~8%) completam o dia.

                Jantar: ~${(ctx.dailyCalorieTarget * 0.22).toInt()} kcal
                Ceia: ~${(ctx.dailyCalorieTarget * 0.08).toInt()} kcal

                ${if (ctx.isFatLoss) "Em perda de gordura: jantar mais leve, menos carboidrato e sem fritura." else "Mantenha proteína no jantar para recuperação noturna."}

                Ceia: opções leves — iogurte, fruta ou whey — ajudam a evitar fome noturna.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("lanche", "snack", "lanche da tarde", "lanche manha"),
            respond = { ctx ->
                """
                Lanches (~10% cada ≈ ${(ctx.dailyCalorieTarget * 0.10).toInt()} kcal) mantêm energia estável entre refeições.

                Ideias no cardápio: frutas, castanhas, iogurte, whey, sanduíche integral.

                Evite pular lanches se treina à tarde — você precisa de combustível antes do treino.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "acucar", "doce", "doces", "sobremesa", "docinho",
                "quantidade de doce", "quantidade de doces", "consumo de doce", "consumo de doces",
                "muito doce", "pouco doce", "consome doce", "come doce", "come doces",
            ),
            respond = { ctx ->
                val warning = ctx.sweetWarning?.let { "\n\n$it" }.orEmpty()
                """
                Consumo de açúcar no seu plano: ${ctx.sweetLabel}.
                ${ctx.sweetDetail}

                A OMS recomenda limitar açúcares livres a menos de 10% das calorias (idealmente 5%). Em 2000 kcal: até 50 g (10%) ou 25 g (5%).

                Prefira frutas, aveia e doces ocasionais. Ajuste em Nutrição → "Você consome muito doce?" (Pouco, Moderado ou Muito).$warning
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "alcool", "alcoolica", "beber alcool",
                "cerveja", "cervejas", "chopp", "chope", "vinho", "vodka", "whisky", "uisque",
                "destilada", "destiladas", "bebida alcoolica", "drinque", "drink",
                "caipirinha", "gin", "rum", "tequila", "pinga", "cachaca", "bebida destilada",
            ),
            respond = { ctx ->
                """
                Álcool, cerveja e bebidas destiladas têm influência negativa relevante no plano (${ctx.objective}).

                Por que prejudica:
                • Calorias vazias — o corpo queima álcool antes de gordura (atrapalha perda de peso)
                • Cerveja: ~90–180 kcal/lata + carboidratos; destilados: ~70–100 kcal/dose (40 ml), mas o efeito do etanol é maior por concentração
                • Reduz síntese proteica e recuperação muscular pós-treino
                • Piora sono (menos REM), desidrata e aumenta fome no dia seguinte
                • Em excesso: fígado, pressão arterial e adesão à dieta caem

                Sua meta: ${ctx.dailyCalorieTarget} kcal/dia.

                Se for consumir (não é recomendado em fase de cutting):
                • Máximo ocasional — não é parte do cardápio HealthFit
                • Evite no dia de treino intenso ou antes de dormir
                • Não compense "comendo menos" no dia — priorize proteína e água
                • Destilados com calorias de mixers (refrigerante, suco) somam ainda mais

                Para ganho de massa ou perda de gordura, menos álcool = melhor resultado.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "cerveja zero", "zero alcool", "sem alcool",
                "nao alcoolica", "cerveja sem alcool",
                "heineken 0", "brahma 0", "antarctica 0", "bebida zero alcool",
            ),
            respond = { ctx ->
                """
                Cerveja zero álcool — o que pode e o que não pode:

                ✅ Pode (com moderação):
                • Opção social sem etanol — não intoxica nem prejudica o fígado como álcool
                • Geralmente menos calorias que cerveja comum (~15–35 kcal/100 ml vs ~40–50)
                • Cabe melhor na meta de ${ctx.dailyCalorieTarget} kcal/dia se contabilizar no dia
                • Hidratação levemente melhor que cerveja alcoólica (sem efeito diurético do álcool)

                ❌ Não pode / cuidados:
                • Não é "liberado à vontade" — ainda tem carboidrato, sódio e calorias
                • Pode conter açúcar ou maltose — leia o rótulo
                • Não substitui água, leite ou refeições
                • Algumas marcas têm traços de álcool (<0,5%) — atletas em competição devem verificar
                • Pode manter hábito de "cerveja todo dia" — o ideal é ocasional

                Resumo: melhor que cerveja comum para saúde e dieta, mas trate como bebida calórica ocasional, não como hidratação ou suplemento.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "cerveja light", "cerveja diet", "cerveja baixa caloria", "cerveja baixa calorias",
                "cerveja low carb", "pode cerveja light", "cerveja menos calorias", "cerveja light faz mal",
            ),
            respond = { ctx ->
                """
                Cerveja light / de baixa caloria — pontos positivos e negativos:

                👍 Influência positiva (relativa):
                • Menos calorias que cerveja tradicional (~80–100 kcal/lata vs ~140–180)
                • Facilita encaixar 1 unidade ocasional na meta de ${ctx.dailyCalorieTarget} kcal/dia
                • Pode ser escolha "menos pior" em eventos sociais (objetivo: ${ctx.objective})

                👎 Influência negativa (ainda presente):
                • Continua com álcool — etanol segue atrapalhando queima de gordura e recuperação
                • Álcool permanece (~3,5–4,5%) — efeito no sono, fígado e treino é similar
                • Risco de beber mais unidades ("é light, então pode mais")
                • Carboidratos e sódio ainda existem; pouca proteína ou nutriente útil

                Comparativo rápido:
                • Pior: destilado + mixer, cerveja comum em excesso
                • Médio: cerveja light ocasional
                • Melhor para dieta/treino: zero álcool ou não beber

                Em perda de gordura ou ganho de massa, menos é mais. Se beber, 1 light ocasional e conte as calorias no dia.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("lactose", "intolerancia", "leite", "iogurte", "queijo", "laticinio"),
            respond = { ctx ->
                val tolerance = ctx.lactoseLabel
                """
                ${tolerance?.let { "Sua tolerância à lactose: $it." } ?: "Informe sua tolerância à lactose em Nutrição para filtrar opções com leite e queijo."}

                Se intolerante, o cardápio prioriza opções sem lactose (leite vegetal, ovos, carnes, frutas).
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("fruta", "frutas", "banana", "maca", "morango", "vitamina"),
            respond = {
                """
                Frutas são fonte de fibras, vitaminas e carboidratos naturais.

                • 2–4 porções/dia é uma boa referência
                • Melhor com refeições ou lanches (não substituem proteína)
                • Priorize frutas inteiras em vez de sucos industrializados

                Na lista de compras do app: banana, maçã, morango, mamão e outras sazonais.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("fritura", "frituras", "frito", "fast food", "ultraprocessado", "industrializado"),
            respond = { ctx ->
                """
                Frituras e ultraprocessados têm muita gordura, sódio e calorias vazias.

                ${if (ctx.isFatLoss) "Seu plano de perda de gordura exclui frituras do cardápio." else "Consuma com moderação — ocasionalmente não arruína o progresso."}

                Prefira: grelhados, assados, cozidos e airfryer.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("jejum", "jejuar", "intermitente", "fasting"),
            respond = { ctx ->
                """
                Jejum intermitente (ex.: 16/8) pode funcionar para algumas pessoas, mas não é obrigatório.

                O que importa para ${ctx.objective.lowercase()}: total calórico diário (${ctx.dailyCalorieTarget} kcal) e proteína adequada.

                Se treina de manhã, não pule proteína pré/pós-treino.
                Consulte um profissional se tiver condições médicas.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("fibras", "fibra", "constipacao", "intestino"),
            respond = {
                """
                Fibras melhoram digestão, saciedade e controle glicêmico.

                Meta: 25–30 g/dia (adultos).
                Fontes: frutas, vegetais, aveia, arroz integral, leguminosas.

                Aumente aos poucos e beba água — fibras sem hidratação podem causar desconforto.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "deficit", "deficit calorico", "emagrecer", "perda de gordura",
                "perder peso", "emagrecimento",
            ),
            respond = { ctx ->
                val deficit = ctx.caloricDeficit
                val weekly = ctx.estimatedWeeklyWeightLoss
                """
                Déficit calórico = gastar mais energia do que consome.

                Seu TDEE: ${ctx.estimatedTdee} kcal/dia.
                Déficit configurado: ${if (deficit > 0) "−$deficit kcal/dia" else "sem déficit ativo"}.
                Meta calórica: ${ctx.dailyCalorieTarget} kcal/dia.
                ${if (weekly > 0) "Estimativa: ~${"%.2f".format(weekly)} kg/semana de perda." else ""}

                O que fazer no déficit:
                • Priorize proteína (preserva músculo)
                • Mantenha treino de força
                • Inclua cardio moderado se quiser
                • Beba água e durma 7–9 h
                • Evite déficits extremos (não fique abaixo de ~1200 kcal sem acompanhamento)
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "ganho de massa", "bulking", "hipertrofia", "massa muscular alimentacao",
                "engordar musculo",
            ),
            respond = { ctx ->
                """
                Ganho de massa muscular (bulking):

                • Meta calórica: ${ctx.dailyCalorieTarget} kcal/dia (superávit sobre TDEE de ${ctx.estimatedTdee})
                • Proteína: ${proteinRecommendation(ctx)}
                • Treino: 3–5x/semana com progressão de carga
                • Biotipo ${ctx.bodyType.title}: ajuste calorias e estratégias no app

                Ganho de 0,25–0,5 kg/semana indica progresso sem excesso de gordura.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("lista de compras", "compras semana", "supermercado", "feira"),
            respond = {
                """
                A lista de compras do HealthFit inclui:

                • Proteínas: frango, carne, peixe, ovos
                • Frutas e vegetais da semana
                • Grãos: arroz, aveia, feijão
                • Suplementos: creatina, ômega 3, beta-alanina, pré-treino
                • Energéticos (configurável — alerta OMS acima de 2/semana)

                Gere em Nutrição → Lista de Compras após montar o cardápio.
                """.trimIndent()
            },
        ),
    )

    private val imcTopics: List<AssistantTopic> = listOf(
        AssistantTopic(
            keywords = listOf(
                "imc", "bmi", "indice de massa", "massa corporal",
                "qual meu imc", "qual e meu imc",
            ),
            respond = { ctx ->
                val (label, advice) = bmiInfo(ctx.bmi)
                """
                IMC (Índice de Massa Corporal) mede a relação peso/altura — não mede gordura diretamente, mas é um indicador útil.

                Seus dados:
                • Peso: ${"%.1f".format(ctx.weightKg)} kg
                • Altura: ${"%.0f".format(ctx.heightCm)} cm
                • IMC: ${"%.1f".format(ctx.bmi)}
                • Classificação: $label

                $advice

                Atletas com muito músculo podem ter IMC alto sem excesso de gordura. Combine com medidas corporais e % gordura se possível.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("peso ideal", "peso saudavel", "quanto devo pesar", "meta de peso"),
            respond = { ctx ->
                val heightM = ctx.heightCm / 100f
                val minWeight = 18.5f * heightM * heightM
                val maxWeight = 24.9f * heightM * heightM
                """
                Faixa de peso saudável (IMC 18,5–24,9) para sua altura (${"%.0f".format(ctx.heightCm)} cm):

                • Mínimo: ~${"%.1f".format(minWeight)} kg
                • Máximo: ~${"%.1f".format(maxWeight)} kg
                • Seu peso atual: ${"%.1f".format(ctx.weightKg)} kg (IMC ${"%.1f".format(ctx.bmi)})

                Objetivo no app: ${ctx.objective}.
                ${if (ctx.estimatedWeeklyWeightLoss > 0) "Ritmo estimado: ~${"%.2f".format(ctx.estimatedWeeklyWeightLoss)} kg/semana." else "Ajuste calorias conforme progresso semanal."}

                Composição corporal importa mais que o número na balança — treino de força preserva músculo.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "sobrepeso", "obesidade", "obeso", "gordo", "acima do peso",
                "magreza", "abaixo do peso", "muito magro",
            ),
            respond = { ctx ->
                val (label, advice) = bmiInfo(ctx.bmi)
                """
                Seu IMC: ${"%.1f".format(ctx.bmi)} — $label

                $advice

                Objetivo configurado: ${ctx.objective}.
                Meta calórica: ${ctx.dailyCalorieTarget} kcal/dia.

                Mudanças graduais e consistentes vencem dietas radicais. O app acompanha treino, nutrição e hidratação.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("peso", "balanca", "engordar", "emagreci", "subi de peso", "desci de peso"),
            respond = { ctx ->
                val (label, _) = bmiInfo(ctx.bmi)
                """
                Seu peso: ${"%.1f".format(ctx.weightKg)} kg
                Altura: ${"%.0f".format(ctx.heightCm)} cm
                IMC: ${"%.1f".format(ctx.bmi)} ($label)

                Para ${ctx.objective.lowercase()}:
                • Meta calórica: ${ctx.dailyCalorieTarget} kcal/dia
                • TDEE: ${ctx.estimatedTdee} kcal/dia
                ${if (ctx.estimatedWeeklyWeightLoss > 0) "• Estimativa: ~${"%.2f".format(ctx.estimatedWeeklyWeightLoss)} kg/semana" else ""}

                Pese-se no mesmo horário (ex.: ao acordar) 1–2x/semana. Flutuações diárias de 1–2 kg são normais (água, alimento).
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "composicao corporal", "gordura corporal", "percentual de gordura", "bf", "body fat",
            ),
            respond = { ctx ->
                """
                Composição corporal = proporção de gordura vs músculo (mais relevante que peso sozinho).

                Seu IMC (${"%.1f".format(ctx.bmi)}) é um proxy, não mede % gordura diretamente.

                Para melhorar composição:
                • Treino de força (preserva/ganha músculo)
                • Proteína adequada
                • Déficit moderado se perder gordura

                Bioimpedância, adipômetro ou DEXA dão medidas mais precisas que a balança comum.
                """.trimIndent()
            },
        ),
    )

    private val bodyEvolutionTopics: List<AssistantTopic> = listOf(
        AssistantTopic(
            keywords = listOf(
                "evolucao corporal", "fotos de evolucao",
                "comparar medidas", "comparativo de medidas", "progresso corporal", "antes e depois",
                "lote de fotos", "pdf de medidas",
            ),
            respond = {
                """
                Evolução Corporal no HealthFit:
                • Fotos são opcionais e privadas — só você pode ver ou acessar.
                • O relatório principal usa as medidas corporais do Perfil.
                • Após 30 dias, registre uma nova avaliação (com ou sem fotos).
                • Os PDFs das avaliações ficam salvos na sua conta.

                Ainda não há comparativo detalhado de medidas no Android — preencha e acompanhe em **Perfil → Medidas Corporais**.

                Abra Perfil para registrar medidas e acompanhar sua evolução.
                """.trimIndent()
            },
        ),
    )

    private val workoutTopics: List<AssistantTopic> = listOf(
        AssistantTopic(
            keywords = listOf(
                "montar treino", "criar treino", "gerar treino", "montar ficha", "criar ficha", "gerar ficha",
                "treino sem personal", "nao tenho personal", "sem personal",
                "ficha personalizada", "treino pelo assistente", "sugestao de treino",
            ),
            respond = {
                """
                Posso orientar um treino para quem não tem personal.

                Abra a aba **Treinos** e escolha:
                • Musculação (métodos e fichas A/B/C)
                • Treine em Casa (peso corporal, fichas A–F)
                • Cardio ou Meditação

                Sem personal, comece por 3 dias: empurrar, puxar e pernas — ou full body em casa.

                $WorkoutProfessionalDisclaimer

                $Disclaimer
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "treino em casa", "treinar em casa", "sem academia", "sem equipamento",
                "peso corporal", "bodyweight", "casa funciona", "so em casa",
                "treino caseiro", "montar treino em casa", "como treinar em casa",
            ),
            respond = {
                """
                Treinar em casa funciona — principalmente com consistência, progressão e boa técnica.

                O que priorizar em casa:
                • Full body ou divisão simples (superior/inferior) 3–5x/semana
                • Progressão: mais reps, menos descanso, variações mais difíceis (ex.: flexão diamante)
                • Core, pernas e empurrar/puxar com peso corporal
                • Use demos em GIF no app (**Treinos → Treine em Casa**)

                Limitações honestas:
                • Hipertrofia avançada de certos grupos fica mais fácil com carga externa
                • Elásticos/halteres leves ajudam, mas não são obrigatórios para começar

                Abra **Treinos → Treine em Casa** para as fichas prontas.

                $WorkoutProfessionalDisclaimer

                $Disclaimer
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "ganhar massa em casa", "hipertrofia em casa", "crescer em casa",
                "musculo em casa",
            ),
            respond = {
                """
                Dá para ganhar músculo em casa, sobretudo no início e intermediário:

                • Chegue perto da falha em 8–20 reps (flexões, agachamentos, afundos, ponte, mergulhos)
                • Aumente dificuldade: pausas, tempo sob tensão, unilateral, elevações
                • Proteína adequada + sono 7–9 h + superávit leve se o objetivo for massa
                • 3–4 sessões/semana com recuperação entre estímulos do mesmo grupo

                No app: **Treinos → Treine em Casa** com foco em ganho de massa.

                $WorkoutProfessionalDisclaimer

                $Disclaimer
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "emagrecer em casa", "perder gordura em casa", "secar em casa",
                "hiit em casa", "cardio em casa",
            ),
            respond = {
                """
                Emagrecer em casa combina déficit calórico + movimento consistente:

                • Circuitos com agachamento, burpee, polichinelo, mountain climber e prancha
                • 20–35 min, 3–5x/semana, mantendo esforço sustentável
                • Força em casa 2–3x ajuda a preservar músculo no déficit
                • Água, sono e proteína continuam essenciais

                Veja HIIT e circuitos em **Treinos → Treine em Casa**.

                $Disclaimer
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "espaco pequeno", "apartamento", "vizinho",
                "sem barulho", "treino silencioso",
            ),
            respond = {
                """
                Em apartamento / espaço pequeno:

                • Prefira afundos, agachamento controlado, ponte, prancha, flexões e isometrias
                • Evite burpees/saltos se o barulho incomodar vizinhos
                • Tapete antiderrapante e janela ventilada ajudam
                • Sessões curtas (20–30 min) bem feitas valem mais que treinos longos irregulares

                Em **Treine em Casa** há fichas full body e core com demos.

                $Disclaimer
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "treino", "musculacao", "forca", "exercicio", "academia", "ficha",
            ),
            respond = { ctx ->
                """
                Treino de musculação (força) ganha/preserva massa muscular, acelera metabolismo e melhora composição corporal.

                Para ${ctx.objective}:
                ${goalTrainingSummary(ctx.objective)}

                No app: **Treinos → Musculação**. Também há **Treine em Casa** (peso corporal) e **Mobilidade**.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "serie", "series", "repeticao", "repeticoes", "reps", "quantas series",
            ),
            respond = { ctx ->
                val scheme = when {
                    ctx.isMuscleGain -> "3–5 séries × 6–12 reps (hipertrofia). Descanso 60–90 s."
                    ctx.isFatLoss -> "3–4 séries × 8–15 reps. Mantenha carga desafiadora."
                    ctx.isEndurance -> "2–3 séries × 15–20 reps ou circuitos."
                    else -> "3 séries × 8–12 reps — equilíbrio força e volume."
                }
                """
                Séries e repetições dependem do objetivo (${ctx.objective}):

                $scheme

                Regras gerais:
                • Últimas 2–3 reps devem ser difíceis (RPE 7–9)
                • Progressão: aumente carga ou reps quando completar o topo da faixa
                • Registre no app para acompanhar evolução
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "descanso entre series", "intervalo", "pausa entre", "descanso entre",
            ),
            respond = {
                """
                Descanso entre séries:

                • Força (1–5 reps): 2–5 min
                • Hipertrofia (6–12 reps): 60–90 s
                • Resistência (15+ reps): 30–60 s
                • Exercícios compostos (agachamento, terra): mais descanso
                • Isolados (rosca, extensora): menos descanso

                Descanso insuficiente reduz performance; excessivo esfria o músculo. Use o timer do app durante o treino.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("aquecimento", "alongamento", "warm up", "warmup", "mobilidade", "flexibilidade"),
            respond = {
                """
                Aquecimento (5–10 min antes do treino):
                • Cardio leve (esteira, bike)
                • Mobilidade articular
                • 1–2 séries leves do primeiro exercício

                Alongamento:
                • Dinâmico antes do treino
                • Estático após o treino (15–30 s por músculo)

                Reduz risco de lesão e melhora amplitude de movimento.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "progressao", "carga", "sobrecarga", "evoluir", "aumentar peso", "plateau", "estagnado",
            ),
            respond = {
                """
                Progressão de carga (sobrecarga progressiva):

                • Quando completar todas as reps com boa forma → aumente 2,5–5 kg (membros superiores) ou 5–10 kg (inferiores)
                • Ou adicione 1–2 reps por série
                • Anote pesos no app — compare semana a semana

                Estagnou? Varie exercícios, aumente volume ou revise sono/alimentação.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "cardio", "corrida", "caminhada", "esteira", "bike", "bicicleta", "aerobico", "eliptico",
            ),
            respond = { ctx ->
                """
                Cardio melhora condicionamento, queima calorias e saúde cardiovascular.

                Indicado para ${ctx.objective} e recuperação ativa.
                • Leve: caminhada, bike leve — recuperação
                • Moderado: corrida leve, elíptico — queima calorias
                • Intenso: HIIT, sprints — condicionamento avançado

                No HealthFit: Treinos → Cardio. Combine 1–3 sessões/semana com musculação.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("hiit", "intervalado", "sprint", "alta intensidade"),
            respond = { ctx ->
                """
                HIIT (treino intervalado de alta intensidade) alterna esforço máximo e recuperação.

                Benefícios: condicionamento rápido, queima calórica elevada.
                Riscos: exige base cardiovascular; não ideal para iniciantes ou todos os dias.

                Para ${ctx.objective.lowercase()}: 1–2x/semana, além de musculação.
                No app: Treinos → Cardio → opções intensas.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("meditacao", "mindfulness", "relaxar", "ansiedade", "estresse"),
            respond = {
                """
                Meditação reduz estresse, melhora foco e apoia recuperação.

                Benefícios:
                • Melhor qualidade do sono
                • Menos cortisol
                • Mais consistência nos hábitos

                No app: Treinos → Meditação. 5–10 minutos já fazem diferença. Complementa treino e dieta.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("melhor", "qual escolher", "treino ou", "cardio ou", "comparar", "versus", " vs "),
            respond = { ctx ->
                val recommendation = when {
                    ctx.isMuscleGain -> "Priorize musculação (4–5x/semana). Cardio leve 1–2x. Meditação para recuperação."
                    ctx.isFatLoss -> "Musculação 3–4x + déficit calórico. Cardio 2–3x. Meditação para sono e adesão."
                    ctx.isEndurance -> "Cardio 3–4x + musculação 2x para prevenir lesões. Meditação para foco."
                    else -> "Combine musculação 2–3x, cardio 2x e meditação 2–3x por semana."
                }
                """
                Não existe um só "melhor" — depende do objetivo (${ctx.objective}):

                • Musculação — massa muscular, força, metabolismo
                • Cardio — condicionamento, calorias, coração
                • Meditação — mente, sono, estresse

                Recomendação para você: $recommendation

                O ideal é combinar os três ao longo da semana.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "peito", "supino", "costas", "dorsal", "perna", "pernas", "agachamento", "gluteo",
                "ombro", "ombros", "braco", "biceps", "triceps", "abdomen", "abdominal", "core",
            ),
            respond = {
                """
                Grupos musculares no app:

                • Peito — supino reto/inclinado, crucifixo, crossover
                • Costas — remada, puxada, levantamento terra
                • Pernas — agachamento, leg press, extensora, flexora, panturrilha
                • Ombros — desenvolvimento, elevação lateral/frontal
                • Braços — rosca (bíceps), tríceps pulley/testa
                • Core — estabilização em compostos + abdominais

                Fichas divididas (A/B/C) cobrem todos os grupos na semana. Veja guia de execução em cada exercício.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "frequencia", "quantos treinos", "vezes por semana", "dias de treino", "split",
            ),
            respond = { ctx ->
                """
                Frequência de treinos para ${ctx.objective}:

                ${goalTrainingSummary(ctx.objective)}

                Splits comuns:
                • Full body — 3x/semana (iniciantes)
                • ABC — 3–6x/semana (intermediários)
                • Push/Pull/Legs — 4–6x/semana (avançados)

                Descanse 48 h entre treinos do mesmo grupo muscular.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "lesao", "dor", "machucado", "contusao", "tendinite",
                "mal-estar", "mal estar", "tontura", "ferido", "inflamacao",
                "desconforto", "duvida no exercicio",
            ),
            respond = {
                """
                $Disclaimer

                Dor vs desconforto muscular:
                • Desconforto muscular (DOMS) 24–48 h após treino — normal
                • Dor aguda, articular, pontual, com formigamento ou falta de ar — pare imediatamente

                Se sentir dor, dúvida ou desconforto no exercício:
                • Interrompa o exercício na hora
                • Não treine a região afetada
                • Procure um profissional de saúde qualificado e habilitado (médico, fisioterapeuta ou emergência)
                • Não busque diagnóstico, tratamento ou “o que fazer” em ferramentas de IA

                Este assistente é apenas informativo e não substitui atendimento médico.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("personal", "relatorio", "email", "e-mail", "enviar treino"),
            respond = {
                """
                Relatórios de treino no HealthFit:

                • Ao finalizar musculação ou cardio, o app gera o resumo
                • Compartilhe o relatório com seu personal pelos apps do celular (Gmail, WhatsApp, etc.)
                • Inclui exercícios, séries, cargas, cardio e uso de pré-treino
                • Cadastre o personal em Perfil se ainda não tiver

                Relatório semanal em Início → Progresso Semanal.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "consulta", "agendar", "agendamento", "horario livre", "horarios livres",
                "agenda", "marcar consulta", "nutricionista consulta", "personal consulta",
                "slot", "disponibilidade",
            ),
            respond = {
                """
                Agenda de consultas no HealthFit Coach:

                • Assistente de agendamento: analisa a agenda do personal/nutri e sugere horários livres.
                • Calendário: você escolhe data e hora manualmente.
                • Depois de marcar, você pode cancelar ou remarcar a qualquer momento.
                • Personal e nutricionista têm agendas separadas no vínculo.

                Em **Perfil → HealthFit Coach**, entre com o código do profissional (plano Fit+).
                Sem vínculo, a agenda fica indisponível até conectar o personal ou nutricionista.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "conforme o personal", "conforme personal", "orientacao profissional",
                "seguir ficha", "ficha do personal", "treinar certo", "execucao correta",
                "como treinar", "guia de exercicio", "profissional prescreveu",
                "prescricao", "seguir treino", "treino profissional",
            ),
            respond = {
                """
                Como treinar conforme orientação profissional no HealthFit:

                1. Siga a ficha prescrita
                • Treinos → Musculação → escolha a ficha do seu plano
                • Respeite séries, repetições e descanso indicados
                • Não aumente carga por conta própria sem aval do personal

                2. Execução correta
                • Toque em cada exercício para ver o guia passo a passo
                • Priorize amplitude e forma antes de peso
                • Use o timer de descanso entre séries

                3. Registre tudo
                • Anote cargas e reps reais durante o treino
                • Ao finalizar, o relatório é gerado automaticamente

                4. Comunicação com o personal
                • Cadastre nome do personal em Perfil
                • Compartilhe o resumo do treino pelos apps do celular
                • Leve o histórico de treinos nas consultas

                O app complementa o acompanhamento — dúvidas técnicas ou dores persistentes, consulte sempre o profissional.

                $Disclaimer
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("overtraining", "excesso de treino", "treinar todo dia", "fadiga", "cansaco"),
            respond = {
                """
                Sinais de overtraining (excesso):
                • Queda de performance
                • Fadiga persistente
                • Sono ruim, irritabilidade
                • Dores que não passam

                Prevenção:
                • 1–2 dias de descanso/semana
                • Durma 7–9 h
                • Alimentação e hidratação adequadas
                • Periodize intensidade (nem todo treino é máximo)
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "objetivo", "ganho de massa treino", "resistencia", "manutencao",
            ),
            respond = { ctx ->
                """
                Seu objetivo: ${ctx.objective}

                Dieta: ${ctx.dailyCalorieTarget} kcal/dia (TDEE ${ctx.estimatedTdee}).
                Treino: ${goalTrainingSummary(ctx.objective)}

                Cardápio e fichas se adaptam ao objetivo. Altere em Perfil quando mudar de fase.
                """.trimIndent()
            },
        ),
    )

    private val biotypeTopics: List<AssistantTopic> = listOf(
        AssistantTopic(
            keywords = listOf(
                "ectomorfo", "o que e ectomorfo", "definicao ectomorfo",
                "significado ectomorfo", "ecto morfo", "sou ectomorfo",
            ),
            respond = { ctx ->
                val isUser = ctx.bodyType == BodyType.Ectomorph
                var text = ectomorphDefinition(isUser)
                text += if (isUser) {
                    "\n\nSeu TDEE ajustado: ${ctx.estimatedTdee} kcal/dia (metabolismo +10%)."
                } else {
                    "\n\nNo app, ectomorfos recebem +10% no TDEE. Seu biotipo: ${ctx.bodyType.title}. TDEE: ${ctx.estimatedTdee} kcal/dia."
                }
                text
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "mesomorfo", "o que e mesomorfo", "definicao mesomorfo",
                "significado mesomorfo", "meso morfo", "sou mesomorfo",
            ),
            respond = { ctx ->
                val isUser = ctx.bodyType == BodyType.Mesomorph
                var text = mesomorphDefinition(isUser)
                text += if (isUser) {
                    "\n\nSeu TDEE: ${ctx.estimatedTdee} kcal/dia."
                } else {
                    "\n\nSeu biotipo: ${ctx.bodyType.title}. TDEE: ${ctx.estimatedTdee} kcal/dia."
                }
                text
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "endomorfo", "o que e endomorfo", "definicao endomorfo",
                "significado endomorfo", "endo morfo", "sou endomorfo",
            ),
            respond = { ctx ->
                val isUser = ctx.bodyType == BodyType.Endomorph
                var text = endomorphDefinition(isUser)
                text += if (isUser) {
                    "\n\nSeu TDEE ajustado: ${ctx.estimatedTdee} kcal/dia (metabolismo −10%)."
                } else {
                    "\n\nNo app, endomorfos recebem −10% no TDEE. Seu biotipo: ${ctx.bodyType.title}. TDEE: ${ctx.estimatedTdee} kcal/dia."
                }
                text
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "biotipo", "biotipos", "somatotipo", "somatotipos", "tipos corporais", "tipo corporal",
            ),
            respond = { ctx ->
                """
                Seu biotipo: ${ctx.bodyType.title}
                ${ctx.bodyType.detail}

                Resumo dos três biotipos:
                • Ectomorfo — magro, metabolismo rápido (+10% TDEE)
                • Mesomorfo — atlético, responde bem ao treino
                • Endomorfo — acumula gordura com facilidade (−10% TDEE)

                O biotipo ajusta levemente calorias e estratégias, mas não limita seus resultados.
                """.trimIndent()
            },
        ),
    )

    private val generalTopics: List<AssistantTopic> = listOf(
        AssistantTopic(
            keywords = listOf("metabolismo basal", "tmb", "basal"),
            respond = { ctx ->
                """
                Metabolismo basal (TMB) = calorias em repouso absoluto (respiração, circulação, órgãos).

                Sua TMB: ${ctx.basalMetabolicRate} kcal/dia.
                TDEE (atividade moderada): ${ctx.estimatedTdee} kcal/dia.
                Meta: ${ctx.dailyCalorieTarget} kcal/dia para ${ctx.objective.lowercase()}.

                Varia com peso, altura, idade, sexo e biotipo (${ctx.bodyType.title}).
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("tdee", "gasto calorico", "meta calorica", "calorias"),
            respond = { ctx ->
                """
                TDEE = gasto calórico total (TMB + atividade diária).

                Sua TMB: ${ctx.basalMetabolicRate} kcal/dia.
                TDEE estimado: ${ctx.estimatedTdee} kcal/dia.
                Meta do plano: ${ctx.dailyCalorieTarget} kcal/dia.

                Emagrecer → abaixo do TDEE. Ganhar massa → acima. Manter → perto do TDEE.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf("agua", "hidrata", "beber", "desidrata", "liquido"),
            respond = { ctx ->
                val goal = ctx.waterGoalMl
                val current = ctx.waterMl
                val remaining = maxOf(goal - current, 0)
                val liters = goal / 1000.0
                """
                Sem água suficiente: cansaço, dor de cabeça, queda no treino, recuperação lenta, confusão fome/sede.

                Meta: $goal ml/dia (~${"%.1f".format(liters)} L).
                Hoje: $current ml.
                ${if (remaining > 0) "Faltam ~$remaining ml." else "Meta atingida hoje!"}

                Beba ao longo do dia; aumente em dias de treino ou calor.
                """.trimIndent()
            },
        ),
        AssistantTopic(
            keywords = listOf(
                "sono", "dormir", "descanso", "recuperacao",
                "dormir corretamente", "dormir bem", "higiene do sono", "rotina de sono",
                "insomnia", "insonia", "noite", "cama", "horas de sono", "qualidade do sono",
            ),
            respond = { ctx ->
                val todayNote = sleepStatusLine(ctx.sleepHours)
                """
                Como dormir corretamente:

                Meta: 7–9 horas por noite (adultos).
                • < 5 h — sono não regulado; hormônios e recuperação prejudicados
                • 5–7 h — aumente gradualmente
                • 7–9 h — ideal para treino, músculo e perda de gordura
                • > 9 h — ok ocasionalmente; avalie se há fadiga excessiva

                $todayNote

                Higiene do sono:
                • Horário fixo para deitar e acordar (inclusive fim de semana)
                • Quarto escuro, silencioso e fresco
                • Evite telas 30–60 min antes de dormir
                • Sem cafeína/energético à tarde/noite
                • Jantar leve 2–3 h antes de deitar
                • Meditação no app (Treinos → Meditação) ajuda a relaxar

                Sono ruim sabota treino e dieta — trate o descanso como parte do plano.
                """.trimIndent()
            },
        ),
    )

    private val allTopics: List<AssistantTopic> =
        steroidTopics +
            SupplementationGuideEngine.assistantTopics() +
            dietTopics +
            imcTopics +
            bodyEvolutionTopics +
            workoutTopics +
            biotypeTopics +
            generalTopics
}
