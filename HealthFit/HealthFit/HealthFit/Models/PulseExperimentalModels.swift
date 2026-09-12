import Foundation

/// HealthFit Pulse — compilado em Debug e Release.
/// UI/sync OFF por padrão; produção liga via Firestore `appConfig/ios` (`pulseEnabled` / `pulseCloudSyncEnabled`).
/// DEBUG: Perfil → Labs pode forçar ON localmente.
enum PulseExperimental {
    static var featureName: String { L10n.Pulse.featureName }
    static var tagline: String { L10n.Pulse.tagline }
    static let maxCaptionCharacters = 350
    static let maxVideoSeconds: TimeInterval = 30
    /// Trecho de música no story/post (máx. 15s).
    static let maxMusicClipSeconds: TimeInterval = 15
    /// Alias explícito para UI de story (mesmo limite que `maxMusicClipSeconds`).
    static let storyMusicMaxSeconds: TimeInterval = 15
    static let minMusicClipSeconds: TimeInterval = 5
    static let storyLifetime: TimeInterval = 12 * 60 * 60
    /// Tempo de exibição de cada story no viewer (passagem automática).
    static let storyViewDuration: TimeInterval = 15
    /// Posts expiram e são excluídos automaticamente após 24h.
    static let postLifetime: TimeInterval = 24 * 60 * 60
    /// App general age stays 16+; Pulse UGC (feed, stories, comunidades, people) require 18+.
    static let communityMinimumAge = 18
    /// Alias explícito para gate de UGC em todo o Pulse.
    static var ugcMinimumAge: Int { communityMinimumAge }
    /// Bio curta no perfil Pulse (visível na busca de pessoas).
    static let maxBioCharacters = 100
    static let termsVersion = "pulse-terms-v4-2026-09"
    /// Tag Firestore `source` (rules aceitam este valor e o legado labs).
    static let cloudSourceTag = "healthfit-pulse"

    /// Chat entre seguidores: só em builds DEBUG por enquanto.
    static var isChatEnabledInBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// Posts em vídeo: só em builds DEBUG por enquanto.
    static var isVideoPostsEnabledInBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static let labEnabledKey = "pulse.experimental.labEnabled"
    private static let demoContentKey = "pulse.experimental.includeDemoContent"
    private static let termsAcceptedPrefix = "pulse.experimental.termsAccepted."
    private static let spotifyClientIdKey = "pulse.experimental.spotifyClientId"
    private static let spotifyClientSecretKey = "pulse.experimental.spotifyClientSecret"
    private static let cloudSyncEnabledKey = "pulse.experimental.cloudSyncEnabled"
    private static let remoteUIEnabledKey = "pulse.remote.uiEnabled"
    private static let remoteCloudSyncEnabledKey = "pulse.remote.cloudSyncEnabled"

