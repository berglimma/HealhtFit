package com.healthfit.android.ui.assistant

import kotlin.math.roundToInt

/** Port of iOS SupplementationGuideEngine — 16 topics with Portuguese FAQ copy. */
object SupplementationGuideEngine {

    fun assistantTopics(): List<AssistantTopic> = listOf(
        AssistantTopic(overviewKeywords) { overview() },
        AssistantTopic(wheyKeywords) { ctx -> whey(ctx) },
        AssistantTopic(creatineKeywords) { creatine() },
        AssistantTopic(preWorkoutKeywords) { preWorkout() },
        AssistantTopic(betaAlanineKeywords) { betaAlanine() },
        AssistantTopic(omega3Keywords) { omega3() },
        AssistantTopic(bcaaKeywords) { bcaa() },
        AssistantTopic(glutamineKeywords) { glutamine() },
        AssistantTopic(vitaminDKeywords) { vitaminD() },
        AssistantTopic(multivitaminKeywords) { multivitamin() },
        AssistantTopic(caseinKeywords) { casein() },
        AssistantTopic(massGainerKeywords) { massGainer() },
        AssistantTopic(collagenKeywords) { collagen() },
        AssistantTopic(zmaKeywords) { zma() },
        AssistantTopic(caffeineKeywords) { caffeine() },
        AssistantTopic(plantProteinKeywords) { ctx -> plantProtein(ctx) },
    )

    private val overviewKeywords = listOf(
        "suplementacao", "suplemento", "suplementos", "vale a pena suplementar",
        "preciso suplementar", "quais suplementos", "guia de suplementos", "tipos de suplemento",
        "para que serve suplemento", "suplementar faz bem", "devo tomar suplemento",
    )

    private val wheyKeywords = listOf(
        "whey", "whey protein", "proteina do soro", "whey concentrado",
        "whey isolado", "whey hidrolisado", "shake de proteina",
    )

    private val creatineKeywords = listOf(
        "creatina", "creatina monohidratada", "creatina micronizada", "quanto de creatina",
    )

    private val preWorkoutKeywords = listOf(
        "pre treino", "pre-treino", "pretreino", "preworkout",
    )

    private val betaAlanineKeywords = listOf(
        "beta alanina", "beta-alanina", "betaalanina", "formigamento muscular",
    )

    private val omega3Keywords = listOf(
        "omega 3", "omega-3", "oleo de peixe", "epa dha",
    )

    private val bcaaKeywords = listOf(
        "bcaa", "bcaas", "aminoacidos ramificados", "eaa", "eaas",
        "aminoacidos essenciais",
    )

    private val glutamineKeywords = listOf("glutamina", "l-glutamina")

    private val vitaminDKeywords = listOf(
        "vitamina d", "vitamina d3", "colecalciferol", "falta de sol",
    )

    private val multivitaminKeywords = listOf(
        "multivitaminico", "polivitaminico", "complexo vitaminico",
    )

    private val caseinKeywords = listOf("caseina", "proteina noturna")

    private val massGainerKeywords = listOf(
        "hipercalorico", "mass gainer", "ganho de peso", "engordar rapido",
    )

    private val collagenKeywords = listOf("colageno", "colageno hidrolisado")

    private val zmaKeywords = listOf(
        "zma", "magnesio", "zinco treino", "melatonina natural",
    )

    private val caffeineKeywords = listOf(
        "cafeina", "energetico", "monster", "red bull", "energia artificial",
    )

    private val plantProteinKeywords = listOf(
        "proteina vegetal", "proteina vegana", "ervilha", "soja proteina",
    )

