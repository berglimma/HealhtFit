import Foundation
import SwiftUI

enum MeditationDuration: Int, CaseIterable, Identifiable, Hashable {
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20

    var id: Int { rawValue }

    var label: String { "\(rawValue) min" }

    var seconds: Int { rawValue * 60 }
}

struct MeditationTopic: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var description: String
    var icon: String
    var colorName: String
    var prompts: [String]

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        icon: String,
        colorName: String = "purple",
        prompts: [String]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.colorName = colorName
        self.prompts = prompts
    }

    var color: Color {
        switch colorName {
        case "blue": return .blue
        case "green": return AppTheme.accent
        case "orange": return AppTheme.accentSecondary
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        default: return .purple
        }
    }

    static let catalog: [MeditationTopic] = [
        MeditationTopic(
            name: "Respiração Consciente",
            description: "Acalme a mente focando no ritmo da respiração",
            icon: "wind",
            colorName: "blue",
            prompts: [
                "Sente-se confortavelmente e feche os olhos.",
                "Inspire lentamente pelo nariz contando até quatro.",
                "Segure o ar por um instante, sem tensão.",
                "Expire suavemente pela boca contando até seis.",
                "Observe o ar entrando e saindo do corpo.",
                "Quando a mente divagar, volte gentilmente à respiração.",
                "Sinta o peito e o abdômen se expandirem a cada inspiração.",
                "Permita que cada expiração leve embora o estresse.",
                "Mantenha o ritmo natural, sem forçar.",
                "Finalize agradecendo por este momento de pausa."
            ]
        ),
        MeditationTopic(
            name: "Relaxamento Corporal",
            description: "Libere tensões com varredura corporal progressiva",
            icon: "figure.mind.and.body",
            colorName: "teal",
            prompts: [
                "Deite-se ou sente-se com a coluna ereta.",
                "Traga atenção aos dedos dos pés. Relaxe-os completamente.",
                "Suba pela pernas, soltando qualquer tensão muscular.",
                "Relaxe quadris, abdômen e costas.",
                "Solte os ombros — deixe-os caírem naturalmente.",
                "Relaxe braços, mãos e cada dedo.",
                "Suavize o rosto: mandíbula, testa e olhos.",
                "Sinta o corpo mais leve a cada expiração.",
                "Permaneça em silêncio observando as sensações.",
                "Quando terminar, mova os dedos e abra os olhos devagar."
            ]
        ),
        MeditationTopic(
            name: "Gratidão",
            description: "Cultive sentimentos positivos e bem-estar mental",
            icon: "heart.fill",
            colorName: "pink",
            prompts: [
                "Respire fundo e traga à mente algo pelo qual é grato.",
                "Pode ser uma pessoa, uma conquista ou um momento simples.",
                "Sinta a gratidão se expandir no peito.",
                "Lembre-se de algo que seu corpo fez por você hoje.",
                "Agradeça pela saúde, mesmo que em pequenas vitórias.",
                "Pense em alguém que te apoia. Envie boa energia a essa pessoa.",
                "Reconheça um desafio que te tornou mais forte.",
                "Agradeça por este momento de cuidado consigo mesmo.",
                "Deixe o sentimento de gratidão preencher todo o corpo.",
                "Carregue essa sensação com você pelo resto do dia."
            ]
        ),
        MeditationTopic(
            name: "Foco e Clareza",
            description: "Prepare a mente para treinos e decisões importantes",
            icon: "brain.head.profile",
            colorName: "indigo",
            prompts: [
                "Sente-se em postura alerta, mas relaxada.",
                "Inspire profundamente. Você está presente aqui e agora.",
                "Deixe de lado distrações e compromissos futuros.",
                "Visualize seu objetivo principal com clareza.",
                "Imagine-se executando com confiança e disciplina.",
                "Cada respiração traz mais foco e determinação.",
                "Elimine o ruído mental. Apenas você e o momento.",
                "Sinta sua mente ficando nítida como água calma.",
                "Afirme mentalmente: eu tenho foco, eu tenho força.",
                "Abra os olhos pronto para agir com intenção."
            ]
        ),
        MeditationTopic(
            name: "Redução de Ansiedade",
            description: "Ancore-se no presente e acalme pensamentos acelerados",
            icon: "leaf.fill",
            colorName: "green",
            prompts: [
                "Perceba onde você está. Nomeie mentalmente 3 coisas que vê.",
                "Ouça os sons ao redor sem julgá-los.",
                "Sinta o contato do corpo com a cadeira ou o chão.",
                "Inspire por 4 segundos. Segure por 2. Expire por 6.",
                "Repita: eu estou seguro neste momento.",
                "Os pensamentos são nuvens — deixe-os passar.",
                "Não precisa controlar tudo. Apenas respire.",
                "Com cada expiração, solte um pouco mais de tensão.",
                "Sua mente pode acalmar. Dê tempo a ela.",
                "Retorne ao dia com mais leveza e equilíbrio."
            ]
        ),
        MeditationTopic(
            name: "Sono e Descanso",
            description: "Prepare corpo e mente para uma noite reparadora",
            icon: "moon.stars.fill",
            colorName: "purple",
            prompts: [
                "Deite-se confortavelmente e feche os olhos.",
                "Diminua a respiração. Inspire e expire mais devagar.",
                "Relaxe a testa, as pálpebras e a mandíbula.",
                "Imagine uma luz suave envolvendo todo o corpo.",
                "Conte lentamente de 10 até 1 a cada expiração.",
                "Deixe os pensamentos do dia se afastarem.",
                "Seu corpo sabe descansar. Confie nele.",
                "Sinta a cama te sustentando completamente.",
                "Cada músculo está pesado, quente e relaxado.",
                "Permita-se adormecer em paz."
            ]
        ),
        MeditationTopic(
            name: "Recuperação Pós-Treino",
            description: "Acelere a recuperação muscular e mental após o exercício",
            icon: "figure.cooldown",
            colorName: "orange",
            prompts: [
                "Após o esforço, sente-se e respire profundamente.",
                "Agradeça ao corpo pelo trabalho realizado.",
                "Inspire oxigênio. Expire o ácido lático e a fadiga.",
                "Leve atenção aos músculos que trabalharam hoje.",
                "Envie relaxamento para cada grupo muscular.",
                "Seu corpo está se reconstruindo agora. Descanse.",
                "A hidratação e o sono completarão a recuperação.",
                "Respire calmamente. O coração volta ao ritmo de repouso.",
                "Cada expiração acelera a regeneração celular.",
                "Você treinou bem. Agora é hora de recuperar."
            ]
        )
    ]
}

struct MeditationWorkoutConfig: Hashable {
    let topic: MeditationTopic
    let duration: MeditationDuration

    var title: String { "Meditação — \(topic.name)" }
    var targetDurationSeconds: Int { duration.seconds }
}