    static var isLabEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: labEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: labEnabledKey) }
    }

    /// Cache do flag remoto `appConfig/ios.pulseEnabled` (default false).
    static var remoteUIEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: remoteUIEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: remoteUIEnabledKey) }
    }

    /// Cache do flag remoto `appConfig/ios.pulseCloudSyncEnabled` (default false).
    static var remoteCloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: remoteCloudSyncEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: remoteCloudSyncEnabledKey) }
    }

    /// UI do Pulse: em Release só a flag remota; em DEBUG também Labs.
    static var isUIEnabled: Bool {
        #if DEBUG
        isLabEnabled || remoteUIEnabled
        #else
        remoteUIEnabled
        #endif
    }

    /// Dados demo (posts/pessoas fake). Desligado por padrão — só via Labs.
    static var includeDemoContent: Bool {
        get {
            #if DEBUG
            UserDefaults.standard.bool(forKey: demoContentKey)
            #else
            false
            #endif
        }
        set {
            #if DEBUG
            UserDefaults.standard.set(newValue, forKey: demoContentKey)
            #endif
        }
    }

    /// Override local de sync (Labs). Preferir `isCloudSyncEffective` no runtime.
    static var isCloudSyncEnabled: Bool {
        get {
            #if DEBUG
            UserDefaults.standard.bool(forKey: cloudSyncEnabledKey)
            #else
            false
            #endif
        }
        set {
            #if DEBUG
            UserDefaults.standard.set(newValue, forKey: cloudSyncEnabledKey)
            #endif
        }
    }

    /// Sync nuvem efetivo: em Release só remoto; em DEBUG Labs **ou** remoto.
    static var isCloudSyncEffective: Bool {
        #if DEBUG
        isCloudSyncEnabled || remoteCloudSyncEnabled
        #else
        remoteCloudSyncEnabled
        #endif
    }

    /// Aplica flags lidas de `appConfig/ios` (sem alterar overrides de Labs).
    static func applyRemoteFlags(uiEnabled: Bool, cloudSyncEnabled: Bool) {
        remoteUIEnabled = uiEnabled
        remoteCloudSyncEnabled = cloudSyncEnabled
    }

    static var spotifyClientId: String {
        get { UserDefaults.standard.string(forKey: spotifyClientIdKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: spotifyClientIdKey) }
    }

    static var spotifyClientSecret: String {
        get { UserDefaults.standard.string(forKey: spotifyClientSecretKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: spotifyClientSecretKey) }
    }

    static var hasSpotifyCredentials: Bool {
        !spotifyClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !spotifyClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func hasAcceptedTerms(userId: String) -> Bool {
        UserDefaults.standard.bool(forKey: termsAcceptedPrefix + userId + "." + termsVersion)
    }

    static func acceptTerms(userId: String) {
        UserDefaults.standard.set(true, forKey: termsAcceptedPrefix + userId + "." + termsVersion)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: termsAcceptedPrefix + userId + ".at")
    }

    /// Limpa preferências locais do Pulse na exclusão de conta.
    static func clearAccountPreferences(userId: String) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: labEnabledKey)
        defaults.removeObject(forKey: demoContentKey)
        defaults.removeObject(forKey: cloudSyncEnabledKey)
        defaults.removeObject(forKey: spotifyClientIdKey)
        defaults.removeObject(forKey: spotifyClientSecretKey)
        defaults.removeObject(forKey: termsAcceptedPrefix + userId + "." + termsVersion)
        defaults.removeObject(forKey: termsAcceptedPrefix + userId + ".at")
        // Prefixo de termos de versões anteriores.
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(termsAcceptedPrefix + userId) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Desafio estável por dia do ano e por usuário (aleatório determinístico).
    static func dailyChallenge(for userId: String, on date: Date = Date()) -> String {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        let seed = Self.seed(year: year, userId: userId)
        let schedule = Self.challengeSchedule(seed: seed)
        let index = max(0, min(schedule.count - 1, dayOfYear - 1))
        return schedule[index]
    }

    private static func seed(year: Int, userId: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        let material = "\(year)|\(userId)|pulse-challenge-v1"
        for byte in material.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash == 0 ? 1 : hash
    }

    /// 366 desafios (cobre ano bissexto), embaralhados por seed do usuário/ano.
    private static func challengeSchedule(seed: UInt64) -> [String] {
        let templates = PulseLocalized.challengeTemplates
        var pool = templates.isEmpty ? challengeTemplatesFallbackPT : templates
        var guardCount = 0
        let base = pool
        while pool.count < 366 && guardCount < 20 {
            pool.append(contentsOf: base.map { "\($0) ✨" })
            guardCount += 1
        }
        pool = Array(pool.prefix(366))
        var rng = PulseSeededGenerator(seed: seed)
        for i in stride(from: pool.count - 1, through: 1, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            pool.swapAt(i, j)
        }
        return pool
    }

    /// Fallback se o JSON de desafios não estiver no bundle.
    private static let challengeTemplatesFallbackPT: [String] = [
        "Complete 20 min de movimento consciente hoje.",
        "Poste um treino com intensidade registrada (1–10).",
        "Hidrate-se: registre 2L e compartilhe no Pulse.",
        "Convide alguém do Duo para um check-in rápido.",
        "Faça 10 min de mobilidade e conte como se sentiu.",
        "Troque o elevador por escada e registre o desafio.",
        "Compartilhe uma refeição alinhada ao seu plano.",
        "Faça 30 agachamentos com atenção à postura.",
        "Caminhe 3.000 passos a mais que ontem.",
        "Finalize um cardio de 15 minutos sem pausar o celular.",
        "Poste um story de aquecimento antes do treino.",
        "Durma 30 minutos mais cedo e registre a energia.",
        "Faça 3 séries de prancha (20–40s).",
        "Beba um copo de água ao acordar e marque no Pulse.",
        "Troque 1 snack processado por fruta ou iogurte.",
        "Complete um treino de força focado em pernas.",
        "Faça 5 minutos de respiração antes do treino.",
        "Compartilhe sua playlist de treino no story.",
        "Realize 50 polichinelos em ritmo constante.",
        "Faça um treino Duo e publique o card.",
        "Alongue posteriores e quadril por 8 minutos.",
        "Suba escadas por 5 minutos contínuos.",
        "Registre a intensidade real do treino (sem maquiar).",
        "Faça 20 burpees quebrados em blocos confortáveis.",
        "Cozinhe uma refeição simples rica em proteína.",
        "Complete um treino de core de 12 minutos.",
        "Ande 20 minutos ao ar livre sem fones.",
        "Poste um antes/depois de humor pós-treino.",
        "Faça 4 séries de flexões (no seu nível).",
        "Reduza cafeína após 16h hoje.",
        "Complete uma sessão de mobilidade de ombros.",
        "Corra ou pedale 2 km em ritmo conversável.",
        "Faça 10 minutos de foam roller / massagem.",
        "Beba água a cada hora nas próximas 6 horas.",
        "Troque redes sociais por 1 treino curto.",
        "Faça um treino HIIT de 10–12 minutos.",
        "Prepare a roupa de treino na noite anterior.",
        "Complete 100 metros de caminhada rápida 6 vezes.",
        "Poste um check-in de gratidão pós-movimento.",
        "Faça 3 minutos de jump rope (ou simulado).",
        "Priorize proteína no almoço e registre.",
        "Faça um treino de costas e posterior.",
        "Descanse ativamente: caminhada leve de 15 min.",
        "Complete 8 minutos de yoga flow.",
        "Faça 40 elevações de panturrilha.",
        "Publique uma dica curta da sua comunidade.",
        "Treine só com peso corporal por 20 minutos.",
        "Faça 2 minutos de prancha lateral por lado.",
        "Beba chá ou água com limão no lugar de refrigerante.",
        "Complete um treino de peito e tríceps.",
        "Faça 15 minutos de bike ou elíptico.",
        "Registre sono e energia em 1 linha no Pulse.",
        "Faça 5 séries de 10 agachamentos isométricos.",
        "Caminhe depois do almoço por 10 minutos.",
        "Finalize o treino com 5 min de desaceleração.",
        "Faça um desafio de consistência: 1 série a mais.",
        "Poste um story motivando alguém do Duo.",
        "Complete 12 minutos de remo ou simulador.",
        "Faça 30 afundos alternados (15 por perna).",
        "Escolha vegetais em 2 refeições do dia.",
        "Faça um treino de ombros com controle de tempo.",
        "Realize 200 metros de caminhada inclinada.",
        "Alongue peitoral e flexores de quadril.",
        "Faça 8 minutos de shadow boxing / luta shadow.",
        "Beba 500 ml de água antes do almoço.",
        "Complete um treino full body curto.",
        "Faça 3 rounds de 40s on / 20s off.",
        "Poste a meta da semana em 1 frase.",
        "Faça 60 segundos de wall sit 3 vezes.",
        "Caminhe sem olhar o celular por 15 minutos.",
        "Faça 20 abdominais com qualidade, não velocidade.",
        "Prepare um lanche pós-treino com proteína.",
        "Complete 10 minutos de escada ou step.",
        "Faça um treino de glúteos focado e curto.",
        "Durma sem tela nos últimos 20 minutos.",
        "Faça 4 minutos de jumping jacks em blocos.",
        "Compartilhe um progresso pequeno (não só o grande).",
        "Faça 15 minutos de natação ou movimento aquático.",
        "Realize 3 séries de remada invertida / puxada.",
        "Beba água gelada após o treino e respire 1 min.",
        "Faça mobilidade de tornozelo e joelho.",
        "Complete um treino de braços controlado.",
        "Poste um emoji do dia + intensidade 1–10.",
        "Faça 25 minutos de atividade que você gosta.",
        "Troque 1 episódio de série por 1 treino.",
        "Faça 10 minutos de corrida leve ou marcha.",
        "Prepare uma garrafa de 1L e termine até o jantar.",
        "Faça um desafio de postura: ombros baixos 1h.",
        "Complete 5 minutos de dança livre.",
        "Faça 3 séries de hip thrust / ponte.",
        "Registre 1 aprendizado técnico do treino.",
        "Faça um treino em jejum só se fizer sentido — senão, alimente-se bem.",
        "Caminhe 1.000 passos logo ao acordar.",
        "Faça 12 minutos de circuito funcional.",
        "Poste um story com texto motivacional curto.",
        "Faça 40 segundos de mountain climbers em 4 blocos.",
        "Escolha uma comunidade ATIVO e interaja 1x.",
        "Faça 8 minutos de alongamento noturno.",
        "Complete o treino mesmo ‘imperfeito’ — presença conta.",
        "Beba água e faça 20 agachamentos agora.",
        "Faça um check-in: como está sua energia (1–10)?",
        "Termine o dia com 5 minutos de mobilidade suave."
    ]

    static let sportCoverAssets = [
        "CardioCoverCorrida",
        "CardioCoverKitesurf",
        "CardioCoverSurf",
        "CardioCoverNatacao",
        "CardioCoverMountainBike",
        "CardioCoverEscalada",
        "WorkoutProgramMale",
        "FightCoverLuta"
    ]

    /// Texto jurídico exibido na tela “Li e aceito”. Localizado via `PulseTerms_*.txt`.
    static var termsBody: String { PulseLocalized.termsBody }

    /// Fallback PT embutido se os arquivos de termos não estiverem no bundle.
    static let termsBodyFallbackPT = """
    TERMOS DE USO — HEALTHFIT PULSE
    (Comunidade de conteúdo gerado por usuários)

    Versão: \(termsVersion)
    Última atualização: setembro de 2026

    Estes Termos regem o uso do recurso “HealthFit Pulse” (“Pulse”) no aplicativo HealthFit. O HealthFit em geral continua sujeito aos Termos de Uso e à Política de Privacidade do HealthFit. Em caso de conflito sobre o Pulse, prevalecem estas regras específicas, sem prejuízo dos direitos do consumidor.

    O Pulse pode ser liberado gradualmente (por versão do app ou configuração remota). Se o recurso não estiver disponível na sua conta, estas regras passam a aplicar-se assim que o Pulse for habilitado para você.

    Ao tocar em “Li e aceito”, você confirma que leu, compreendeu e concorda com estes Termos, e que declara ter 18 (dezoito) anos de idade ou mais.

    —————————————————————
    1. O QUE É O PULSE
    —————————————————————

    1.1. O Pulse é o espaço social do HealthFit para compartilhar treinos e motivação: feed de posts (foto ou vídeo curto), stories, legendas e textos, anexos de música em prévia de serviços de terceiros, comunidades temáticas, busca de pessoas, pedidos de seguir com aprovação, curtidas, comentários, denúncia, ocultação e bloqueio, ranking leve e desafios, e chat limitado a quem te segue após aprovação, conforme funcionalidades disponíveis na sua versão.

    1.2. Posts podem expirar e ser excluídos automaticamente após aproximadamente 24 (vinte e quatro) horas. Stories podem expirar após aproximadamente 12 (doze) horas. Prazos podem ser ajustados para operação e segurança.

    1.3. Vídeos no Pulse podem ter duração máxima limitada (por exemplo, cerca de 30 segundos). Trechos de música anexados podem ser limitados (por exemplo, até 15 segundos de prévia). Stories no viewer avançam automaticamente após cerca de 15 segundos.

    1.4. O Pulse NÃO constitui aconselhamento médico, nutricional, psicológico ou de treinamento personalizado. Conteúdos de outros usuários são opiniões ou experiências pessoais. Consulte profissionais habilitados antes de alterar treinos, dieta ou hábitos de saúde.

    —————————————————————
    2. ELEGIBILIDADE E IDADE
    —————————————————————

    2.1. O aplicativo HealthFit pode estar disponível a partir de 16 (dezesseis) anos, conforme suas regras gerais.

    2.2. O Pulse (UGC, comunidades, stories, posts, chat entre seguidores e interações sociais) exige 18 (dezoito) anos ou mais. Menores de 18 anos não devem acessar nem publicar conteúdo no Pulse.

    2.3. Declaração falsa de idade pode resultar em bloqueio do Pulse, remoção de conteúdo e outras medidas cabíveis.

    2.4. Você é responsável por manter a confidencialidade da sua conta e por toda atividade realizada nela no Pulse.

    —————————————————————
    3. CONTA, PERFIL E BIO
    —————————————————————

    3.1. Você pode manter uma bio curta no Pulse (limite de caracteres definido no app). Não publique dados sensíveis de terceiros, dados bancários, endereços precisos de menores ou informações que violem a lei.

    3.2. Fotos de perfil e conteúdos devem respeitar as regras da seção 5 (Conduta).

    —————————————————————
    4. LICENÇA SOBRE O SEU CONTEÚDO
    —————————————————————

    4.1. Você conserva os direitos sobre o conteúdo que publica, mas concede à HealthFit (e a seus prestadores técnicos) licença mundial, não exclusiva, gratuita, transferível e sublicenciável para hospedar, armazenar, reproduzir, exibir, adaptar formato, moderar, remover e distribuir esse conteúdo dentro do app e dos canais necessários à operação, segurança e melhoria do Pulse.

    4.2. Você declara ter direitos e autorizações necessários sobre fotos, vídeos, textos, músicas (quando aplicável o uso de prévia) e demais elementos publicados, e que a publicação não viola direitos de terceiros (imagem, voz, autoria, marca, etc.).

    4.3. Ao remover conteúdo ou quando ele expirar, cópias residuais podem permanecer em backups ou caches por tempo limitado, conforme operação técnica razoável.

    —————————————————————
    5. CONDUTA E CONTEÚDO PROIBIDO
    —————————————————————

    É proibido publicar, compartilhar, solicitar ou promover, entre outros:

    a) nudez, pornografia, exploração sexual ou conteúdo sexual envolvendo menores (tolerância zero);
    b) ódio, discriminação, assédio, ameaças, bullying ou humilhação;
    c) violência gráfica gratuita, incentivo a automutilação ou práticas perigosas extremas;
    d) drogas ilícitas, tráfico, armas ilegais ou atividades criminosas;
    e) spam, fraude, phishing, engenharia social ou esquemas financeiros enganosos;
    f) doxxing (exposição de dados pessoais de terceiros sem base legal);
    g) impersonação, contas falsas ou manipulação de engajamento;
    h) conteúdo que viole propriedade intelectual ou direitos de personalidade;
    i) material médico enganoso apresentado como diagnóstico ou tratamento garantido.

    A HealthFit pode remover conteúdo, restringir recursos, suspender o Pulse na conta ou adotar outras medidas, com ou sem aviso prévio, especialmente em risco a pessoas ou à integridade da comunidade.

    —————————————————————
    6. MÚSICA E SERVIÇOS DE TERCEIROS
    —————————————————————

    6.1. Busca e prévia de músicas podem usar APIs ou serviços de terceiros (por exemplo Deezer e, quando disponível, outros provedores), sujeitos aos termos e políticas desses provedores.

    6.2. A HealthFit não vende a faixa completa nem substitui assinaturas desses serviços. O uso típico no Pulse é de prévia curta para acompanhar story/post, nos limites técnicos e contratuais disponíveis.

    6.3. Indisponibilidade, mudança de API, ausência de prévia ou exigência de login/permissão do provedor são de responsabilidade do serviço terceiro. A HealthFit não garante continuidade de qualquer catálogo musical.

    6.4. Você não deve usar o Pulse para redistribuir músicas de forma ilícita ou fora do escopo de prévia autorizada.

    —————————————————————
    7. COMUNIDADES, SEGUIR E CHAT
    —————————————————————

    7.1. Comunidades temáticas e modalidades de cardio ativas podem filtrar o feed e aparecer nos posts. Participar é opcional e pode ser revogado no app.

    7.2. Pedidos de seguir seguem modelo de aprovação. Chat da comunidade, quando disponível, restringe-se a quem te segue após aprovação.

    7.3. Bloqueio, ocultação e denúncia são ferramentas de segurança da comunidade. Denúncias podem ser analisadas de forma manual e/ou automatizada.

    —————————————————————
    8. SAÚDE E RISCO ESPORTIVO
    —————————————————————

    8.1. Exercícios físicos envolvem risco de lesão. Você participa por sua conta e risco.

    8.2. Não publique desafios que incentivem excesso perigoso, desidratação extrema, distúrbios alimentares ou práticas contraindicadas.

    8.3. Em emergência médica, procure serviços de saúde locais — o Pulse não é canal de emergência.

    —————————————————————
    9. PRIVACIDADE E DADOS (LGPD)
    —————————————————————

    9.1. O tratamento de dados pessoais no HealthFit observa a Política de Privacidade do app e a Lei Geral de Proteção de Dados (LGPD), quando aplicável.

    9.2. No Pulse, dados de posts, stories, bios, relações de seguir e preferências de comunidade podem ser processados para exibir o recurso, moderar abuso, segurança e melhoria do produto.

    9.3. Evite publicar dados sensíveis (saúde detalhada de terceiros, documentos, dados financeiros). Conteúdo publicado por você pode ser visível a outros usuários do Pulse conforme as configurações e o desenho do recurso.

    9.4. Pedidos de titular (acesso, correção, eliminação etc.) devem seguir os canais indicados na Política de Privacidade do HealthFit (incluindo o e-mail de suporte do app).

    —————————————————————
    10. MODERAÇÃO E SANÇÕES
    —————————————————————

    10.1. Podemos, a nosso critério: remover conteúdo; limitar visibilidade; restringir comunidades, stories ou chat; encerrar o acesso ao Pulse; e preservar registros necessários a investigações de abuso ou cumprimento legal.

    10.2. A ausência de ação imediata sobre determinado conteúdo não significa autorização ou renúncia de direitos.

    —————————————————————
    11. DISPONIBILIDADE
    —————————————————————

    11.1. Podemos modificar, suspender ou descontinuar funcionalidades do Pulse para manutenção, evolução do produto, segurança ou exigências legais, na medida permitida pela lei.

    —————————————————————
    12. ISENÇÕES E LIMITAÇÃO DE RESPONSABILIDADE
    —————————————————————

    12.1. Na máxima extensão permitida pela legislação aplicável, a HealthFit não se responsabiliza por: (a) conteúdo publicado por usuários; (b) condutas de terceiros; (c) decisões de treino, dieta ou saúde baseadas em posts; (d) indisponibilidade temporária ou perda de dados em falhas técnicas; (e) falhas de serviços de música ou demais terceiros.

    12.2. Nada nestes Termos exclui responsabilidade que não possa ser limitada por lei (por exemplo, hipóteses legais de dolo ou direitos do consumidor inafastáveis, quando aplicáveis).

    —————————————————————
    13. ALTERAÇÕES
    —————————————————————

    13.1. Podemos atualizar estes Termos. A versão vigente é identificada por “Versão” no topo. Mudanças relevantes podem exigir novo aceite (“Li e aceito”) com nova versão.

    —————————————————————
    14. CONTATO
    —————————————————————

    Dúvidas sobre o Pulse ou estes Termos: utilize os canais de suporte/contato indicados no aplicativo HealthFit (Perfil → Feedback) ou na Política de Privacidade.

    —————————————————————
    15. ACEITE
    —————————————————————

    Ao marcar a declaração de idade e tocar em “Li e aceito”, você:

    (i) declara ter 18 anos ou mais;
    (ii) confirma a leitura integral destes Termos;
    (iii) concorda com as regras de conduta, licença de conteúdo e uso de prévias musicais de terceiros;
    (iv) reconhece que o Pulse não substitui orientação profissional de saúde.
    """
}