    fun overview(): String = """
        💊 Guia de suplementação no HealthFit

        Suplementos **complementam** alimentação e treino — não substituem refeições, sono ou consistência.

        ✅ Quando faz sentido
        • Dificuldade em bater proteína diária → whey ou proteína vegetal
        • Força e volume muscular → creatina (evidência forte)
        • Saúde geral → ômega 3, vitamina D (se deficiente)
        • Foco no treino → pré-treino ou cafeína com moderação
        • Recuperação e sono → magnésio/ZMA, caseína à noite

        ⚠️ O que o excesso causa em geral
        • Desconforto gastrointestinal (náusea, gases, diarreia)
        • Sobrecarga renal/hepática em doses altas crônicas
        • Falsa sensação de que “suplemento resolve” má dieta
        • Interações medicamentosas (sempre consulte médico)

        📋 Ordem de prioridade
        1. Alimentação sólida
        2. Sono (7–9 h)
        3. Treino consistente
        4. Suplementos estratégicos

        Pergunte sobre um suplemento específico: whey, creatina, pré-treino, ômega 3, BCAA, vitamina D e outros.
    """.trimIndent()

    fun whey(ctx: AssistantAnswerContext): String {
        val low = (ctx.weightKg * 1.8f).roundToInt()
        val high = (ctx.weightKg * 2.2f).roundToInt()
        val lactoseNote = if (ctx.lactoseLabel?.contains("intoler", ignoreCase = true) == true) {
            "\n\n⚠️ Você marcou intolerância à lactose — prefira whey isolado ou proteína vegetal."
        } else {
            ""
        }
        return """
            🥛 Whey Protein

            ✅ Benefícios
            • Conveniência para bater meta de proteína (sua meta: ~$low–$high g/dia)
            • Rápida digestão — ideal pós-treino
            • Rico em leucina — estimula síntese proteica muscular
            • Prático entre refeições ou no café da manhã

            📋 Uso recomendado
            • 20–40 g por dose (1 scoop), 1–2x/dia conforme necessidade
            • Pós-treino ou quando faltar proteína na refeição
            • Misture com água ou leite (se tolera lactose)

            ⚠️ Excesso e riscos
            • Acima de 40–50 g de uma vez: desconforto intestinal, gases, inchaço
            • Excesso calórico se misturar com muito leite, pasta de amendoim e frutas sem controle
            • Não substitui frango, ovos, peixe — alimentos trazem micronutrientes
            • Intolerância à lactose: preferir isolado, hidrolisado ou proteína vegetal
            $lactoseNote

            Whey é ferramenta de conveniência, não mágica. Priorize comida de verdade.
        """.trimIndent()
    }

    fun creatine(): String = """
        💪 Creatina (monohidratada)

        ✅ Benefícios
        • Aumenta força e potência em treinos de alta intensidade
        • Melhora volume de treino (mais reps/carga)
        • Pode ajudar ganho de massa muscular ao longo do tempo
        • Um dos suplementos com mais evidência científica
        • Barata e segura para saúde em doses padrão

        📋 Uso recomendado
        • 3–5 g/dia, todos os dias (com ou sem treino)
        • Pode tomar a qualquer hora; pós-treino ou com refeição facilita adesão
        • Fase de saturação (20 g/dia) é opcional — não obrigatória
        • Beba água adequadamente

        ⚠️ Excesso e riscos
        • Acima de 10 g/dia sem necessidade: desconforto estomacal, gases, diarreia
        • Retenção hídrica intramuscular (1–2 kg) — normal, não é gordura
        • Mitos sobre rim: em pessoas saudáveis, 3–5 g/dia é seguro; quem tem doença renal deve consultar médico
        • Não “secar” creatina — interromper só reduz estoques musculares

        Creatina funciona com consistência diária, não só no dia de treino.
    """.trimIndent()

    fun preWorkout(): String = """
        ⚡ Pré-treino

        ✅ Benefícios
        • Mais foco, energia e disposição para treinar
        • Cafeína melhora performance e reduz percepção de esforço
        • Beta-alanina e citrulina podem aumentar resistência muscular
        • Ajuda em dias de baixa motivação (com moderação)

        📋 Uso recomendado
        • 30–45 min antes do treino, conforme rótulo
        • Comece com meia dose para testar tolerância
        • Evite à noite se tiver insônia
        • No HealthFit: registre ao iniciar o treino (Perfil → pré-treino)

        ⚠️ Excesso e riscos
        • Muita cafeína: taquicardia, ansiedade, insônia, tremores, dependência
        • Uso diário alto: tolerância — precisa de doses maiores para mesmo efeito
        • Formigamento intenso (beta-alanina) em doses altas — desconfortável mas geralmente inofensivo
        • Pressão arterial elevada em sensíveis — evite se cardiopata sem liberação médica
        • Não substitui sono, alimentação e hidratação

        Use pré-treino estrategicamente, não como “muleta” todos os dias.
    """.trimIndent()

