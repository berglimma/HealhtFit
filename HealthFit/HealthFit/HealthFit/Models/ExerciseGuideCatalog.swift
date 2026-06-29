import Foundation
import SwiftUI

enum ExerciseGuideCatalog {
    private static let guides: [String: [String]] = [
        "Supino Reto": [
            "Deite no banco com os pés firmes no chão e glúteos apoiados.",
            "Segure a barra na largura dos ombros, retraia as escápulas e desça até o peito médio.",
            "Empurre a barra para cima sem perder a curvatura natural das costas.",
            "Inspire na descida e expire na subida, mantendo os cotovelos em ângulo de ~45°."
        ],
        "Supino Inclinado": [
            "Ajuste o banco entre 30° e 45° e posicione os olhos sob a barra.",
            "Desça a carga controlando até a linha superior do peito.",
            "Empurre focando na contração da porção clavicular do peitoral.",
            "Evite arquear demais a lombar e não bater a barra no suporte."
        ],
        "Supino Declinado": [
            "Prenda bem os pés e deite com segurança no banco declinado.",
            "Desça a barra até a porção inferior do peitoral com controle.",
            "Empurre em linha reta, contraindo o peito na subida.",
            "Mantenha os punhos alinhados com os antebraços durante todo o movimento."
        ],
        "Crucifixo Reto": [
            "Deite no banco reto com halteres acima do peito, cotovelos levemente flexionados.",
            "Abra os braços em arco amplo até sentir alongamento no peitoral.",
            "Retorne contraindo o peito, sem bater os halteres no topo.",
            "Mantenha o movimento controlado e evite travar os cotovelos."
        ],
        "Crucifixo Inclinado": [
            "No banco inclinado, inicie com halteres alinhados acima do peito.",
            "Abra os braços mantendo cotovelos semiflexionados.",
            "Feche o movimento contraindo a parte superior do peitoral.",
            "Não deixe os ombros subirem em direção às orelhas."
        ],
        "Crossover": [
            "Posicione as polias na altura dos ombros ou acima.",
            "Dê um passo à frente, tronco levemente inclinado e core ativado.",
            "Cruze as mãos à frente do corpo em movimento de abraço.",
            "Retorne controlando a fase excêntrica sem deixar o peso puxar bruscamente."
        ],
        "Flexão de Braços": [
            "Apoie as mãos na largura dos ombros, corpo alinhado da cabeça aos calcanhares.",
            "Desça o peito em direção ao chão mantendo os cotovelos próximos ao corpo.",
            "Empurre o solo até estender os braços sem travar os cotovelos.",
            "Mantenha o abdômen contraído durante todas as repetições."
        ],
        "Tríceps Pulley": [
            "Fique de frente para a polia, cotovelos colados ao tronco.",
            "Estenda os antebraços até o braço ficar quase reto.",
            "Retorne controlando sem deixar os cotovelos abrirem para fora.",
            "Expire na extensão e mantenha os ombros parados."
        ],
        "Tríceps Testa": [
            "Deite no banco reto com a barra W ou halteres acima do rosto.",
            "Flexione apenas os cotovelos, descendo a carga perto da testa.",
            "Estenda os braços contraindo o tríceps no topo.",
            "Mantenha os cotovelos apontados para o teto, sem abrir lateralmente."
        ],
        "Tríceps Francês": [
            "Segure o halter com as duas mãos atrás da cabeça, cotovelos altos.",
            "Desça o peso atrás da cabeça flexionando os cotovelos.",
            "Estenda os braços sem mover os ombros para frente.",
            "Mantenha o abdômen firme e o tronco estável."
        ],
        "Mergulho no Banco": [
            "Apoie as mãos no banco atrás do corpo, pernas estendidas à frente.",
            "Flexione os cotovelos descendo até ~90° ou conforme sua mobilidade.",
            "Empurre o banco até estender os braços, contraindo o tríceps.",
            "Mantenha os ombros afastados das orelhas durante o movimento."
        ],
        "Barra Fixa": [
            "Segure a barra na pegada pronada, largura um pouco maior que os ombros.",
            "Inicie a subida puxando as escápulas para baixo antes de flexionar os cotovelos.",
            "Leve o peito em direção à barra sem balançar o corpo.",
            "Desça controlando até extensão quase completa dos braços."
        ],
        "Remada Curvada": [
            "Incline o tronco a ~45°, joelhos levemente flexionados e coluna neutra.",
            "Puxe a barra em direção ao umbigo, aproximando as escápulas.",
            "Desça a carga controlando sem arredondar as costas.",
            "Mantenha o core ativado e o olhar levemente à frente."
        ],
        "Puxada Frontal": [
            "Sente na máquina com as coxas fixadas e pegada um pouco mais larga que os ombros.",
            "Puxe a barra até a altura do peito superior, cotovelos indo para baixo.",
            "Retorne devagar alongando as costas sem soltar o peso de uma vez.",
            "Evite inclinar demais o tronco para trás."
        ],
        "Remada Unilateral": [
            "Apoie um joelho e a mão no banco, costas paralelas ao chão.",
            "Puxe o halter em direção ao quadril, cotovelo rente ao corpo.",
            "Desça controlando até o braço quase estender.",
            "Mantenha o tronco estável, sem girar os quadris."
        ],
        "Pulldown Triângulo": [
            "Segure a pegada em V com os cotovelos apontando para baixo.",
            "Puxe em direção ao peito, focando na contração das costas.",
            "Retorne controlando a fase excêntrica.",
            "Não use impulso do tronco para puxar a carga."
        ],
        "Levantamento Terra Romeno": [
            "Fique em pé com barra ou halteres na frente das coxas.",
            "Empurre o quadril para trás mantendo as costas retas e joelhos semiflexionados.",
            "Desça até sentir alongamento nos posteriores, sem arredondar a coluna.",
            "Retorne contraindo glúteos e posteriores, empurrando o quadril para frente."
        ],
        "Puxada Alta": [
            "Segure a barra na largura dos ombros com pegada pronada.",
            "Puxe a barra em direção ao queixo, cotovelos abrindo para os lados.",
            "Desça controlando até os braços quase estenderem.",
            "Evite balançar o corpo ou usar impulso excessivo."
        ],
        "Rosca Direta": [
            "Fique em pé com halteres ou barra, cotovelos colados ao tronco.",
            "Flexione os cotovelos levando a carga em direção aos ombros.",
            "Desça controlando sem mover os cotovelos para frente.",
            "Mantenha os punhos neutros e o core ativado."
        ],
        "Rosca Martelo": [
            "Segure os halteres com pegada neutra (palmas voltadas uma para a outra).",
            "Flexione os cotovelos mantendo-os fixos ao lado do corpo.",
            "Contraia o bíceps e braquial no topo sem balançar.",
            "Retorne devagar até quase estender os braços."
        ],
        "Rosca Scott": [
            "Apoie os braços no banco Scott, axilas no topo do apoio.",
            "Desça a barra ou halteres controlando o alongamento do bíceps.",
            "Flexione os cotovelos sem tirar os braços do banco.",
            "Evite estender completamente os cotovelos na base do movimento."
        ],
        "Rosca Concentrada": [
            "Sente com as pernas abertas e cotovelo apoiado na parte interna da coxa.",
            "Desça o halter controlando até o braço quase estender.",
            "Flexione o cotovelo contraindo o bíceps no topo.",
            "Mantenha o tronco parado, sem balançar o peso."
        ],
        "Agachamento Livre": [
            "Posicione a barra no trapézio, pés na largura dos ombros.",
            "Desça flexionando joelhos e quadril como se fosse sentar em uma cadeira.",
            "Mantenha os joelhos alinhados com os pés e o peito erguido.",
            "Suba empurrando o chão com os calcanhares, contraindo glúteos no topo."
        ],
        "Leg Press 45°": [
            "Sente com os pés na plataforma na largura dos ombros.",
            "Desça a plataforma flexionando joelhos até ~90° ou conforme sua mobilidade.",
            "Empurre sem travar os joelhos no topo do movimento.",
            "Mantenha a lombar apoiada no banco durante todo o exercício."
        ],
        "Hack Squat": [
            "Posicione os ombros nos apoios e os pés na plataforma.",
            "Desça controlando, joelhos acompanhando a linha dos pés.",
            "Suba empurrando a plataforma sem tirar a lombar do encosto.",
            "Mantenha o core firme e respire expirando na subida."
        ],
        "Cadeira Extensora": [
            "Ajuste o encosto para os joelhos ficarem alinhados com o eixo da máquina.",
            "Estenda as pernas contraindo o quadríceps no topo.",
            "Desça controlando sem deixar o peso bater.",
            "Evite arquear a lombar ou usar impulso."
        ],
        "Mesa Flexora": [
            "Deite de bruços com os calcanhares atrás do rolo.",
            "Flexione os joelhos puxando o peso em direção aos glúteos.",
            "Desça devagar alongando os posteriores de coxa.",
            "Mantenha o quadril colado ao banco durante o movimento."
        ],
        "Stiff": [
            "Fique em pé com barra ou halteres, pés na largura do quadril.",
            "Incline o tronco à frente empurrando o quadril para trás, pernas quase retas.",
            "Desça até sentir alongamento nos posteriores, costas retas.",
            "Retorne contraindo glúteos e isquiotibiais."
        ],
        "Afundo": [
            "Dê um passo à frente mantendo o tronco ereto.",
            "Desça flexionando os dois joelhos até ~90°.",
            "Empurre o chão com a perna da frente para retornar.",
            "Alterne as pernas ou complete todas as reps de um lado antes de trocar."
        ],
        "Cadeira Adutora": [
            "Sente com as coxas internas contra as almofadas.",
            "Feche as pernas contraindo a parte interna da coxa.",
            "Retorne controlando sem soltar o peso abruptamente.",
            "Mantenha o tronco apoiado e evite inclinar para frente."
        ],
        "Cadeira Abdutora": [
            "Sente com as coxas externas contra as almofadas.",
            "Abra as pernas contraindo o glúteo médio.",
            "Retorne devagar mantendo tensão no movimento.",
            "Não use impulso do tronco para abrir as pernas."
        ],
        "Panturrilha em Pé": [
            "Posicione a ponta dos pés na plataforma, calcanhares para fora.",
            "Desça os calcanhares para alongar a panturrilha.",
            "Suba na ponta dos pés contraindo no topo por 1 segundo.",
            "Mantenha os joelhos quase estendidos, sem travar."
        ],
        "Panturrilha Sentado": [
            "Sente com as coxas sob o apoio e ponta dos pés na plataforma.",
            "Desça os calcanhares para alongar o sóleo.",
            "Eleve os calcanhares o máximo possível contraindo no topo.",
            "Execute o movimento de forma controlada, sem balançar."
        ],
        "Encolhimento com Barra": [
            "Fique em pé com a barra à frente das coxas, braços estendidos.",
            "Eleve os ombros em direção às orelhas, contraindo o trapézio.",
            "Segure 1 segundo no topo e desça controlando.",
            "Evite rodar os ombros; o movimento é vertical."
        ],
        "Desenvolvimento Militar": [
            "Sente ou fique em pé com halteres ou barra na altura dos ombros.",
            "Empurre a carga acima da cabeça até estender os braços.",
            "Desça controlando até a altura do queixo ou orelhas.",
            "Mantenha o core ativado e evite arquear excessivamente a lombar."
        ],
        "Elevação Lateral": [
            "Fique em pé com halteres ao lado do corpo, cotovelos levemente flexionados.",
            "Eleve os braços lateralmente até a altura dos ombros.",
            "Desça controlando sem deixar o peso cair.",
            "Evite usar impulso do tronco ou elevar acima dos ombros."
        ],
        "Remada Alta": [
            "Segure a barra na largura dos ombros com pegada pronada.",
            "Puxe a barra em direção ao queixo, cotovelos abrindo para cima.",
            "Desça controlando até os braços estenderem.",
            "Mantenha a barra próxima ao corpo durante o movimento."
        ],
        "Encolhimento com Halteres": [
            "Fique em pé com um halter em cada mão ao lado do corpo.",
            "Eleve os ombros verticalmente contraindo o trapézio.",
            "Pause no topo e desça devagar.",
            "Mantenha os braços estendidos e o tronco estável."
        ],
        "Elevação Frontal": [
            "Segure halteres ou barra à frente das coxas.",
            "Eleve os braços à frente até a altura dos ombros.",
            "Desça controlando sem balançar o tronco.",
            "Mantenha cotovelos levemente flexionados durante o movimento."
        ],
        "Crucifixo Inverso": [
            "Incline o tronco à frente ou use o banco inclinado peitoral.",
            "Com halteres, abra os braços lateralmente mantendo cotovelos semiflexionados.",
            "Contraia a parte posterior do ombro ao fechar o movimento.",
            "Evite subir os halteres acima da linha dos ombros."
        ],
        "Face Pull": [
            "Ajuste a polia na altura do rosto com corda.",
            "Puxe a corda em direção ao rosto, cotovelos altos e abertos.",
            "Separe as pontas da corda ao lado das orelhas.",
            "Retorne controlando, mantendo tensão nos ombros posteriores."
        ]
    ]