/// Comunidades temáticas + modalidades de cardio (cada modalidade também é comunidade).
enum PulseCommunity: Hashable, Identifiable, Codable {
    case musculacao
    case cardio
    case kite
    case nutricao
    case cardioModality(String)

    var id: String { storageKey }

    var storageKey: String {
        switch self {
        case .musculacao: return "musculacao"
        case .cardio: return "cardio"
        case .kite: return "kite"
        case .nutricao: return "nutricao"
        case .cardioModality(let name): return "cardio.\(name)"
        }
    }

    init?(storageKey: String) {
        switch storageKey {
        case "musculacao": self = .musculacao
        case "cardio": self = .cardio
        case "kite": self = .kite
        case "nutricao": self = .nutricao
        default:
            guard storageKey.hasPrefix("cardio.") else { return nil }
            let name = String(storageKey.dropFirst("cardio.".count))
            guard !name.isEmpty else { return nil }
            self = .cardioModality(name)
        }
    }

    /// Compatível com persistência antiga (`rawValue`).
    init?(rawValue: String) {
        self.init(storageKey: rawValue)
    }

    var rawValue: String { storageKey }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let key = try container.decode(String.self)
        guard let value = PulseCommunity(storageKey: key) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Comunidade Pulse desconhecida: \(key)"
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageKey)
    }

    static var thematicCases: [PulseCommunity] {
        [.musculacao, .cardio, .kite, .nutricao]
    }

    static var cardioModalityCases: [PulseCommunity] {
        CardioExercise.catalog.map { .cardioModality($0.name) }
    }

    /// Temáticas + todas as modalidades de cardio.
    static var allCases: [PulseCommunity] {
        thematicCases + cardioModalityCases
    }

    var isCardioModality: Bool {
        if case .cardioModality = self { return true }
        return false
    }

    var cardioExercise: CardioExercise? {
        guard case .cardioModality(let name) = self else { return nil }
        return CardioExercise.catalog.first { $0.name == name }
    }

    var title: String {
        switch self {
        case .musculacao: return L10n.Pulse.communityMusculacao
        case .cardio: return L10n.Pulse.communityCardio
        case .kite: return L10n.Pulse.communityKite
        case .nutricao: return L10n.Pulse.communityNutricao
        case .cardioModality(let name): return name
        }
    }

    var systemImage: String {
        switch self {
        case .musculacao: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .kite: return "wind"
        case .nutricao: return "leaf.fill"
        case .cardioModality:
            return cardioExercise?.icon ?? "figure.run"
        }
    }

    var coverAsset: String {
        switch self {
        case .musculacao: return "WorkoutProgramMale"
        case .cardio: return "CardioCoverCorrida"
        case .kite: return "CardioCoverKitesurf"
        case .nutricao: return "CardioCoverCaminhada"
        case .cardioModality:
            return cardioExercise?.coverImageName ?? "CardioCoverCorrida"
        }
    }

    /// Resolve título de treino/modalidade para a comunidade Pulse correspondente.
    static func fromWorkoutTitle(_ title: String) -> PulseCommunity {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = CardioExercise.catalog.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return .cardioModality(exact.name)
        }
        let lower = trimmed.lowercased()
        if let fuzzy = CardioExercise.catalog.first(where: { lower.contains($0.name.lowercased()) }) {
            return .cardioModality(fuzzy.name)
        }
        if lower.contains("kite") { return .kite }
        if lower.contains("cardio") { return .cardio }
        if lower.contains("nutri") { return .nutricao }
        return .musculacao
    }
}