    fun betaAlanine(): String = """
        🔥 Beta-alanina

        ✅ Benefícios
        • Aumenta carnosina muscular — retarda fadiga em exercícios de 1–4 minutos
        • Melhora performance em séries longas e HIIT
        • Complementa creatina em treinos de alta intensidade

        📋 Uso recomendado
        • 3,2–6,4 g/dia divididos em doses de 0,8–1,6 g
        • Efeito acumula com uso diário (2–4 semanas)
        • Pode estar no pré-treino ou tomada separada

        ⚠️ Excesso e riscos
        • Formigamento (parestesia) na pele — comum e inofensivo, mais intenso em doses altas de uma vez
        • Dividir a dose reduz o formigamento
        • Sem benefício extra acima de ~6,4 g/dia para a maioria
        • Não é estimulante — não confunda com cafeína

        Beta-alanina exige constância; o formigamento é normal, não é alergia.
    """.trimIndent()

    fun omega3(): String = """
        🐟 Ômega 3 (EPA + DHA)

        ✅ Benefícios
        • Saúde cardiovascular — triglicerídeos e inflamação
        • Apoio à recuperação muscular (efeito anti-inflamatório leve)
        • Saúde cerebral e humor
        • Pode ajudar articulações em atletas

        📋 Uso recomendado
        • 1–3 g/dia de EPA+DHA combinados (veja o rótulo, não só “óleo de peixe”)
        • Com refeição para melhor absorção
        • Peixes gordos (salmão, sardinha) 2–3x/semana também contam

        ⚠️ Excesso e riscos
        • Doses muito altas (>3–4 g EPA+DHA): risco de sangramento, especialmente com anticoagulantes
        • Desconforto gastrointestinal, refluxo, gosto de peixe
        • Qualidade importa — rancificação pode ser prejudicial
        • Não cancela dieta ruim ou sedentarismo

        Ômega 3 é suplemento de saúde, não queimador de gordura.
    """.trimIndent()

    fun bcaa(): String = """
        🧬 BCAA / EAA (aminoácidos)

        ✅ Benefícios
        • BCAA (leucina, isoleucina, valina): podem reduzir fadiga central levemente
        • EAA (aminoácidos essenciais): perfil mais completo que BCAA isolado
        • Úteis em treino em jejum prolongado (casos específicos)
        • Sabor e hidratação durante treino longo

        📋 Uso recomendado
        • 5–10 g durante treino longo (>90 min) ou se proteína da dieta estiver baixa
        • EAA geralmente superior a BCAA isolado
        • Se já come proteína suficiente, benefício extra é pequeno

        ⚠️ Excesso e riscos
        • Caro em relação ao benefício se dieta proteica já está ok
        • Excesso sem necessidade: dinheiro jogado fora, possível desconforto
        • BCAA isolado sem outros aminoácidos pode ser inferior a proteína completa
        • Não substitui whey, ovos ou carne

        Se bate proteína diária, BCAA/EAA é opcional — não essencial.
    """.trimIndent()

    fun glutamine(): String = """
        🌿 Glutamina

        ✅ Benefícios
        • Aminoácido mais abundante no corpo
        • Pode apoiar recuperação intestinal em atletas de alto volume
        • Alguns usam em períodos de dieta muito restritiva
        • Evidência para performance é modesta

        📋 Uso recomendado
        • 5–10 g/dia se houver indicação específica
        • Geralmente desnecessária com dieta proteica adequada

        ⚠️ Excesso e riscos
        • Doses altas: desconforto gastrointestinal
        • Custo-benefício baixo para a maioria dos praticantes
        • Não é “anti-catabolismo mágico”
        • Quem tem doença hepática ou renal deve consultar médico

        Para a maioria: priorize whey e comida antes de glutamina.
    """.trimIndent()

