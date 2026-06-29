# HealthFit

Aplicativo iOS + watchOS de saúde e fitness desenvolvido em **Swift** e **SwiftUI**. O HealthFit integra treinos de musculação, cardio e meditação, nutrição personalizada, métricas do Apple Health, sincronização com Apple Watch, relatório semanal de progresso e check-in de sono/hidratação.

| Plataforma | Versão mínima | Bundle ID |
|------------|---------------|-----------|
| iOS        | 17.0          | `luan.com.healthfit.app` |
| watchOS    | 10.0          | `luan.com.healthfit.app.watchkitapp` |

**Versão:** 1.0.0  
**Linguagem:** Swift 5  
**UI:** SwiftUI (tema escuro por padrão)

---

## Índice

- [Visão geral](#visão-geral)
- [Stack tecnológica](#stack-tecnológica)
- [Arquitetura](#arquitetura)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Módulos e funcionalidades](#módulos-e-funcionalidades)
- [Sincronização com Apple Watch](#sincronização-com-apple-watch)
- [Persistência de dados](#persistência-de-dados)
- [Permissões e integrações](#permissões-e-integrações)
- [Requisitos](#requisitos)
- [Configuração e execução](#configuração-e-execução)
- [Build via linha de comando](#build-via-linha-de-comando)
- [Convenções de código](#convenções-de-código)
- [Limitações conhecidas](#limitações-conhecidas)

---

## Visão geral

O HealthFit é um app nativo Apple com dois targets principais:

1. **HealthFit (iPhone/iPad)** — experiência completa: autenticação, dashboard, treinos, nutrição, perfil e relatórios.
2. **HealthFitWatch (Apple Watch)** — companion app focado em cronômetro, métricas em tempo real e sessões guiadas sincronizadas com o iPhone.

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

O fluxo de navegação raiz (`RootView`) alterna entre autenticação e `MainTabView` (4 abas: Início, Treinos, Nutrição, Perfil).

---

## Stack tecnológica

| Área | Tecnologia |
|------|------------|
| UI | SwiftUI, Charts |
| Saúde | HealthKit (leitura/escrita de treinos, passos, calorias, FC) |
| Watch | WatchConnectivity (`WCSession`) |
| Visão | AVFoundation + Vision (detecção de postura e repetições) |
| Notificações | UserNotifications (motivação diária, lembretes de inatividade) |
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
│  Dashboard · Treinos · Nutrição · Perfil · Watch UI   │
└─────────────────────────┬───────────────────────────────┘
                          │ @EnvironmentObject
┌─────────────────────────▼───────────────────────────────┐
│                        Services                          │
│  WorkoutStore · AuthService · HealthKitManager            │
│  WatchConnectivityManager · WeeklyReportService           │
│  DailyWellnessService · MealPlanService · VisionWorkout   │
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

---

## Estrutura do projeto

```
HealhtFit/
├── README.md
├── generate_report.py          # Script auxiliar para gerar relatório .docx
└── HealthFit/
    └── HealthFit/
        ├── HealthFit.xcodeproj
        ├── HealthFit/                    # Target iOS
        │   ├── HealthFitApp.swift
        │   ├── Models/
        │   ├── Services/
        │   ├── Views/
        │   ├── Theme/
        │   ├── Assets.xcassets
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
| `WorkoutModels.swift` | Fichas de treino, sessões, exercícios, registros |
| `CardioModels.swift` | Catálogo de cardio, intensidades, configuração |
| `MeditationModels.swift` | Tópicos (7), durações (5–20 min), prompts guiados |
| `WeeklyProgressModels.swift` | Estatísticas semanais, tendências, resumo de meditação |
| `DailyWellnessModels.swift` | Sono, hidratação, metas por peso |
| `UserProfile.swift` | Perfil, biotipo, objetivo fitness |
| `MealModels.swift` | Plano alimentar semanal e lista de compras |

### Services (`HealthFit/Services/`)

| Serviço | Função |
|---------|--------|
| `WorkoutStore` | CRUD de fichas, sessões ativas, histórico |
| `AuthService` | Login/registro local, perfil do usuário |
| `HealthKitManager` | Autorização, métricas diárias, salvamento de treinos |
| `WatchConnectivityManager` | Bridge iPhone ↔ Watch |
| `WeeklyReportService` | Disponibilidade do relatório (ciclo de 7 dias) |
| `WeeklyProgressAnalyzer` | Cálculo de score, tendências e sugestões |
| `DailyWellnessService` | Check-in de sono e consumo de água |
| `MealPlanService` | Geração e persistência do plano alimentar |
| `VisionWorkoutService` | Câmera + Vision para contagem de reps |
| `RestTimerService` | Timer de descanso entre séries |
| `NotificationService` | Notificações locais |
| `WorkoutReportBuilder` | Montagem de relatório para envio por e-mail |

### Views (`HealthFit/Views/`)

| Pasta | Telas principais |
|-------|------------------|
| `Auth/` | Login, registro |
| `Dashboard/` | Dashboard, gráficos HealthKit, relatório semanal |
| `Workout/` | Lista (musculação/cardio/meditação), treino ativo, resumo |
| `Nutrition/` | Plano alimentar, lista de compras |
| `Profile/` | Perfil, sono e hidratação |
| `Camera/` | Treino com visão computacional |
| `Shared/` | Check-in wellness, composição de e-mail |

---

## Módulos e funcionalidades

### Treinos — Musculação

- Fichas de treino com exercícios, séries, repetições e descanso
- Cronômetro por exercício e timer de descanso com alerta de overtime
- Sincronização com Watch (nome do exercício, tempo total e por exercício)
- Resumo pós-treino com opção de enviar relatório ao personal via e-mail
- Treino assistido por câmera (`VisionWorkoutService`) para contagem de repetições

### Treinos — Cardio

- Catálogo com 11 modalidades (corrida, bicicleta, escalada, burpees, etc.)
- Três níveis de intensidade (baixa, média, alta) com duração e multiplicador calórico
- Sincronização Watch com meta de tempo e barra de progresso (tema laranja)

### Treinos — Meditação

- 7 tópicos com 10 prompts cada (respiração, relaxamento, sono, pós-treino, etc.)
- Durações: 5, 10, 15 ou 20 minutos
- Prompts rotacionam ao longo da sessão
- Sincronização Watch com cor do tópico, anel de progresso e texto guiado (tema roxo/índigo)

### Relatório semanal

- Gerado a partir do histórico de `WorkoutSession` dos últimos 7 dias
- Score geral (0–100), comparativo com semana anterior, gráfico de atividade diária
- Seção dedicada de **meditação** (sessões, minutos, tópicos, tendência)
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

---

## Sincronização com Apple Watch

Comunicação via **WatchConnectivity** com mensagens JSON-like (`[String: Any]`).

### Ações iPhone → Watch

| `action` | Descrição |
|----------|-----------|
| `startWorkout` | Inicia treino de musculação |
| `syncWorkoutProgress` | Sincroniza tempos e exercício atual (tempo real) |
| `startCardio` | Inicia sessão de cardio com meta |
| `syncCardioProgress` | Atualiza progresso do cardio (tempo real) |
| `startMeditation` | Inicia meditação com tópico, cor e prompt |
| `syncMeditationProgress` | Atualiza tempo e prompt (tempo real) |
| `startRest` / `stopRest` | Timer de descanso no Watch |
| `stopWorkout` | Encerra sessão ativa |

### Ações Watch → iPhone

| `action` | Descrição |
|----------|-----------|
| `heartRateUpdate` | BPM em tempo real |
| `caloriesUpdate` | Calorias estimadas |

Mensagens de alta frequência usam `sendMessage` (`realtime: true`). Início/fim de sessão usa `transferUserInfo` como fallback quando o Watch não está alcançável.

**Detecção de tipo de sessão no histórico:**

- Cardio: título com prefixo `"Cardio"`
- Meditação: título com prefixo `"Meditação"` ou `"Meditacao"`

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
| Foto de perfil | FileManager | diretório de documentos do app |
| Treinos concluídos | HealthKit | `HKWorkout` + calorias ativas |

---

## Permissões e integrações

Configuradas no target iOS (`INFOPLIST_KEY_*` no Xcode):

| Permissão | Uso |
|-----------|-----|
| **HealthKit** (read/write) | Passos, calorias, FC, treinos |
| **Câmera** | Visão computacional para reps e postura |
| **Fotos** | Imagem de perfil |
| **Notificações** | Motivação, inatividade, início/fim de treino |

Entitlements (`HealthFit.entitlements`):

```xml
<key>com.apple.developer.healthkit</key>
<true/>
```

O companion Watch declara `WKCompanionAppBundleIdentifier = luan.com.healthfit.app`.

---

## Requisitos

- **macOS** com Xcode 15+ (recomendado Xcode 16)
- **Conta Apple Developer** para executar em dispositivo físico (HealthKit e Watch exigem device real)
- **iPhone** com iOS 17+
- **Apple Watch** pareado (opcional, para testar sincronização)
- Simulador iOS funciona para grande parte das telas; HealthKit e Watch têm limitações no simulador

---

## Configuração e execução

1. Clone o repositório:
   ```bash
   git clone <url-do-repositorio>
   cd HealhtFit/HealthFit/HealthFit
   ```

2. Abra o projeto no Xcode:
   ```bash
   open HealthFit.xcodeproj
   ```

3. Selecione o scheme **HealthFit** e um simulador ou dispositivo iOS.

4. Configure **Signing & Capabilities** com seu Team e bundle identifiers compatíveis (ou mantenha os IDs do projeto se tiver acesso).

5. Para o Watch:
   - Selecione o scheme **HealthFitWatch**
   - Execute em Apple Watch Simulator ou dispositivo pareado
   - O app iOS deve estar instalado no iPhone companion

6. Execute (`⌘R`).

### Testando e-mail do relatório ao personal

O envio usa `MFMailComposeViewController`. Funciona apenas em **dispositivo físico** com conta de e-mail configurada no app Mail. No simulador, o composer pode não estar disponível.

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

## Convenções de código

- **Idioma da UI:** português (Brasil)
- **Serviços:** `@MainActor final class … : ObservableObject`
- **Singletons compartilhados:** `static let shared` (`WatchConnectivityManager`, `WeeklyReportService`, `DailyWellnessService`)
- **Tema:** `AppTheme` + `BiotypeThemes` (cores por biotipo)
- **Layout:** `DeviceLayout.adaptivePadding` + `.adaptiveContentWidth()` para iPad
- **Sessões:** toda atividade gera um `WorkoutSession` com `startedAt` / `endedAt` para alimentar dashboard e relatório

---

## Limitações conhecidas

| Área | Situação atual |
|------|----------------|
| Autenticação | Local/simulada — sem API, JWT ou Keychain |
| Sincronização de dados | Apenas entre iPhone e Watch durante sessão ativa |
| Backup | Dados em UserDefaults — não há sync iCloud |
| Testes automatizados | Sem target de unit/UI tests no projeto |
| Internacionalização | Apenas pt-BR |

---

## Licença

Definir licença do projeto (ex.: MIT, proprietária) antes da publicação pública do repositório.