enum PulseMediaKind: String, Codable, Hashable {
    case photo
    case video
    case workoutCard
}

enum PulseQuickReaction: String, Codable, CaseIterable, Hashable {
    case fire = "🔥"
    case strength = "💪"
    case clap = "👏"
}

struct PulseReactionEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: String
    var userName: String
    /// `"heart"` ou `PulseQuickReaction.rawValue`
    var kind: String
    var createdAt: Date
    var avatarFileName: String?

    init(
        id: UUID = UUID(),
        userId: String,
        userName: String,
        kind: String,
        createdAt: Date = .now,
        avatarFileName: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.kind = kind
        self.createdAt = createdAt
        self.avatarFileName = avatarFileName
    }

    var isHeart: Bool { kind == "heart" }
    var emojiLabel: String { isHeart ? "💚" : kind }
}

enum PulseFollowStatus: String, Codable, Hashable {
    case none
    case requested
    case following
    case incoming
}

struct PulseComment: Identifiable, Codable, Hashable {
    var id: UUID
    var authorId: String
    var authorName: String
    var text: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        authorId: String,
        authorName: String,
        text: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.text = text
        self.createdAt = createdAt
    }
}

struct PulseWorkoutMeta: Codable, Hashable {
    var modality: String?
    var durationSeconds: Int?
    var intensity: Int?
    var duoTeamName: String?

