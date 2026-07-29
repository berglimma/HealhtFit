# HealthFit

Aplicativo iOS + watchOS de saúde e fitness desenvolvido em **Swift** e **SwiftUI**. O HealthFit integra treinos de musculação, cardio (incluindo corrida por distância e meta calórica), meditação, nutrição personalizada, assistente de dúvidas, métricas do Apple Health, sincronização com Apple Watch, relatório semanal de progresso, preparação para maratona e ícone dinâmico por inatividade.

| Plataforma | Versão mínima | Bundle ID |
|------------|---------------|-----------|
| iOS        | 17.0          | `luan.com.healthfit.app` |
| watchOS    | 10.0          | `luan.com.healthfit.app.watchkitapp` |

**Versão:** 1.0.0  
**Linguagem:** Swift 5  
**UI:** SwiftUI (tema escuro por padrão)  
**Desenvolvimento:** BERG / LUAN

---

## Índice

- [Visão geral](#visão-geral)
- [Stack tecnológica](#stack-tecnológica)
- [Arquitetura](#arquitetura)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Módulos e funcionalidades](#módulos-e-funcionalidades)
- [Ícone dinâmico do app](#ícone-dinâmico-do-app)
- [Sincronização com Apple Watch](#sincronização-com-apple-watch)
- [Persistência de dados](#persistência-de-dados)
- [Permissões e integrações](#permissões-e-integrações)
- [Requisitos](#requisitos)
- [Configuração e execução](#configuração-e-execução)
- [Build via linha de comando](#build-via-linha-de-comando)
- [Scripts auxiliares](#scripts-auxiliares)
- [Convenções de código](#convenções-de-código)
- [Limitações conhecidas](#limitações-conhecidas)

---

## Visão geral

O HealthFit é um app nativo Apple com dois targets principais:

1. **HealthFit (iPhone/iPad)** — experiência completa: autenticação, boas-vindas motivacionais, dashboard, treinos, nutrição, chat de dúvidas, perfil e relatórios.
2. **HealthFitWatch (Apple Watch)** — companion app focado em cronômetro, métricas em tempo real (BPM, calorias) e sessões guiadas sincronizadas com o iPhone.

### Fluxo de navegação

```
Login / Registro
      ↓
WelcomeMotivationView (5 s, mensagens por inatividade)
      ↓
MainTabView — 5 abas: Início · Treinos · Nutrição · Dúvidas · Perfil
```

O ponto de entrada do app iOS injeta os serviços globais via `@EnvironmentObject`:

```swift
@main
struct HealthFitApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var workoutStore = WorkoutStore()
    @StateObject private var mealPlanService = MealPlanService()
    @StateObject private var timerService = RestTimerService()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var weeklyReportService = WeeklyReportService.shared
    @StateObject private var wellnessService = DailyWellnessService.shared
    // ...
}
```

Ao abrir o app, `AppIconInactivityService` restaura o ícone verde padrão. Ao ir para background, inicia a contagem de inatividade e a pulsação alternada do ícone.

---

## Stack tecnológica

| Área | Tecnologia |
|------|------------|
| UI | SwiftUI, Charts |
| Saúde | HealthKit (leitura/escrita de treinos, passos, calorias, FC) |
| Watch | WatchConnectivity (`WCSession`) |
| Visão | AVFoundation + Vision (detecção de postura e repetições) |
| Notificações | UserNotifications (motivação diária, inatividade, início/fim de treino) |
| Background | BGTaskScheduler (atualização do ícone alternativo) |
| E-mail | MessageUI (`MFMailComposeViewController`) |
| Armazenamento | UserDefaults + FileManager (foto de perfil) |
| Layout adaptativo | `DeviceLayout`, `horizontalSizeClass` |

Não há backend remoto: autenticação, histórico de treinos e planos alimentares são persistidos localmente no dispositivo.

---

## Arquitetura

O projeto segue uma organização **MVVM simplificada** com serviços singleton ou `@StateObject`:

```
┌─────────────────────────────────────────────────────────┐
│                      Views (SwiftUI)                     │
│  Dashboard · Treinos · Nutrição · Dúvidas · Perfil     │
└─────────────────────────┬───────────────────────────────┘
                          │ @EnvironmentObject
┌─────────────────────────▼───────────────────────────────┐
│                        Services                          │
│  WorkoutStore · AuthService · HealthKitManager            │
│  WatchConnectivityManager · WeeklyReportService           │
│  HealthAssistantService · AppIconInactivityService        │
│  MarathonReportBuilder · DailyWellnessService             │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│              Models + UserDefaults / HealthKit           │
└─────────────────────────────────────────────────────────┘
```

**Padrões recorrentes:**

- `@MainActor` nos serviços observáveis
- Estado compartilhado via `ObservableObject` + `@Published`
- Análise de relatório semanal desacoplada em `WeeklyProgressAnalyzer` (funções estáticas puras)
- Protocolo de mensagens Watch baseado em dicionários com chave `"action"`
- Assistente de saúde baseado em base de conhecimento local (`HealthAssistantService`)

---

## Estrutura do projeto

```
HealhtFit/
├── README.md
├── generate_report.py              # Script auxiliar para gerar relatório .docx
├── scripts/
│   ├── generate_alternate_app_icons.py   # Ícones alternativos e frames de pulso
│   └── app_icon_master.png               # Master gerado a partir do AppIcon
└── HealthFit/
    └── HealthFit/
        ├── HealthFit.xcodeproj
        ├── HealthFit/                    # Target iOS
        │   ├── HealthFitApp.swift
        │   ├── Models/
        │   ├── Services/
        │   ├── Views/
        │   ├── Theme/
        │   ├── Assets.xcassets           # AppIcon + ícones alternativos + BrandHeart
        │   ├── Info.plist
        │   └── HealthFit.entitlements
        └── HealthFitWatch/               # Target watchOS
            ├── HealthFitWatchApp.swift
            ├── WatchContentView.swift
            └── WatchWorkoutManager.swift
```

### Models (`HealthFit/Models/`)

| Arquivo | Responsabilidade |
|---------|------------------|
| `WorkoutModels.swift` | Fichas, sessões, metadados de corrida (distância, ritmo, meta calórica) |
| `CardioModels.swift` | Catálogo de cardio, intensidades, distâncias (5–25 km), meta de calorias |
| `MeditationModels.swift` | Tópicos (7), durações (5–20 min), prompts guiados |
| `WeeklyProgressModels.swift` | Estatísticas semanais, tendências, meditação diária |
| `DailyWellnessModels.swift` | Sono, hidratação, metas por peso |
| `UserProfile.swift` | Perfil, biotipo, objetivo fitness, personal trainer |
| `MealModels.swift` | Plano alimentar semanal e lista de compras |

### Services (`HealthFit/Services/`)

| Serviço | Função |
|---------|--------|
| `WorkoutStore` | CRUD de fichas, sessões ativas, histórico |
| `AuthService` | Login/registro local, perfil do usuário |
| `HealthKitManager` | Autorização, métricas diárias, salvamento de treinos |
| `WatchConnectivityManager` | Bridge iPhone ↔ Watch (BPM, calorias, progresso) |
| `WeeklyReportService` | Disponibilidade do relatório (ciclo de 7 dias) |
| `WeeklyProgressAnalyzer` | Score, tendências, meditação e sugestões |
| `HealthAssistantService` | Chat de dúvidas (dieta, treinos, IMC, biotipos, sono) |
| `WelcomeMotivationService` | Mensagens da tela pós-login por inatividade |
| `AppIconInactivityService` | Ícone alternativo verde/amarelo/vermelho/quebrado + pulso |
| `MarathonReportBuilder` | Relatório de performance para maratona |
| `WorkoutReportBuilder` | Relatório de treino/cardio para e-mail |
| `DailyWellnessService` | Check-in de sono e consumo de água |
| `MealPlanService` | Geração e persistência do plano alimentar |
| `VisionWorkoutService` | Câmera + Vision para contagem de reps |
| `RestTimerService` | Timer de descanso entre séries |
| `NotificationService` | Notificações locais e lembretes de inatividade |
| `MotivationMessages` | Textos motivacionais (treino, ícone, superação calórica) |

### Views (`HealthFit/Views/`)

| Pasta | Telas principais |
|-------|------------------|
| `Auth/` | Login, registro |
| `Dashboard/` | Dashboard, gráficos HealthKit, relatório semanal |
| `Workout/` | Musculação, cardio, meditação, resumo, corrida por distância |
| `Nutrition/` | Plano alimentar, lista de compras |
| `Assistant/` | Chat de dúvidas com indicador de digitação |
| `Profile/` | Perfil, sono, hidratação, estado do ícone do app |
| `Camera/` | Treino com visão computacional |
| `Shared/` | Boas-vindas, check-in wellness, composição de e-mail, ícone pulsante |

---

## Módulos e funcionalidades

### Treinos — Musculação

- Fichas de treino com exercícios, séries, repetições e descanso
- Cronômetro por exercício e timer de descanso com alerta de overtime
- Sincronização com Watch (nome do exercício, tempo total e por exercício)
- Resumo pós-treino com opção de enviar relatório ao personal via e-mail
- Treino assistido por câmera (`VisionWorkoutService`) para contagem de repetições
- Registro opcional de uso de pré-treino

### Treinos — Cardio

- Catálogo com 11 modalidades (corrida, bicicleta, escalada, burpees, etc.)
- Três níveis de intensidade (baixa, média, alta) com duração e multiplicador calórico
- **Corrida por distância:** metas de 5, 10, 15, 20 e 25 km com ritmo alvo por intensidade
- **Meta de calorias (opcional):** presets ou valor personalizado (50–1200 kcal)
- Evolução calórica em tempo real, priorizando dados do Apple Watch
- Mensagens de progresso (25/50/75%) e **superação** ao ultrapassar a meta
- **Relatório de performance para maratona** após corridas por distância:
  - Projeções para meia (21,1 km) e maratona (42,2 km)
  - Comparação com melhor marca, volume semanal e orientações
- Sincronização Watch com meta de tempo, calorias e barra de progresso

### Treinos — Meditação

- 7 tópicos com 10 prompts cada (respiração, relaxamento, sono, pós-treino, etc.)
- Durações: 5, 10, 15 ou 20 minutos
- Prompts rotacionam ao longo da sessão
- Sincronização Watch com cor do tópico, anel de progresso e texto guiado

### Assistente de dúvidas (aba Dúvidas)

- Chat local com respostas sobre dieta, IMC, biotipos, sono, treinos e personal
- Indicador de digitação (3 s) antes de cada resposta
- Boas-vindas contextualizadas com alertas de sono, água e treinos
- Contexto personalizado com dados do perfil e do wellness do dia

### Boas-vindas pós-login

- Tela `WelcomeMotivationView` exibida por **5 segundos** após login
- Mensagens adaptadas ao tempo sem usar o app (24 h / 36 h / 48 h+)
- Transição automática para o dashboard, sem necessidade de toque

### Relatório semanal

- Gerado a partir do histórico de `WorkoutSession` dos últimos 7 dias
- Score geral (0–100), comparativo com semana anterior, gráfico de atividade diária
- Seção de **meditação** (sessões, minutos, evolução diária, tendência)
- Sugestões de melhoria priorizadas por objetivo fitness do usuário
- Badge **NOVO** no dashboard a cada 7 dias após visualização

### Wellness (sono e hidratação)

- Check-in de sono ao abrir o app (se ainda não registrado no dia)
- Meta de água calculada por peso (35 ml/kg)
- Avaliação qualitativa da qualidade do sono
- Dados exibidos no perfil e persistidos por usuário/dia

### Nutrição

- Plano alimentar semanal gerado com base no perfil (biotipo + objetivo)
- Lista de compras derivada do plano

### Apple Watch

- UI com abas verticais: treino ativo e status de sincronização
- Modos visuais distintos: verde (musculação), laranja (cardio), roxo (meditação)
- BPM e calorias do relógio retornam ao iPhone durante cardio/musculação
- Cardio com meta calórica: progresso e alerta de superação no relógio

---

## Ícone dinâmico do app

O ícone na tela inicial do iPhone muda conforme o tempo **sem abrir o app** (contagem inicia ao ir para background):

| Tempo sem abrir | Estado | Comportamento |
|-----------------|--------|---------------|
| Uso normal | Verde (padrão) | Pulsa entre 3 frames ao estar em background |
| 24 h | Amarelo | Ícone alternativo + pulso |
| 36 h | Vermelho | Ícone alternativo + pulso |
| 48 h+ | Quebrado | Ícone rachado + notificação para retomar atividades |

- Ao **abrir o app**, o ícone volta ao verde imediatamente
- `BGTaskScheduler` agenda transições mesmo com o app fechado
- Seção **Ícone do App** no Perfil mostra o estado projetado e próxima mudança
- Ícones gerados por `scripts/generate_alternate_app_icons.py` (12 variantes + pulso)

> **Nota:** Ícones alternativos exigem dispositivo físico; o simulador não aplica `setAlternateIconName`.

---

## Sincronização com Apple Watch

Comunicação via **WatchConnectivity** com mensagens JSON-like (`[String: Any]`).

### Ações iPhone → Watch

| `action` | Descrição |
|----------|-----------|
| `startWorkout` | Inicia treino de musculação |
| `syncWorkoutProgress` | Sincroniza tempos e exercício atual (tempo real) |
| `startCardio` | Inicia cardio com meta de tempo e calorias |
| `syncCardioProgress` | Atualiza tempo, calorias atuais e meta calórica |
| `startMeditation` | Inicia meditação com tópico, cor e prompt |
| `syncMeditationProgress` | Atualiza tempo e prompt (tempo real) |
| `restTimerStart` / `restTimerStop` | Timer de descanso no Watch |
| `stopWorkout` | Encerra sessão ativa |
| `deliverNotification` | Replica notificação no relógio |

### Dados Watch → iPhone

| Campo | Descrição |
|-------|-----------|
| `heartRate` | BPM em tempo real |
| `calories` | Calorias acumuladas na sessão |

Mensagens de alta frequência usam `sendMessage` (`realtime: true`). Início/fim de sessão usa `transferUserInfo` como fallback quando o Watch não está alcançável.

**Detecção de tipo de sessão no histórico:**

- Cardio: título com prefixo `"Cardio"`
- Meditação: título com prefixo `"Meditação"` ou `"Meditacao"`
- Corrida por distância: `targetDistanceKm` preenchido na sessão

---

## Persistência de dados

| Dado | Mecanismo | Chave / local |
|------|-----------|---------------|
| Usuário logado | UserDefaults | `healthfit_current_user` |
| Fichas de treino | UserDefaults (JSON) | `healthfit_workout_sheets` |
| Histórico de sessões | UserDefaults (JSON) | `healthfit_session_history` |
| Plano alimentar | UserDefaults | via `MealPlanService` |
| Wellness diário | UserDefaults | `healthfit_wellness_{email}_{dayKey}` |
| Último relatório visto | UserDefaults | `healthfit_last_weekly_report_viewed` |
| Fim da última sessão (ícone) | UserDefaults | `healthfit_last_session_end_at` |
| Foto de perfil | FileManager | diretório de documentos do app |
| Treinos concluídos | HealthKit | `HKWorkout` + calorias ativas |

Campos opcionais em `WorkoutSession` para cardio avançado: `targetDistanceKm`, `completedDistanceKm`, `averagePaceSecondsPerKm`, `targetCalories`, `cardioIntensityLabel`.

---

## Permissões e integrações

Configuradas no target iOS (`INFOPLIST_KEY_*` no Xcode):

| Permissão | Uso |
|-----------|-----|
| **HealthKit** (read/write) | Passos, calorias, FC, treinos |
| **Câmera** | Visão computacional para reps e postura |
| **Fotos** | Imagem de perfil |
| **Notificações** | Motivação, inatividade, início/fim de treino, ícone quebrado |

Entitlements (`HealthFit.entitlements`):

```xml
<key>com.apple.developer.healthkit</key>
<true/>
```

`Info.plist` declara **CFBundleAlternateIcons** (amarelo, vermelho, quebrado + frames de pulso) e identificadores **BGTaskScheduler** para atualização do ícone.

O companion Watch declara `WKCompanionAppBundleIdentifier = luan.com.healthfit.app`.

---

## Requisitos

- **macOS** com Xcode 15+ (recomendado Xcode 16)
- **Conta Apple Developer** para executar em dispositivo físico (HealthKit, ícones alternativos e Watch exigem device real)
- **iPhone** com iOS 17+
- **Apple Watch** pareado (opcional, para testar sincronização e calorias)
- Simulador iOS funciona para grande parte das telas; HealthKit, ícones alternativos e Watch têm limitações no simulador

---

## Configuração e execução

1. Clone o repositório:
   ```bash
   git clone https://github.com/berglimma/HealhtFit.git
   cd HealhtFit/HealthFit/HealthFit
   ```

2. Abra o projeto no Xcode:
   ```bash
   open HealthFit.xcodeproj
   ```

3. Selecione o scheme **HealthFit** e um simulador ou dispositivo iOS.

4. Configure **Signing & Capabilities** com seu Team e bundle identifiers compatíveis.

5. Para o Watch:
   - Selecione o scheme **HealthFitWatch**
   - Execute em Apple Watch Simulator ou dispositivo pareado
   - O app iOS deve estar instalado no iPhone companion

6. Execute (`⌘R`).

### Testando recursos que exigem dispositivo físico

| Recurso | Simulador | Dispositivo |
|---------|-----------|-------------|
| HealthKit completo | Parcial | Sim |
| Ícones alternativos | Não | Sim |
| E-mail ao personal | Não | Sim (conta Mail configurada) |
| Apple Watch sync | Limitado | Sim |

---

## Build via linha de comando

Build sem assinatura (útil para validar compilação em CI):

```bash
cd HealthFit/HealthFit
xcodebuild \
  -scheme HealthFit \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Para build com assinatura automática em máquina de desenvolvimento:

```bash
xcodebuild \
  -scheme HealthFit \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  build
```

---

## Scripts auxiliares

### Regenerar ícones alternativos

Requer Python 3 e Pillow:

```bash
pip install Pillow
python3 scripts/generate_alternate_app_icons.py
```

Gera em `Assets.xcassets`: `AppIconYellow`, `AppIconRed`, `AppIconBroken`, frames de pulso (`*Pulse1`, `*Pulse2`) e `BrandHeart` (uso na UI).

### Relatório .docx

```bash
python3 generate_report.py
```

---

## Convenções de código

- **Idioma da UI:** português (Brasil)
- **Serviços:** `@MainActor final class … : ObservableObject`
- **Singletons compartilhados:** `static let shared` (`WatchConnectivityManager`, `WeeklyReportService`, `AppIconInactivityService`, etc.)
- **Tema:** `AppTheme` + `BiotypeThemes` (cores por biotipo)
- **Layout:** `DeviceLayout.adaptivePadding` + `.adaptiveContentWidth()` para iPad
- **Sessões:** toda atividade gera um `WorkoutSession` com `startedAt` / `endedAt` para alimentar dashboard e relatório

---

## Limitações conhecidas

| Área | Situação atual |
|------|----------------|
| Autenticação | Local/simulada — sem API, JWT ou Keychain |
| Assistente de dúvidas | Base de conhecimento local — não é LLM externo |
| Sincronização de dados | Apenas entre iPhone e Watch durante sessão ativa |
| Backup | Dados em UserDefaults — não há sync iCloud |
| Ícone animado | Pulsação via alternância de frames estáticos (limitação do iOS) |
| Testes automatizados | Sem target de unit/UI tests no projeto |
| Internacionalização | Apenas pt-BR |

---

## Créditos

**BERG / LUAN**

Código desenvolvido por BERG / LUAN.

---

## Licença

Definir licença do projeto (ex.: MIT, proprietária) antes da publicação pública do repositório.