    private static let keywordGuides: [(keywords: [String], steps: [String])] = [
        (["supino"], [
            "Deite no banco com pés firmes e escápulas retraídas.",
            "Desça a carga controlando até o peito.",
            "Empurre em linha reta contraindo o peitoral.",
            "Mantenha os cotovelos em ângulo seguro (~45°)."
        ]),
        (["crucifixo", "crossover"], [
            "Posicione-se com cotovelos levemente flexionados.",
            "Abra os braços em arco controlado até sentir alongamento.",
            "Feche o movimento contraindo o peitoral.",
            "Evite travar os cotovelos ou usar peso excessivo."
        ]),
        (["tríceps", "triceps", "mergulho"], [
            "Mantenha os cotovelos estáveis durante o movimento.",
            "Flexione ou estenda os antebraços conforme o exercício.",
            "Contraia o tríceps na fase de esforço.",
            "Retorne controlando sem abrir os cotovelos lateralmente."
        ]),
        (["rosca", "curl"], [
            "Cotovelos fixos ao lado do corpo ou apoiados no banco.",
            "Flexione os cotovelos levando a carga em direção aos ombros.",
            "Contraia o bíceps no topo sem balançar.",
            "Desça devagar mantendo tensão no músculo."
        ]),
        (["remada", "row"], [
            "Mantenha a coluna neutra e o core ativado.",
            "Puxe a carga em direção ao tronco, aproximando as escápulas.",
            "Contraia as costas no final do movimento.",
            "Desça controlando sem arredondar a lombar."
        ]),
        (["puxada", "pulldown", "barra fixa", "pull"], [
            "Inicie o movimento retraindo as escápulas.",
            "Puxe a carga em direção ao peito ou queixo.",
            "Contraia as costas no ponto de maior esforço.",
            "Retorne devagar até extensão quase completa dos braços."
        ]),
        (["agachamento", "squat", "leg press", "hack"], [
            "Pés firmes na largura adequada, core ativado.",
            "Desça flexionando joelhos e quadril com controle.",
            "Mantenha joelhos alinhados com os pés.",
            "Suba empurrando o chão ou a plataforma sem travar os joelhos."
        ]),
        (["extensora", "flexora", "stiff", "afundo"], [
            "Ajuste a máquina ou posição para alinhar as articulações.",
            "Execute o movimento em amplitude controlada.",
            "Contraia o músculo alvo na fase de esforço.",
            "Retorne devagar sem usar impulso."
        ]),
        (["panturrilha", "calf"], [
            "Posicione a ponta dos pés na plataforma.",
            "Desça os calcanhares para alongar a panturrilha.",
            "Suba na ponta dos pés contraindo no topo.",
            "Mantenha o movimento controlado em cada repetição."
        ]),
        (["desenvolvimento", "elevação", "elevacao", "militar"], [
            "Mantenha o core ativado e a coluna neutra.",
            "Empurre ou eleve a carga em trajetória controlada.",
            "Contraia os deltoides no topo do movimento.",
            "Desça devagar sem arquear excessivamente a lombar."
        ]),
        (["encolhimento"], [
            "Braços estendidos ao lado do corpo.",
            "Eleve os ombros verticalmente contraindo o trapézio.",
            "Pause brevemente no topo.",
            "Desça controlando sem rodar os ombros."
        ]),
        (["flexão", "flexao"], [
            "Corpo alinhado da cabeça aos calcanhares.",
            "Desça o peito controlando até amplitude segura.",
            "Empurre o solo mantendo o abdômen contraído.",
            "Evite deixar o quadril cair ou subir demais."
        ])
    ]

