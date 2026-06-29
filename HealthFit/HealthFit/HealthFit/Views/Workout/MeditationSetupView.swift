import SwiftUI

struct MeditationSetupView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let topic: MeditationTopic
    @State private var selectedDuration: MeditationDuration = .ten
    @State private var showActiveMeditation = false

    private var config: MeditationWorkoutConfig {
        MeditationWorkoutConfig(topic: topic, duration: selectedDuration)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                durationSection
                promptsPreview
                startButton
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showActiveMeditation) {
            ActiveMeditationView(config: config)
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(topic.color.opacity(0.2))
                    .frame(width: 72, height: 72)
                Image(systemName: topic.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(topic.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(topic.name)
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(topic.description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Label("\(topic.prompts.count) etapas guiadas", systemImage: "text.quote")
                    .font(.caption)
                    .foregroundStyle(topic.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duração")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(MeditationDuration.allCases) { duration in
                    Button {
                        selectedDuration = duration
                    } label: {
                        Text(duration.label)
                            .font(.headline)
                            .foregroundStyle(selectedDuration == duration ? .white : AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(selectedDuration == duration ? topic.color : AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var promptsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tópicos da sessão")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(Array(topic.prompts.enumerated()), id: \.offset) { index, prompt in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(topic.color)
                        .clipShape(Circle())

                    Text(prompt)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var startButton: some View {
        Button {
            workoutStore.startMeditationSession(config: config)
            let firstPrompt = topic.prompts.first ?? ""
            watchConnectivity.startMeditationOnWatch(
                workoutName: config.title,
                targetSeconds: config.targetDurationSeconds,
                topicName: topic.name,
                topicIcon: topic.icon,
                colorName: topic.colorName,
                currentPrompt: firstPrompt,
                promptIndex: 0,
                totalPrompts: topic.prompts.count
            )
            let athleteName = authService.currentUser?.name ?? "Atleta"
            NotificationService.shared.deliverWorkoutStartNotification(
                workoutTitle: config.title,
                athleteName: athleteName
            )
            showActiveMeditation = true
        } label: {
            Label("Iniciar Meditação", systemImage: "play.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

struct MeditationTopicCard: View {
    let topic: MeditationTopic

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(topic.color.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: topic.icon)
                    .font(.title2)
                    .foregroundStyle(topic.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(topic.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(topic.description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}
