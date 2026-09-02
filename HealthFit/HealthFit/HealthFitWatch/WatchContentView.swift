import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        Group {
            if workoutManager.isActive {
                activeWorkoutRoot
            } else {
                NavigationStack {
                    homeMenu
                }
            }
        }
    }

    // MARK: - Menu principal

    private var homeMenu: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    Image(systemName: "heart.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("HealthFit")
                        .font(.headline)
                    Text("Escolha o que fazer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Iniciar") {
                NavigationLink {
                    strengthList
                } label: {
                    Label("Treinos", systemImage: "dumbbell.fill")
                }

                NavigationLink {
                    cardioList
                } label: {
                    Label("Cardio", systemImage: "figure.run")
                }

                NavigationLink {
                    meditationList
                } label: {
                    Label("Meditação", systemImage: "brain.head.profile")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        workoutManager.isPhoneReachable ? "iPhone conectado" : "Modo solo no relógio",
                        systemImage: workoutManager.isPhoneReachable
                            ? "iphone.and.arrow.forward"
                            : "applewatch"
                    )
                    .font(.caption2)
                    .foregroundStyle(workoutManager.isPhoneReachable ? .green : .secondary)
                    Text("Você pode iniciar treinos mesmo sem o iPhone. BPM e kcal usam o Watch.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("HealthFit")
    }

    // MARK: - Listas

    private var strengthList: some View {
        List {
            ForEach(WatchCatalog.strengthPrograms) { program in
                Button {
                    workoutManager.beginLocalStrength(program)
                } label: {
                    Label(program.title, systemImage: program.icon)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Treinos")
    }

    private var cardioList: some View {
        List {
            Section("Água · Surf / Kitesurf") {
                ForEach(WatchCatalog.cardioActivities.filter(\.isWaterSport)) { activity in
                    NavigationLink {
                        waterSportStartView(activity: activity)
                    } label: {
                        Label(activity.name, systemImage: activity.icon)
                            .font(.caption)
                    }
                }
            }

            Section("Cardio") {
                ForEach(WatchCatalog.cardioActivities.filter { !$0.isWaterSport }) { activity in
                    NavigationLink {
                        if activity.isSwimming {
                            cardioDurationPicker(activity: activity)
                        } else {
                            cardioDurationPicker(activity: activity)
                        }
                    } label: {
                        Label(activity.name, systemImage: activity.icon)
                            .font(.caption)
                    }
                }
            }

            Section("Escalada") {
                Toggle(isOn: $workoutManager.isClimbingAutoDetectEnabled) {
                    Label("Detectar automático", systemImage: "figure.climbing")
                        .font(.caption)
                }
                if !workoutManager.climbingDetectionStatus.isEmpty {
                    Text(workoutManager.climbingDetectionStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Cardio")
    }

    /// Setup estilo Surf para Surf e Kitesurf (mesmo fluxo, opções paralelas).
    private func waterSportStartView(activity: WatchCatalog.CardioActivity) -> some View {
        WaterSportWatchStartView(activity: activity) { mode, board in
            workoutManager.beginLocalCardio(
                activity,
                targetSeconds: 0,
                setupModeName: mode,
                setupBoardName: board
            )
        }
    }

    private func cardioDurationPicker(activity: WatchCatalog.CardioActivity) -> some View {
        List {
            Section {
                Text(activity.name)
                    .font(.headline)
                Text("Duração alvo (opcional — livre se não escolher)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("Duração") {
                Button("Livre (sem meta de tempo)") {
                    workoutManager.beginLocalCardio(activity, targetSeconds: 0)
                }
                .font(.caption)

                ForEach(WatchCatalog.DurationOption.allCases) { option in
                    Button(option.label) {
                        workoutManager.beginLocalCardio(activity, targetSeconds: option.seconds)
                    }
                    .font(.caption)
                }
            }
        }
        .navigationTitle(activity.name)
    }

    private var meditationList: some View {
        List {
            ForEach(WatchCatalog.meditationTopics) { topic in
                NavigationLink {
                    meditationDurationPicker(topic: topic)
                } label: {
                    Label(topic.name, systemImage: topic.icon)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Meditação")
    }

    private func meditationDurationPicker(topic: WatchCatalog.MeditationTopic) -> some View {
        List {
            Section {
                Text(topic.name)
                    .font(.headline)
            }
            Section("Duração") {
                ForEach([WatchCatalog.DurationOption.five, .ten, .fifteen, .twenty], id: \.id) { option in
                    Button(option.label) {
                        workoutManager.beginLocalMeditation(topic, targetSeconds: option.seconds)
                    }
                    .font(.caption)
                }
            }
        }
        .navigationTitle(topic.name)
    }

    // MARK: - Sessão ativa

    private var activeWorkoutRoot: some View {
        TabView {
            activeMetricsPage
            if workoutManager.isWaterSportMode {
                waterSportStatsPage
            }
            if workoutManager.isKitesurfMode {
                KiteSpotBuddyWatchRootView(workoutManager: workoutManager)
            }
            sessionControlsPage
        }
        .tabViewStyle(.verticalPage)
    }

    /// Página 1: cronômetro e métricas (sem botões empilhados).
    private var activeMetricsPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(workoutManager.workoutName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if workoutManager.isPaused {
                        Text("PAUSADO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                if workoutManager.isResting {
                    restSection
                } else if workoutManager.isMeditationWorkout {
                    meditationSection
                } else if workoutManager.isCardioWorkout {
                    cardioSection
                } else {
                    strengthSection
                }

                if !workoutManager.isMeditationWorkout {
                    compactMetricsRow
                }

                Text("Deslize ↑ para Pausar / Encerrar")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }

    /// Página dedicada — mesma experiência para Surf e Kitesurf (funções espelhadas).
    private var waterSportStatsPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                Label(
                    workoutManager.isKitesurfMode ? "Kitesurf ao vivo" : "Surf ao vivo",
                    systemImage: workoutManager.isKitesurfMode ? "wind" : "figure.surfing"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.cyan)

                if !workoutManager.waterSetupModeName.isEmpty || !workoutManager.waterSetupBoardName.isEmpty {
                    VStack(spacing: 2) {
                        if !workoutManager.waterSetupModeName.isEmpty {
                            Text(workoutManager.isKitesurfMode
                                 ? "Modo: \(workoutManager.waterSetupModeName)"
                                 : "Prancha: \(workoutManager.waterSetupModeName)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        if !workoutManager.waterSetupBoardName.isEmpty {
                            Text(workoutManager.isKitesurfMode
                                 ? "Prancha: \(workoutManager.waterSetupBoardName)"
                                 : workoutManager.waterSetupBoardName)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    waterStat("\(workoutManager.waterJumpCount)", "saltos")
                    waterStat(String(format: "%.1f", workoutManager.waterMaxJumpMeters), "m max")
                    waterStat(String(format: "%.1f", workoutManager.waterLastJumpMeters), "último")
                }

                HStack(spacing: 10) {
                    waterStat(String(format: "%.1f", workoutManager.waterLiveAccelG), "g")
                    waterStat(
                        String(format: "%+.1f", workoutManager.waterRelativeAltitude),
                        "alt m"
                    )
                    waterStat("\(Int(workoutManager.heartRate))", "BPM")
                }

                Text(workoutManager.isKitesurfMode
                     ? "Saltos: giroscópio + acelerômetro (como no Surf)"
                     : "Sensores ativos · saltos automáticos e manuais")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if workoutManager.isKitesurfMode {
                    Text("Deslize ↑ para Spot Buddy")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.cyan)
                }

                if !workoutManager.waterSensorStatus.isEmpty {
                    Text(workoutManager.waterSensorStatus)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !workoutManager.lastAutoJumpNote.isEmpty {
                    Text(workoutManager.lastAutoJumpNote)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.cyan)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Button {
                    workoutManager.markWaterSportJump()
                } label: {
                    Label("Marcar salto", systemImage: "hand.tap")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(workoutManager.isPaused)

                Button {
                    workoutManager.requestPhoneSyncFromWatch()
                } label: {
                    Label(
                        workoutManager.isPhoneReachable
                            ? "Sincronizar iPhone"
                            : "Enviar p/ iPhone",
                        systemImage: "iphone.and.arrow.forward"
                    )
                    .font(.caption2)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if !workoutManager.watchSyncStatus.isEmpty {
                    Text(workoutManager.watchSyncStatus)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }

    private func waterStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Página de controles: Pausar e Encerrar em linha, sem sobreposição.
    private var sessionControlsPage: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            Text(formatDuration(workoutManager.workoutElapsedSeconds))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(workoutManager.isPaused ? .orange : .primary)

            Text(workoutManager.isPaused ? "Sessão pausada" : "Sessão em andamento")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    workoutManager.togglePause()
                } label: {
                    Label(
                        workoutManager.isPaused ? "Retomar" : "Pausar",
                        systemImage: workoutManager.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(workoutManager.isPaused ? .green : .orange)

                Button {
                    workoutManager.stopWorkout()
                } label: {
                    Label("Encerrar", systemImage: "xmark")
                        .font(.caption2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }

    private var strengthSection: some View {
        VStack(spacing: 6) {
            Label("Cronômetro", systemImage: "stopwatch.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(formatDuration(workoutManager.workoutElapsedSeconds))
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(workoutManager.isPaused ? .yellow : .green)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if !workoutManager.currentExerciseName.isEmpty {
                Text(workoutManager.currentExerciseName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(formatDuration(workoutManager.exerciseElapsedSeconds))
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var meditationSection: some View {
        let accent = meditationColor(from: workoutManager.meditationColorName)
        let remaining = max(workoutManager.meditationTargetSeconds - workoutManager.workoutElapsedSeconds, 0)
        let progress = workoutManager.meditationTargetSeconds > 0
            ? Double(workoutManager.workoutElapsedSeconds) / Double(workoutManager.meditationTargetSeconds)
            : 0

        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: workoutManager.meditationTopicIcon)
                    .font(.caption)
                Text(workoutManager.meditationTopicName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(accent.opacity(0.2))
            .clipShape(Capsule())

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(formatDuration(remaining))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                    Text("restante")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Etapa \(workoutManager.meditationPromptIndex + 1)/\(workoutManager.meditationTotalPrompts)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(accent.opacity(0.85))

            if !workoutManager.meditationPrompt.isEmpty {
                Text(workoutManager.meditationPrompt)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func meditationColor(from name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        default: return .purple
        }
    }

    private var cardioSection: some View {
        let hasCalorieGoal = workoutManager.cardioTargetCalories > 0
        let calorieProgress = hasCalorieGoal
            ? min(workoutManager.calories / Double(workoutManager.cardioTargetCalories), 1.0)
            : 0

        return VStack(spacing: 6) {
            if workoutManager.isWaterSportMode {
                waterSportCompactChip
            }
            if workoutManager.isSwimmingMode {
                swimmingCardioExtras
            }

            if hasCalorieGoal {
                Label("Meta calórica", systemImage: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)

                Text("\(Int(workoutManager.calories))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(workoutManager.calories >= Double(workoutManager.cardioTargetCalories) ? .orange : .primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("de \(workoutManager.cardioTargetCalories) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ProgressView(value: calorieProgress)
                    .tint(.orange)

                if !workoutManager.cardioSuperationMessage.isEmpty {
                    Text(workoutManager.cardioSuperationMessage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            } else {
                Label("Cronômetro", systemImage: "stopwatch.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(formatDuration(workoutManager.workoutElapsedSeconds))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(workoutManager.isPaused ? Color.yellow : Color.orange)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                if workoutManager.cardioTargetSeconds > 0 {
                    Text("Meta: \(formatDuration(workoutManager.cardioTargetSeconds))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ProgressView(
                        value: Double(workoutManager.workoutElapsedSeconds),
                        total: Double(max(workoutManager.cardioTargetSeconds, 1))
                    )
                    .tint(.orange)
                }
            }

            if !workoutManager.currentExerciseName.isEmpty {
                Text(workoutManager.currentExerciseName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }

    /// Chip resumido na página de métricas; detalhe + sync ficam na página de água.
    private var waterSportCompactChip: some View {
        HStack(spacing: 6) {
            Image(systemName: workoutManager.isKitesurfMode ? "wind" : "figure.surfing")
            Text("\(workoutManager.waterJumpCount) saltos")
            Text("·")
            Text(String(format: "%.1f m", workoutManager.waterMaxJumpMeters))
            if !workoutManager.waterSetupModeName.isEmpty {
                Text("·")
                Text(workoutManager.waterSetupModeName)
                    .lineLimit(1)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.cyan)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.cyan.opacity(0.15))
        .clipShape(Capsule())
    }

    private var swimmingCardioExtras: some View {
        VStack(spacing: 4) {
            Label("Natação", systemImage: "figure.pool.swim")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.cyan)

            HStack(spacing: 10) {
                VStack(spacing: 1) {
                    Text("\(workoutManager.swimLapCount)")
                        .font(.title3.bold())
                    Text("voltas")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 1) {
                    Text("\(Int(workoutManager.swimDistanceMeters.rounded()))")
                        .font(.title3.bold())
                    Text("m")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 1) {
                    Text("\(Int(workoutManager.poolLengthMeters))")
                        .font(.title3.bold())
                    Text("m/volta")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Voltas automáticas do relógio")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var restSection: some View {
        VStack(spacing: 6) {
            Text(formatDuration(workoutManager.workoutElapsedSeconds))
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("Descanso")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !workoutManager.restExerciseName.isEmpty {
                Text(workoutManager.restExerciseName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Text(restTimeText)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundStyle(workoutManager.isRestOvertime ? .red : .green)

            if workoutManager.isRestOvertime {
                Text("Hora de voltar!")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var compactMetricsRow: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(Int(workoutManager.heartRate))")
                    .font(.title3.bold())
                    .foregroundStyle(.red)
                Text("BPM")
                    .font(.caption2)
            }

            VStack(spacing: 2) {
                Text("\(Int(workoutManager.calories))")
                    .font(.title3.bold())
                Text("kcal")
                    .font(.caption2)
            }
        }
    }

    private var restTimeText: String {
        if workoutManager.isRestOvertime {
            let seconds = workoutManager.restOvertimeSeconds
            let minutes = max(seconds, 0) / 60
            let secs = max(seconds, 0) % 60
            return String(format: "+%02d:%02d", minutes, secs)
        }
        let seconds = workoutManager.restRemainingSeconds
        let minutes = max(seconds, 0) / 60
        let secs = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let total = max(seconds, 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

}

// MARK: - Setup Surf / Kitesurf (paridade com sessão Surf)

/// Mesmo fluxo para Surf e Kitesurf: escolhe setup leve e inicia sessão livre.
private struct WaterSportWatchStartView: View {
    let activity: WatchCatalog.CardioActivity
    let onStart: (_ modeName: String, _ boardName: String) -> Void

    @State private var selectedMode: WatchCatalog.WaterRideOption?
    @State private var selectedBoard: WatchCatalog.WaterRideOption?

    private var modeOptions: [WatchCatalog.WaterRideOption] {
        activity.isKitesurf ? WatchCatalog.kiteRidingModes : WatchCatalog.surfBoards
    }

    private var boardOptions: [WatchCatalog.WaterRideOption] {
        activity.isKitesurf ? WatchCatalog.kiteBoards : []
    }

    private var modeSectionTitle: String {
        activity.isKitesurf ? "Modo de velejo" : "Tipo de prancha"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Label(activity.name, systemImage: activity.icon)
                        .font(.headline)
                        .foregroundStyle(.cyan)
                    Text(activity.isKitesurf
                          ? "Mesmas funções do Surf: saltos, sensores, sync iPhone, pausar e encerrar."
                          : "Sessão livre com saltos opcionais (giroscópio) e sync com o iPhone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section(modeSectionTitle) {
                ForEach(modeOptions) { option in
                    Button {
                        selectedMode = option
                    } label: {
                        HStack {
                            Label(option.name, systemImage: option.icon)
                                .font(.caption)
                            Spacer()
                            if selectedMode?.id == option.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.cyan)
                                    .font(.caption)
                            }
                        }
                    }
                }
                if selectedMode == nil {
                    Text("Toque para escolher (opcional)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            if activity.isKitesurf, !boardOptions.isEmpty {
                Section("Prancha") {
                    ForEach(boardOptions) { option in
                        Button {
                            selectedBoard = option
                        } label: {
                            HStack {
                                Label(option.name, systemImage: option.icon)
                                    .font(.caption)
                                Spacer()
                                if selectedBoard?.id == option.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.cyan)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    onStart(
                        selectedMode?.name ?? (activity.isKitesurf ? "Big Air" : "Shortboard"),
                        selectedBoard?.name ?? (activity.isKitesurf ? "Twin Tip" : "")
                    )
                } label: {
                    Label(
                        activity.isKitesurf ? "Iniciar Kitesurf" : "Iniciar Surf",
                        systemImage: "play.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .tint(.cyan)
            } footer: {
                Text("Sessão livre · sensors de salto iguais ao Surf · métricas no iPhone pareado.")
                    .font(.system(size: 10))
            }
        }
        .navigationTitle(activity.name)
        .onAppear {
            if selectedMode == nil {
                selectedMode = modeOptions.first
            }
            if activity.isKitesurf, selectedBoard == nil {
                selectedBoard = boardOptions.first
            }
        }
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchWorkoutManager())
}