    var intensityLabel: String? {
        guard let intensity else { return nil }
        return "Intensidade \(intensity)/10"
    }

    var durationLabel: String? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        let m = durationSeconds / 60
        return m > 0 ? "\(m) min" : "\(durationSeconds)s"
    }
}

struct PulsePost: Identifiable, Codable, Hashable {
    var id: UUID
    var authorId: String
    var authorName: String
    var authorCountryCode: String
    var caption: String
    var mediaKind: PulseMediaKind
    var mediaFileName: String?
    /// URL remota (Firebase Storage) quando o post veio do sync em nuvem.
    var remoteMediaURL: String?
    var systemImagePlaceholder: String?
    var community: PulseCommunity
    var workoutMeta: PulseWorkoutMeta?
    var music: PulseMusicAttachment?
    var createdAt: Date
    var expiresAt: Date
    var reactions: [PulseReactionEvent]
    var comments: [PulseComment]
    var isHidden: Bool
    var reportCount: Int

    var isActive: Bool { Date() < expiresAt }

    var heartCount: Int { reactions.filter(\.isHeart).count }

    var quickReactions: [String: Int] {
        var counts: [String: Int] = [:]
        for reaction in reactions where !reaction.isHeart {
            counts[reaction.kind, default: 0] += 1
        }
        return counts
    }