    fun vitaminD(): String = """
        ☀️ Vitamina D

        ✅ Benefícios
        • Saúde óssea — absorção de cálcio
        • Função imune e muscular
        • Humor e energia (se você estava deficiente)
        • Muitas pessoas têm níveis baixos (pouco sol, trabalho indoor)

        📋 Uso recomendado
        • Ideal: dosar sangue (25-OH vitamina D) com médico
        • Manutenção comum: 1.000–2.000 UI/dia se deficiente leve (seguir prescrição)
        • Tomar com refeição gordurosa melhora absorção

        ⚠️ Excesso e riscos
        • Megadoses sem exame: hipercalcemia (náusea, confusão, pedras nos rins)
        • Acima de 4.000 UI/dia crônico sem acompanhamento: risco aumentado
        • Não “tomar sol em cápsula” em excesso — toxicidade é real
        • Interage com alguns medicamentos

        Exame de sangue antes de megadosar. Suplementar às cegas não é ideal.
    """.trimIndent()

    fun multivitamin(): String = """
        💊 Multivitamínico

        ✅ Benefícios
        • Cobre lacunas de micronutrientes em dietas restritivas
        • Praticidade para quem come pouca variedade
        • Pode apoiar imunidade se houver deficiências
        • Útil em cutting agressivo ou veganismo mal planejado

        📋 Uso recomendado
        • 1 dose/dia conforme rótulo, com refeição
        • Não substitui frutas, verduras e proteínas variadas

        ⚠️ Excesso e riscos
        • Excesso de vitamina A e ferro (em alguns multis): toxicidade
        • “Mais não é melhor” — megadoses sem necessidade
        • Máscara dieta ruim em vez de corrigir alimentação
        • Interações com medicamentos (anticoagulantes, tireoide)

        Multivitamínico é rede de segurança, não base da nutrição.
    """.trimIndent()

    fun casein(): String = """
        🌙 Caseína

        ✅ Benefícios
        • Proteína de digestão lenta — liberação gradual de aminoácidos
        • Ideal antes de dormir para suporte muscular noturno
        • Maior saciedade — ajuda em déficit calórico
        • Alternativa ao whey à noite

        📋 Uso recomendado
        • 20–40 g 30–60 min antes de dormir
        • Ou como lanche entre refeições longas
        • Iogurte grego e queijo cottage também são fontes naturais

        ⚠️ Excesso e riscos
        • Calorias extras se não couber no plano diário
        • Intolerância à lactose: desconforto intestinal
        • Não é obrigatória — whey + comida funcionam bem
        • Excesso proteico total: estresse renal em predisposição (raro em saudáveis)

        Caseína é whey “lento” — escolha conforme rotina e tolerância.
    """.trimIndent()

    fun massGainer(): String = """
        📈 Hipercalórico (Mass Gainer)

        ✅ Benefícios
        • Facilita superávit calórico para quem não consegue comer volume
        • Combina proteína + carboidrato em uma dose
        • Prático para ectomorfos com apetite baixo
        • Ganho de peso mais rápido em bulking

        📋 Uso recomendado
        • 1 shake/dia entre refeições ou pós-treino
        • Ajuste porção conforme meta calórica
        • Prefira ganho gradual (0,25–0,5 kg/semana)

        ⚠️ Excesso e riscos
        • Ganho de gordura, não só músculo, se exagerar
        • Muito açúcar em alguns produtos — picos glicêmicos
        • Substituir refeições reais prejudica micronutrientes
        • Caro em relação a arroz, aveia e frango

        Hipercalórico é atalho calórico — use se não conseguir comer, não por preguiça de cozinhar.
    """.trimIndent()