    private static let muscleGroupFallbacks: [MuscleGroup: [String]] = [
        .chest: [
            "Posicione-se com estabilidade no banco ou chão.",
            "Execute o movimento em amplitude que permita controle total.",
            "Contraia o peitoral na fase de esforço.",
            "Retorne devagar mantendo tensão no músculo."
        ],
        .back: [
            "Mantenha a coluna neutra e o abdômen firme.",
            "Inicie o movimento pelas escápulas.",
            "Puxe ou reme contraindo as costas.",
            "Desça a carga controlando sem perder a postura."
        ],
        .legs: [
            "Pés firmes e joelhos alinhados com a ponta dos pés.",
            "Desça com controle mantendo o peito erguido.",
            "Empurre o chão ou plataforma na subida.",
            "Evite travar as articulações no topo."
        ],
        .shoulders: [
            "Core ativado e postura ereta.",
            "Eleve ou empurre a carga sem balançar o tronco.",
            "Contraia os deltoides no ponto de maior esforço.",
            "Retorne controlando a fase excêntrica."
        ],
        .arms: [
            "Cotovelos estáveis durante todo o movimento.",
            "Flexione ou estenda os braços de forma controlada.",
            "Contraia bíceps ou tríceps na fase de esforço.",
            "Evite usar impulso do corpo."
        ],
        .core: [
            "Mantenha o abdômen contraído e a respiração controlada.",
            "Execute o movimento em amplitude segura.",
            "Contraia o core na fase de esforço.",
            "Não prenda a respiração durante as repetições."
        ],
        .fullBody: [
            "Aqueça as articulações antes de iniciar.",
            "Mantenha postura neutra e core ativado.",
            "Execute cada repetição com controle.",
            "Priorize a técnica antes de aumentar a carga."
        ]
    ]

    static func guide(for exercise: Exercise) -> [String] {
        if let exact = guides[exercise.name] {
            return exact
        }

        let normalized = exercise.name.lowercased()
        for rule in keywordGuides {
            if rule.keywords.contains(where: { normalized.contains($0) }) {
                return rule.steps
            }
        }

        return muscleGroupFallbacks[exercise.muscleGroup] ?? muscleGroupFallbacks[.fullBody]!
    }
}

extension Exercise {
    var executionGuide: [String] {
        ExerciseGuideCatalog.guide(for: self)
    }
}

struct ExerciseExecutionGuideView: View {
    let steps: [String]
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Label("Guia de Execução", systemImage: "list.number")
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
                        .background(AppTheme.accent)
                        .clipShape(Circle())

                    Text(step)
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(compact ? AppTheme.textSecondary : AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(compact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
