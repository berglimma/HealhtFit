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
            ForEach(WatchCatalog.cardioActivities) { activity in
                NavigationLink {
                    cardioDurationPicker(activity: activity)
                } label: {
                    Label(activity.name, systemImage: activity.icon)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Cardio")
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
            activeWorkoutTab
            metricsTab
        }
        .tabViewStyle(.verticalPage)
    }

    private var activeWorkoutTab: some View {
        VStack(spacing: 10) {
            Text(workoutManager.workoutName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

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

            Button("Encerrar") {
                workoutManager.stopWorkout()
            }
            .tint(.red)
            .font(.caption2)
        }
        .padding()
    }

    private var strengthSection: some View {
        VStack(spacing: 6) {
            Label("Cronômetro", systemImage: "stopwatch.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(formatDuration(workoutManager.workoutElapsedSeconds))
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(.green)
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
                waterSportCardioExtras
            }
            if workoutManager.isSwimmingMode {
                swimmingCardioExtras
            }

            if hasCalorieGoal {
                Label("Meta calórica", systemImage: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)

                Text("\(Int(workoutManager.calories))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(workoutManager.calories >= Double(workoutManager.cardioTargetCalories) ? .orange : .primary)

                Text("de \(workoutManager.cardioTargetCalories) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ProgressView(value: calorieProgress)
                    .tint(workoutManager.calories >= Double(workoutManager.cardioTargetCalories) ? .orange : .orange.opacity(0.8))

                if !workoutManager.cardioSuperationMessage.isEmpty {
                    Text(workoutManager.cardioSuperationMessage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            } else {
                Label("Cronômetro", systemImage: "stopwatch.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(formatDuration(workoutManager.workoutElapsedSeconds))
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if workoutManager.cardioTargetSeconds > 0 {
                    Text("Meta: \(formatDuration(workoutManager.cardioTargetSeconds))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ProgressView(
                        value: Double(workoutManager.workoutElapsedSeconds),
                        total: Double(workoutManager.cardioTargetSeconds)
                    )
                    .tint(.orange)
                }
            }

            Text(formatDuration(workoutManager.workoutElapsedSeconds))
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            if !workoutManager.currentExerciseName.isEmpty {
                Text(workoutManager.currentExerciseName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }

    private var swimmingCardioExtras: some View {
        VStack(spacing: 4) {
            Label("Natação", systemImage: "figure.pool.swim")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.cyan)

            HStack(spacing: 12) {
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

    private var waterSportCardioExtras: some View {
        VStack(spacing: 6) {
            Label(
                workoutManager.isKitesurfMode ? "Kitesurf" : "Surf",
                systemImage: workoutManager.isKitesurfMode
                    ? "wind"
                    : "figure.surfing"
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.cyan)

            HStack(spacing: 10) {
                VStack(spacing: 1) {
                    Text("\(workoutManager.waterJumpCount)")
                        .font(.title3.bold())
                    Text("saltos")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", workoutManager.waterMaxJumpMeters))
                        .font(.title3.bold())
                    Text("m max")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", workoutManager.waterLiveAccelG))
                        .font(.title3.bold())
                    Text("g")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Button("Marcar salto") {
                workoutManager.markWaterSportJump()
            }
            .tint(.orange)
            .font(.caption2)

            Button("Sincronizar") {
                workoutManager.requestPhoneSyncFromWatch()
            }
            .font(.caption2)

            if !workoutManager.watchSyncStatus.isEmpty {
                Text(workoutManager.watchSyncStatus)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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

    private var metricsTab: some View {
        VStack(spacing: 8) {
            Label(
                workoutManager.isPhoneReachable ? "Sincronizado com iPhone" : "Sessão no Watch",
                systemImage: workoutManager.isPhoneReachable
                    ? "iphone.and.arrow.forward"
                    : "applewatch"
            )
            .font(.caption)
            Text("Treino, cardio e meditação podem ser iniciados no próprio relógio.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchWorkoutManager())
}