    fun collagen(): String = """
        🦴 Colágeno

        ✅ Benefícios
        • Pode apoiar saúde de pele, unhas e cabelo (evidência moderada)
        • Alguns relatam melhora em articulações e tendões
        • Proteína estrutural — complemento, não substituto de whey
        • Útil em recuperação de lesões (com orientação profissional)

        📋 Uso recomendado
        • 10–15 g/dia de colágeno hidrolisado
        • Com vitamina C melhora síntese (laranja ou suplemento)
        • Consistência por 8–12 semanas para avaliar efeito

        ⚠️ Excesso e riscos
        • Não constrói músculo como proteína completa (baixa leucina)
        • Excesso: desconforto digestivo leve
        • Expectativa irreal — não “rejuvenesce” sozinho
        • Não substitui treino de força para articulações

        Colágeno é complemento estético/articular, não proteína principal.
    """.trimIndent()

    fun zma(): String = """
        😴 ZMA / Magnésio

        ✅ Benefícios
        • Magnésio: relaxamento muscular, qualidade do sono, função nervosa
        • Zinco: imunidade, testosterona (se deficiente)
        • Pode reduzir cãibras noturnas em deficientes
        • Apoia recuperação em atletas com baixa ingestão

        📋 Uso recomendado
        • ZMA: conforme rótulo, 30–60 min antes de dormir
        • Magnésio: 200–400 mg de magnésio elementar/dia
        • Fontes alimentares: castanhas, sementes, folhas verdes

        ⚠️ Excesso e riscos
        • Excesso de zinco: náusea, competição com cobre, imunidade prejudicada
        • Magnésio alto: diarreia (forma citrato mais laxante)
        • Não é sedativo forte — expectativa realista
        • Interação com antibióticos e outros fármacos

        Teste sono e alimentação antes de depender de ZMA.
    """.trimIndent()

    fun caffeine(): String = """
        ☕ Cafeína / Energéticos

        ✅ Benefícios
        • Aumenta alerta, foco e performance (3–6 mg/kg)
        • Reduz percepção de esforço no treino
        • Pode aumentar termogênese levemente
        • Conveniente antes de treinos matinais

        📋 Uso recomendado
        • 100–200 mg antes do treino (1–2 xícaras de café)
        • Evite 6 h antes de dormir
        • OMS: moderação em energéticos (alerta acima de 2/semana em excesso)

        ⚠️ Excesso e riscos
        • Insônia, ansiedade, taquicardia, dependência
        • Tolerância — precisa de mais para mesmo efeito
        • Energéticos: muito açúcar + cafeína — calorias vazias
        • Combinação com pré-treino + café + energético = overdose fácil
        • Desidratação se não compensar com água

        No HealthFit: registre energéticos no Perfil. Moderação é chave.
    """.trimIndent()

    fun plantProtein(ctx: AssistantAnswerContext): String {
        val lactoseNote = if (ctx.lactoseLabel?.contains("intoler", ignoreCase = true) == true) {
            " Você marcou intolerância à lactose — proteína vegetal é excelente alternativa ao whey."
        } else {
            ""
        }
        return """
            🌱 Proteína vegetal (ervilha, arroz, soja)

            ✅ Benefícios
            • Opção para intolerância à lactose e veganos
            • Boa digestão para muitas pessoas sensíveis ao whey
            • Blend ervilha+arroz tem perfil completo de aminoácidos
            • Menos impacto ambiental que whey para alguns

            📋 Uso recomendado
            • 20–40 g por dose, igual ao whey
            • Prefira blends (não fonte única isolada)
            • Combine com dieta variada (leguminosas, grãos)

            ⚠️ Excesso e riscos
            • Sabor e textura podem ser menos agradáveis
            • Soja em excesso: debate sobre hormônios — moderação em predisposição
            • Custo por grama de proteína às vezes maior
            • Mesmos riscos de excesso proteico que whey (intestinal, calorias)$lactoseNote

            Proteína vegetal de qualidade equivale ao whey para ganho muscular.
        """.trimIndent()
    }
}
