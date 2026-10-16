import SwiftUI
import UIKit

struct StudyFocusHubRoute: Hashable {}

struct StudyFocusHubView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var watchConnectivity: WatchConnectivityManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    @StateObject private var store = StudyFocusStore.shared
    @State private var selectedChoice: StudyFocusDurationChoice = .minutes(30)
    @State private var customMinutes: Int = 45
    @State private var showCustomDuration = false
    @State private var customMinutesDraft: String = "45"
    @State private var selectedCardId: UUID?
    @State private var editorCard: StudyFocusCard?
    @State private var showEditor = false
    /// Após Fechar no resumo (host do MainTab), volta à lista de meditação.
    @State private var popWhenHostCloses = false

    private var baseTopic: MeditationTopic { StudyFocusStore.studyTopic }

    private var selectedMinutes: Int {
        switch selectedChoice {
        case .minutes(let m): return max(1, m)
        case .custom: return max(1, customMinutes)
        }
    }

    private var selectedCard: StudyFocusCard? {
        if let id = selectedCardId { return store.card(id: id) }
        return store.cards.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                header
                durationSection
                cardsSection
                startButton
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("Foco em Estudo")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorCard = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Novo card de estudo")
            }
        }
        .onAppear {
            if selectedCardId == nil {
                selectedCardId = store.cards.first?.id
            }
        }
        .sheet(isPresented: $showEditor) {
            StudyFocusCardEditor(
                card: editorCard,
                onSave: { card in
                    if editorCard != nil {
                        store.update(card)
                        selectedCardId = card.id
                    } else {
                        let created = store.create(
                            name: card.name,
                            note: card.note,
                            priorities: card.priorities,
                            notifyPriorities: card.notifyPriorities
                        )
                        selectedCardId = created.id
                    }
                    showEditor = false
                },
                onDelete: { id in
                    store.delete(id: id)
                    if selectedCardId == id {
                        selectedCardId = store.cards.first?.id
                    }
                    showEditor = false
                }
            )
        }
        .alert("Duração personalizada", isPresented: $showCustomDuration) {
            TextField("Minutos", text: $customMinutesDraft)
                .keyboardType(.numberPad)
            Button("Cancelar", role: .cancel) {}
            Button("Usar") {
                let parsed = Int(customMinutesDraft.trimmingCharacters(in: .whitespacesAndNewlines)) ?? customMinutes
                customMinutes = min(max(parsed, 1), 12 * 60)
                selectedChoice = .custom
            }
        } message: {
            Text("Informe a duração em minutos (1–720).")
        }
        // Sessão roda só no overlay do MainTab. Ao Fechar o resumo, volta à lista de meditação.
        .onChange(of: workoutStore.activeWorkoutUICloseTick) { _, _ in
            guard popWhenHostCloses else { return }
            popWhenHostCloses = false
            NotificationService.shared.cancelStudyFocusPriorityReminders()
            UIApplication.shared.isIdleTimerDisabled = false
            dismiss()
        }
    }

    private var heroCard: some View {
        WorkoutProgramHeroCard(
            title: "Foco em Estudo",
            subtitle: "Sessões longas com prioridades, tela acesa e lembretes do IAssistente.",
            accent: baseTopic.color,
            imageName: "StudyFocusCover",
            systemImage: "book.fill",
            coverColors: baseTopic.coverColors,
            eyebrow: "ESTUDO",
            eyebrowSystemImage: "book.closed.fill",
            footerLabels: [
                (icon: "timer", text: StudyFocusDurationChoice.label(forMinutes: selectedMinutes)),
                (icon: "bell.badge.fill", text: "Prioridades"),
            ]
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Crie cards com o nome do que vai estudar, marque prioridades e receba lembretes durante a sessão.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Label("Tela permanece acesa · notificações de prioridade", systemImage: "bell.badge.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(baseTopic.color)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duração do foco")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(StudyFocusDurationChoice.presets) { choice in
                    let isSelected = selectedChoice == choice
                    Button {
                        if case .custom = choice {
                            customMinutesDraft = "\(customMinutes)"
                            showCustomDuration = true
                        } else {
                            selectedChoice = choice
                        }
                    } label: {
                        Text(choice.chipLabel(customMinutes: customMinutes))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 6)
                            .background(isSelected ? baseTopic.color : AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Seus cards")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button("Novo") {
                    editorCard = nil
                    showEditor = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(baseTopic.color)
            }

            if store.cards.isEmpty {
                Text("Nenhum card ainda. Crie um com o nome que desejar.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(store.cards) { card in
                    StudyFocusCardRow(
                        card: card,
                        selected: card.id == selectedCard?.id,
                        accent: baseTopic.color,
                        onSelect: { selectedCardId = card.id },
                        onEdit: {
                            editorCard = card
                            showEditor = true
                        }
                    )
                }
            }
        }
    }

    private var startButton: some View {
        Button {
            guard let card = selectedCard else { return }
            let topic = card.asMeditationTopic(base: baseTopic)
            var config = MeditationWorkoutConfig(topic: topic, duration: .twenty)
            config.titlePrefix = "Estudo"
            config.customTargetSeconds = selectedMinutes * 60
            guard workoutStore.startMeditationSession(config: config) else { return }
            watchConnectivity.startMeditationOnWatch(
                workoutName: config.title,
                targetSeconds: config.targetDurationSeconds,
                topicName: topic.name,
                topicIcon: topic.icon,
                colorName: topic.colorName,
                currentPrompt: topic.prompts.first ?? "",
                promptIndex: 0,
                totalPrompts: topic.prompts.count
            )
            NotificationService.shared.requestAuthorization()
            NotificationService.shared.deliverStudyFocusStartNotification(
                cardName: card.name,
                topPriority: card.priorities.first?.title
            )
            if card.notifyPriorities {
                NotificationService.shared.scheduleStudyFocusPriorityReminders(
                    cardName: card.name,
                    priorities: card.priorities,
                    sessionMinutes: selectedMinutes
                )
            }
            UIApplication.shared.isIdleTimerDisabled = true
            popWhenHostCloses = true
        } label: {
            Label("Iniciar foco em estudo", systemImage: "play.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(selectedCard == nil)
        .opacity(selectedCard == nil ? 0.5 : 1)
    }
}

private struct StudyFocusCardRow: View {
    let card: StudyFocusCard
    let selected: Bool
    let accent: Color
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    if !card.note.isEmpty {
                        Text(card.note)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }
                    Text(prioritySummary)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                }
                Spacer(minLength: 0)
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(selected ? accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var prioritySummary: String {
        let count = card.priorities.count
        if count == 0 { return card.notifyPriorities ? "Sem prioridades · avisos ativos" : "Sem prioridades" }
        let high = card.priorities.filter { $0.level == .high }.count
        var parts = ["\(count) prioridade\(count == 1 ? "" : "s")"]
        if high > 0 { parts.append("\(high) alta") }
        if card.notifyPriorities { parts.append("notificações") }
        return parts.joined(separator: " · ")
    }
}

private struct StudyFocusCardEditor: View {
    @Environment(\.dismiss) private var dismiss
    let card: StudyFocusCard?
    let onSave: (StudyFocusCard) -> Void
    let onDelete: (UUID) -> Void

    @State private var name: String = ""
    @State private var note: String = ""
    @State private var priorities: [StudyPriorityItem] = []
    @State private var notifyPriorities = true
    @State private var draftPriority = ""
    @State private var draftLevel: StudyPriorityLevel = .high
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    TextField("Nome do card", text: $name)
                    TextField("Nota (opcional)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                    Toggle("Notificar prioridades na sessão", isOn: $notifyPriorities)
                }

                Section("Prioridades") {
                    ForEach(priorities) { item in
                        HStack {
                            Image(systemName: item.level.icon)
                                .foregroundStyle(levelColor(item.level))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                Text(item.level.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                priorities.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    TextField("Nova prioridade", text: $draftPriority)
                    Picker("Nível", selection: $draftLevel) {
                        ForEach(StudyPriorityLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    Button("Adicionar prioridade") {
                        let trimmed = draftPriority.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        priorities.append(StudyPriorityItem(title: trimmed, level: draftLevel))
                        draftPriority = ""
                    }
                }

                if card != nil {
                    Section {
                        Button("Excluir card", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(card == nil ? "Novo card" : "Editar card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        var next = card ?? StudyFocusCard(name: name)
                        next.name = name
                        next.note = note
                        next.priorities = priorities
                        next.notifyPriorities = notifyPriorities
                        onSave(next)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let card {
                    name = card.name
                    note = card.note
                    priorities = card.priorities
                    notifyPriorities = card.notifyPriorities
                }
            }
            .confirmationDialog("Excluir este card?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Excluir", role: .destructive) {
                    if let id = card?.id { onDelete(id) }
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    private func levelColor(_ level: StudyPriorityLevel) -> Color {
        switch level {
        case .high: return .orange
        case .medium: return AppTheme.accent
        case .low: return .secondary
        }
    }
}
