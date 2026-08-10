import SwiftUI

struct DuoTeamChatView: View {
    let teamId: String
    let teamName: String
    @ObservedObject private var duoService = DuoTeamService.shared
    @State private var draft = ""
    @State private var showSchedule = false
    @State private var scheduleDate = Calendar.current.date(
        byAdding: .day, value: 1, to: Date()
    ) ?? Date()
    @State private var scheduleNote = ""

    private var messages: [DuoChatMessage] {
        duoService.messagesByTeam[teamId] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(DuoTeamChatPolicy.purposeNotice)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Sem localização em tempo real.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.accent.opacity(0.12))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    showSchedule = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                }
                .accessibilityLabel("Propor horário de treino")

                TextField("Só atividades físicas…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    Task {
                        let text = draft
                        draft = ""
                        await duoService.sendText(teamId: teamId, text: text)
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.accent)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(AppTheme.background)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(teamName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            duoService.startListening(teamId: teamId)
        }
        .onDisappear {
            duoService.stopListening(teamId: teamId)
        }
        .task {
            await duoService.loadMessages(teamId: teamId)
        }
        .sheet(isPresented: $showSchedule) {
            NavigationStack {
                Form {
                    Section("Marcar treino") {
                        DatePicker("Quando", selection: $scheduleDate)
                        TextField("Observação (opcional)", text: $scheduleNote)
                    }
                    Section {
                        Text("Só para marcar atividades físicas. A mensagem expira em 24 horas. Sem mapa e sem localização ao vivo.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Propor treino")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showSchedule = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Enviar") {
                            Task {
                                await duoService.sendScheduleProposal(
                                    teamId: teamId,
                                    when: scheduleDate,
                                    note: scheduleNote
                                )
                                scheduleNote = ""
                                showSchedule = false
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: DuoChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.kind != .system {
                Text(message.senderName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(message.kind == .system ? AppTheme.textSecondary : AppTheme.textPrimary)
                .padding(10)
                .background(bubbleBackground(for: message))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: message.kind == .system ? .center : .leading)
    }

    private func bubbleBackground(for message: DuoChatMessage) -> Color {
        switch message.kind {
        case .system:
            return Color.clear
        case .scheduleProposal:
            return AppTheme.accent.opacity(0.18)
        case .text:
            return Color(.secondarySystemBackground)
        }
    }
}
