import SwiftUI

struct DuoTeamChatView: View {
    let teamId: String
    let teamName: String
    @ObservedObject private var duoService = DuoTeamService.shared
    @EnvironmentObject private var authService: AuthService
    @FocusState private var isComposerFocused: Bool

    @Environment(\.scenePhase) private var scenePhase

    @State private var draft = ""
    @State private var showSchedule = false
    @State private var scheduleDate = Calendar.current.date(
        byAdding: .day, value: 1, to: Date()
    ) ?? Date()
    @State private var scheduleNote = ""

    private var messages: [DuoChatMessage] {
        duoService.messagesByTeam[teamId] ?? []
    }

    private var lastMessageId: String? {
        messages.last?.id
    }

    private var currentUid: String? {
        authService.currentUser?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            policyBanner

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            messageRow(message, index: index)
                                .id(message.id)
                                .padding(.top, topSpacing(before: index))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: lastMessageId) { _, _ in
                    scrollToBottom(proxy: proxy, animated: true)
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy, animated: true)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }

            composerBar
        }
        .background(iMessageBackground.ignoresSafeArea())
        .navigationTitle(teamName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            duoService.restartListening(teamId: teamId)
        }
        .onDisappear {
            duoService.stopListening(teamId: teamId)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                duoService.restartListening(teamId: teamId)
                Task { await duoService.loadMessages(teamId: teamId) }
            }
        }
        .task(id: teamId) {
            duoService.restartListening(teamId: teamId)
            await duoService.loadMessages(teamId: teamId)
            // Backup leve enquanto a tela está aberta (caso o snapshot atrase).
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { break }
                await duoService.loadMessages(teamId: teamId)
            }
        }
        .sheet(isPresented: $showSchedule) {
            scheduleSheet
        }
    }

    // MARK: - Banner

    private var policyBanner: some View {
        Text("Só atividades físicas · mensagens expiram em 12h")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
    }

    // MARK: - Messages

    @ViewBuilder
    private func messageRow(_ message: DuoChatMessage, index: Int) -> some View {
        if message.kind == .system {
            systemMessage(message)
        } else {
            let isMine = message.senderUid == currentUid
            let showSender = shouldShowSender(at: index, isMine: isMine)

            HStack(alignment: .bottom, spacing: 0) {
                if isMine { Spacer(minLength: 56) }

                VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                    if showSender {
                        Text(message.senderName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                    }

                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(isMine ? Color.white : Color(red: 0.12, green: 0.14, blue: 0.15))
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(bubbleFill(for: message, isMine: isMine))
                        .clipShape(iMessageBubbleShape(isMine: isMine))

                    if shouldShowTimestamp(at: index) {
                        Text(message.createdAt, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                    }
                }
                .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)

                if !isMine { Spacer(minLength: 56) }
            }
            .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        }
    }

    private func systemMessage(_ message: DuoChatMessage) -> some View {
        Text(message.text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    /// Cinza claro do padrão Selfit/HealthFit (bolhas recebidas).
    private static let lightGrayBubble = Color(red: 0.90, green: 0.91, blue: 0.92)

    private func bubbleFill(for message: DuoChatMessage, isMine: Bool) -> Color {
        if message.kind == .scheduleProposal {
            return isMine
                ? AppTheme.accent
                : Self.lightGrayBubble
        }
        return isMine
            ? AppTheme.accent
            : Self.lightGrayBubble
    }

    private func iMessageBubbleShape(isMine: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: isMine ? 18 : 5,
            bottomTrailingRadius: isMine ? 5 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    private func shouldShowSender(at index: Int, isMine: Bool) -> Bool {
        guard !isMine else { return false }
        guard index > 0 else { return true }
        let previous = messages[index - 1]
        if previous.kind == .system { return true }
        return previous.senderUid != messages[index].senderUid
    }

    private func shouldShowTimestamp(at index: Int) -> Bool {
        let message = messages[index]
        guard message.kind != .system else { return false }
        guard index + 1 < messages.count else { return true }
        let next = messages[index + 1]
        if next.kind == .system { return true }
        if next.senderUid != message.senderUid { return true }
        return next.createdAt.timeIntervalSince(message.createdAt) > 3 * 60
    }

    private func topSpacing(before index: Int) -> CGFloat {
        guard index > 0 else { return 4 }
        let previous = messages[index - 1]
        let current = messages[index]
        if current.kind == .system || previous.kind == .system { return 12 }
        if previous.senderUid == current.senderUid,
           current.createdAt.timeIntervalSince(previous.createdAt) < 2 * 60 {
            return 3
        }
        return 10
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    // MARK: - Composer

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                showSchedule = true
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Propor horário de treino")

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Mensagem", text: $draft, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.15))
                    .lineLimit(1...5)
                    .focused($isComposerFocused)
                    .padding(.leading, 4)
                    .padding(.vertical, 6)

                Button {
                    sendDraft()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            Color.white,
                            canSend ? AppTheme.accent : Color(red: 0.70, green: 0.72, blue: 0.74)
                        )
                }
                .disabled(!canSend)
                .accessibilityLabel("Enviar")
            }
            .padding(.leading, 10)
            .padding(.trailing, 4)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(Self.lightGrayBubble)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.28), lineWidth: 0.8)
            )
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendDraft() {
        let text = draft
        draft = ""
        Task {
            await duoService.sendText(teamId: teamId, text: text)
        }
    }

    // MARK: - Background

    private var iMessageBackground: some View {
        ZStack {
            Color(uiColor: .systemGray6)
            LinearGradient(
                colors: [
                    AppTheme.accent.opacity(0.08),
                    Color(uiColor: .systemGray6),
                    Color(uiColor: .systemGray5).opacity(0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Schedule sheet

    private var scheduleSheet: some View {
        NavigationStack {
            Form {
                Section("Marcar treino") {
                    DatePicker("Quando", selection: $scheduleDate)
                    TextField("Observação (opcional)", text: $scheduleNote)
                }
                Section {
                    Text("Só para marcar atividades físicas. A mensagem expira em 12 horas. Sem mapa e sem localização ao vivo.")
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