    init(
        id: UUID = UUID(),
        authorId: String,
        authorName: String,
        authorCountryCode: String = "BR",
        caption: String,
        mediaKind: PulseMediaKind,
        mediaFileName: String? = nil,
        remoteMediaURL: String? = nil,
        systemImagePlaceholder: String? = nil,
        community: PulseCommunity = .musculacao,
        workoutMeta: PulseWorkoutMeta? = nil,
        music: PulseMusicAttachment? = nil,
        createdAt: Date = .now,
        expiresAt: Date? = nil,
        reactions: [PulseReactionEvent] = [],
        comments: [PulseComment] = [],
        isHidden: Bool = false,
        reportCount: Int = 0,
        heartCount: Int = 0,
        quickReactions: [String: Int] = [:]
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorCountryCode = authorCountryCode
        self.caption = caption
        self.mediaKind = mediaKind
        self.mediaFileName = mediaFileName
        self.remoteMediaURL = remoteMediaURL
        self.systemImagePlaceholder = systemImagePlaceholder
        self.community = community
        self.workoutMeta = workoutMeta
        self.music = music
        self.createdAt = createdAt
        self.expiresAt = expiresAt ?? createdAt.addingTimeInterval(PulseExperimental.postLifetime)
        self.comments = comments
        self.isHidden = isHidden
        self.reportCount = reportCount

        if reactions.isEmpty, heartCount > 0 || !quickReactions.isEmpty {
            var seeded: [PulseReactionEvent] = []
            for i in 0..<heartCount {
                seeded.append(
                    PulseReactionEvent(
                        userId: "legacy-heart-\(i)",
                        userName: "Pulse",
                        kind: "heart",
                        createdAt: createdAt
                    )
                )
            }
            for (kind, count) in quickReactions {
                for i in 0..<count {
                    seeded.append(
                        PulseReactionEvent(
                            userId: "legacy-\(kind)-\(i)",
                            userName: "Pulse",
                            kind: kind,
                            createdAt: createdAt
                        )
                    )
                }
            }
            self.reactions = seeded
        } else {
            self.reactions = reactions
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        authorCountryCode = try container.decodeIfPresent(String.self, forKey: .authorCountryCode) ?? "BR"
        caption = try container.decode(String.self, forKey: .caption)
        mediaKind = try container.decode(PulseMediaKind.self, forKey: .mediaKind)
        mediaFileName = try container.decodeIfPresent(String.self, forKey: .mediaFileName)
        remoteMediaURL = try container.decodeIfPresent(String.self, forKey: .remoteMediaURL)
        systemImagePlaceholder = try container.decodeIfPresent(String.self, forKey: .systemImagePlaceholder)
        community = try container.decodeIfPresent(PulseCommunity.self, forKey: .community) ?? .musculacao
        workoutMeta = try container.decodeIfPresent(PulseWorkoutMeta.self, forKey: .workoutMeta)
        music = try container.decodeIfPresent(PulseMusicAttachment.self, forKey: .music)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
            ?? createdAt.addingTimeInterval(PulseExperimental.postLifetime)
        comments = try container.decodeIfPresent([PulseComment].self, forKey: .comments) ?? []
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        reportCount = try container.decodeIfPresent(Int.self, forKey: .reportCount) ?? 0

        if let decoded = try container.decodeIfPresent([PulseReactionEvent].self, forKey: .reactions), !decoded.isEmpty {
            reactions = decoded
        } else {
            let legacyHearts = try container.decodeIfPresent(Int.self, forKey: .heartCount) ?? 0
            let legacyQuick = try container.decodeIfPresent([String: Int].self, forKey: .quickReactions) ?? [:]
            var seeded: [PulseReactionEvent] = []
            for i in 0..<legacyHearts {
                seeded.append(PulseReactionEvent(userId: "legacy-heart-\(i)", userName: "Pulse", kind: "heart", createdAt: createdAt))
            }
            for (kind, count) in legacyQuick {
                for i in 0..<count {
                    seeded.append(PulseReactionEvent(userId: "legacy-\(kind)-\(i)", userName: "Pulse", kind: kind, createdAt: createdAt))
                }
            }
            reactions = seeded
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(authorCountryCode, forKey: .authorCountryCode)
        try container.encode(caption, forKey: .caption)
        try container.encode(mediaKind, forKey: .mediaKind)
        try container.encodeIfPresent(mediaFileName, forKey: .mediaFileName)
        try container.encodeIfPresent(remoteMediaURL, forKey: .remoteMediaURL)
        try container.encodeIfPresent(systemImagePlaceholder, forKey: .systemImagePlaceholder)
        try container.encode(community, forKey: .community)
        try container.encodeIfPresent(workoutMeta, forKey: .workoutMeta)
        try container.encodeIfPresent(music, forKey: .music)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encode(reactions, forKey: .reactions)
        try container.encode(heartCount, forKey: .heartCount)
        try container.encode(quickReactions, forKey: .quickReactions)
        try container.encode(comments, forKey: .comments)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encode(reportCount, forKey: .reportCount)
    }

    private enum CodingKeys: String, CodingKey {
        case id, authorId, authorName, authorCountryCode, caption, mediaKind, mediaFileName, remoteMediaURL
        case systemImagePlaceholder, community, workoutMeta, music, createdAt, expiresAt
        case reactions, heartCount, quickReactions, comments, isHidden, reportCount
    }

    var engagementScore: Int {
        reactions.count + comments.count * 2
    }
}

struct PulseMusicAttachment: Codable, Hashable, Identifiable {
    var id: String { "\(provider.rawValue)-\(trackId)" }
    var provider: PulseMusicProvider
    var trackId: String
    var title: String
    var artistName: String
    var artworkURL: String?
    var previewURL: String?
    var externalURL: String?
    /// Início do trecho escolhido (segundos no preview).
    var clipStartSeconds: Double
    /// Duração do trecho (máx. `PulseExperimental.maxMusicClipSeconds`).
    var clipDurationSeconds: Double

    var providerLabel: String { provider.title }

    var clipEndSeconds: Double { clipStartSeconds + clipDurationSeconds }

    var clipRangeLabel: String {
        "\(Self.formatTime(clipStartSeconds)) – \(Self.formatTime(clipEndSeconds))"
    }

    init(
        provider: PulseMusicProvider,
        trackId: String,
        title: String,
        artistName: String,
        artworkURL: String? = nil,
        previewURL: String? = nil,
        externalURL: String? = nil,
        clipStartSeconds: Double = 0,
        clipDurationSeconds: Double = PulseExperimental.maxMusicClipSeconds
    ) {
        self.provider = provider
        self.trackId = trackId
        self.title = title
        self.artistName = artistName
        self.artworkURL = artworkURL
        self.previewURL = previewURL
        self.externalURL = externalURL
        self.clipStartSeconds = max(0, clipStartSeconds)
        self.clipDurationSeconds = min(
            max(clipDurationSeconds, PulseExperimental.minMusicClipSeconds),
            PulseExperimental.maxMusicClipSeconds
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(PulseMusicProvider.self, forKey: .provider)
        trackId = try container.decode(String.self, forKey: .trackId)
        title = try container.decode(String.self, forKey: .title)
        artistName = try container.decode(String.self, forKey: .artistName)
        artworkURL = try container.decodeIfPresent(String.self, forKey: .artworkURL)
        previewURL = try container.decodeIfPresent(String.self, forKey: .previewURL)
        externalURL = try container.decodeIfPresent(String.self, forKey: .externalURL)
        clipStartSeconds = max(0, try container.decodeIfPresent(Double.self, forKey: .clipStartSeconds) ?? 0)
        let decodedDuration = try container.decodeIfPresent(Double.self, forKey: .clipDurationSeconds)
            ?? PulseExperimental.maxMusicClipSeconds
        clipDurationSeconds = min(
            max(decodedDuration, PulseExperimental.minMusicClipSeconds),
            PulseExperimental.maxMusicClipSeconds
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        try container.encode(trackId, forKey: .trackId)
        try container.encode(title, forKey: .title)
        try container.encode(artistName, forKey: .artistName)
        try container.encodeIfPresent(artworkURL, forKey: .artworkURL)
        try container.encodeIfPresent(previewURL, forKey: .previewURL)
        try container.encodeIfPresent(externalURL, forKey: .externalURL)
        try container.encode(clipStartSeconds, forKey: .clipStartSeconds)
        try container.encode(clipDurationSeconds, forKey: .clipDurationSeconds)
    }

    private enum CodingKeys: String, CodingKey {
        case provider, trackId, title, artistName, artworkURL, previewURL, externalURL
        case clipStartSeconds, clipDurationSeconds
    }

    mutating func normalizeClip(againstPreviewDuration previewDuration: Double) {
        let available = max(previewDuration, PulseExperimental.minMusicClipSeconds)
        let maxDuration = min(PulseExperimental.maxMusicClipSeconds, available)
        clipDurationSeconds = min(max(clipDurationSeconds, PulseExperimental.minMusicClipSeconds), maxDuration)
        let maxStart = max(0, available - clipDurationSeconds)
        clipStartSeconds = min(max(0, clipStartSeconds), maxStart)
    }

    static func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

enum PulseMusicProvider: String, Codable, CaseIterable, Identifiable, Hashable {
    case deezer
    case appleMusic
    case spotify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deezer: return "Deezer"
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        }
    }

    var systemImage: String {
        switch self {
        case .deezer: return "waveform"
        case .appleMusic: return "music.note"
        case .spotify: return "headphones"
        }
    }

    /// Providers no picker. Apple Music (MusicKit) e Spotify ficam para v2 / Labs.
    static var selectableCases: [PulseMusicProvider] { [.deezer] }
}

struct PulseStory: Identifiable, Codable, Hashable {
    var id: UUID
    var authorId: String
    var authorName: String
    var mediaFileName: String?
    /// URL remota (Firebase Storage) quando o story veio do sync em nuvem.
    var remoteMediaURL: String?
    var systemImagePlaceholder: String?
    var createdAt: Date
    var expiresAt: Date
    var isViewed: Bool
    var reactions: [PulseReactionEvent]
    var music: PulseMusicAttachment?
    var textOverlays: [PulseStoryTextOverlay]

    var isActive: Bool { Date() < expiresAt }

    init(
        id: UUID = UUID(),
        authorId: String,
        authorName: String,
        mediaFileName: String? = nil,
        remoteMediaURL: String? = nil,
        systemImagePlaceholder: String? = nil,
        createdAt: Date = .now,
        expiresAt: Date? = nil,
        isViewed: Bool = false,
        reactions: [PulseReactionEvent] = [],
        music: PulseMusicAttachment? = nil,
        textOverlays: [PulseStoryTextOverlay] = []
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.mediaFileName = mediaFileName
        self.remoteMediaURL = remoteMediaURL
        self.systemImagePlaceholder = systemImagePlaceholder
        self.createdAt = createdAt
        self.expiresAt = expiresAt ?? createdAt.addingTimeInterval(PulseExperimental.storyLifetime)
        self.isViewed = isViewed
        self.reactions = reactions
        self.music = music
        self.textOverlays = textOverlays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        mediaFileName = try container.decodeIfPresent(String.self, forKey: .mediaFileName)
        remoteMediaURL = try container.decodeIfPresent(String.self, forKey: .remoteMediaURL)
        systemImagePlaceholder = try container.decodeIfPresent(String.self, forKey: .systemImagePlaceholder)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
            ?? createdAt.addingTimeInterval(PulseExperimental.storyLifetime)
        isViewed = try container.decodeIfPresent(Bool.self, forKey: .isViewed) ?? false
        reactions = try container.decodeIfPresent([PulseReactionEvent].self, forKey: .reactions) ?? []
        music = try container.decodeIfPresent(PulseMusicAttachment.self, forKey: .music)
        textOverlays = try container.decodeIfPresent([PulseStoryTextOverlay].self, forKey: .textOverlays) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(authorName, forKey: .authorName)
        try container.encodeIfPresent(mediaFileName, forKey: .mediaFileName)
        try container.encodeIfPresent(remoteMediaURL, forKey: .remoteMediaURL)
        try container.encodeIfPresent(systemImagePlaceholder, forKey: .systemImagePlaceholder)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encode(isViewed, forKey: .isViewed)
        try container.encode(reactions, forKey: .reactions)
        try container.encodeIfPresent(music, forKey: .music)
        try container.encode(textOverlays, forKey: .textOverlays)
    }

    private enum CodingKeys: String, CodingKey {
        case id, authorId, authorName, mediaFileName, remoteMediaURL, systemImagePlaceholder
        case createdAt, expiresAt, isViewed, reactions, music, textOverlays
    }
}

/// Denúncia remota (moderação / listagem).
struct PulseCloudReport: Identifiable, Hashable {
    var id: String
    var postId: String
    var reporterId: String
    var reason: String
    var createdAt: Date
}

struct PulsePerson: Identifiable, Codable, Hashable {
    var id: String
    var displayName: String
    var emailHint: String
    var countryCode: String
    var state: String
    var city: String
    var bio: String
    var communityFocus: PulseCommunity
    var notifyOnPosts: Bool

    var flagEmoji: String { CountryOption.flagEmoji(for: countryCode) }
    var countryName: String { CountryOption.option(for: countryCode)?.name ?? countryCode }

    /// Handle para @menções (sem acentos/espaços), ex.: "Coach HealthFit" → "CoachHealthFit".
    var mentionHandle: String {
        let folded = displayName
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
        let cleaned = folded.filter { $0.isLetter || $0.isNumber }
        return cleaned.isEmpty ? String(id.prefix(12)) : cleaned
    }

    /// Ex.: "São Paulo, SP"
    var regionLabel: String {
        let parts = [city, state].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    init(
        id: String,
        displayName: String,
        emailHint: String,
        countryCode: String,
        state: String,
        city: String,
        bio: String,
        communityFocus: PulseCommunity,
        notifyOnPosts: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.emailHint = emailHint
        self.countryCode = countryCode
        self.state = state
        self.city = city
        self.bio = String(bio.prefix(PulseExperimental.maxBioCharacters))
        self.communityFocus = communityFocus
        self.notifyOnPosts = notifyOnPosts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        emailHint = try container.decode(String.self, forKey: .emailHint)
        countryCode = try container.decode(String.self, forKey: .countryCode)
        bio = String((try container.decode(String.self, forKey: .bio)).prefix(PulseExperimental.maxBioCharacters))
        communityFocus = try container.decode(PulseCommunity.self, forKey: .communityFocus)
        notifyOnPosts = try container.decodeIfPresent(Bool.self, forKey: .notifyOnPosts) ?? true

        let decodedState = try container.decodeIfPresent(String.self, forKey: .state)
        let decodedCity = try container.decodeIfPresent(String.self, forKey: .city)
        if let decodedState, let decodedCity {
            state = decodedState
            city = decodedCity
        } else if let legacy = try container.decodeIfPresent(String.self, forKey: .region) {
            let parts = legacy.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count >= 2 {
                city = parts[0]
                state = parts[1]
            } else {
                state = legacy
                city = ""
            }
        } else {
            state = decodedState ?? ""
            city = decodedCity ?? ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(emailHint, forKey: .emailHint)
        try container.encode(countryCode, forKey: .countryCode)
        try container.encode(state, forKey: .state)
        try container.encode(city, forKey: .city)
        try container.encode(regionLabel, forKey: .region)
        try container.encode(bio, forKey: .bio)
        try container.encode(communityFocus, forKey: .communityFocus)
        try container.encode(notifyOnPosts, forKey: .notifyOnPosts)
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, emailHint, countryCode, state, city, region, bio, communityFocus, notifyOnPosts
    }
}

struct PulseFollowRelation: Identifiable, Codable, Hashable {
    var id: UUID
    var fromUserId: String
    var toUserId: String
    var status: PulseFollowStatus
    var createdAt: Date
    var notifyPosts: Bool

    init(
        id: UUID = UUID(),
        fromUserId: String,
        toUserId: String,
        status: PulseFollowStatus,
        createdAt: Date = .now,
        notifyPosts: Bool = true
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.status = status
        self.createdAt = createdAt
        self.notifyPosts = notifyPosts
    }
}

struct PulseSocialNotification: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        createdAt: Date = .now,
        isRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.isRead = isRead
    }
}

struct PulseChatMessage: Identifiable, Codable, Hashable {
    var id: UUID
    var threadId: String
    var senderId: String
    var senderName: String
    var text: String
    var createdAt: Date
    var community: PulseCommunity

    init(
        id: UUID = UUID(),
        threadId: String,
        senderId: String,
        senderName: String,
        text: String,
        createdAt: Date = .now,
        community: PulseCommunity = .cardio
    ) {
        self.id = id
        self.threadId = threadId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.createdAt = createdAt
        self.community = community
    }
}

enum PulseChatThread {
    static func id(between a: String, and b: String) -> String {
        [a, b].sorted().joined(separator: "__")
    }
}

enum PulseStoryFontStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case modern
    case rounded
    case serif
    case mono
    case poster

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modern: return "Modern"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .mono: return "Mono"
        case .poster: return "Poster"
        }
    }
}

struct PulseStoryTextOverlay: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var fontStyle: PulseStoryFontStyle
    var isBold: Bool
    var colorHex: String
    /// Posição relativa no story (0...1).
    var x: Double
    var y: Double
    var scale: Double

    init(
        id: UUID = UUID(),
        text: String = "",
        fontStyle: PulseStoryFontStyle = .modern,
        isBold: Bool = true,
        colorHex: String = "#FFFFFF",
        x: Double = 0.5,
        y: Double = 0.45,
        scale: Double = 1
    ) {
        self.id = id
        self.text = text
        self.fontStyle = fontStyle
        self.isBold = isBold
        self.colorHex = colorHex
        self.x = min(max(x, 0.08), 0.92)
        self.y = min(max(y, 0.08), 0.92)
        self.scale = min(max(scale, 0.35), 2.2)
    }
}

/// RNG determinístico simples para agenda anual de desafios.
struct PulseSeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
