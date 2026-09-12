import SwiftUI

/// Personal busca alunos no diretório e, se não tiverem personal, envia mensagem motivacional de interesse.
struct CoachStudentSearchView: View {
    @ObservedObject private var coach = CoachService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var searchResults: [UserDirectoryEntry] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var statusMessage: String?
    @State private var sendingUid: String?
    @State private var composeFor: UserDirectoryEntry?
    @State private var customMessage = ""

    var body: some View {
        Form {
            Section {
                Text("Busque alunos pelo nome, apelido ou e-mail. Resultados do seu país aparecem primeiro; em seguida, outros países. Se a pessoa ainda não tem personal, você pode enviar uma mensagem motivacional com seu interesse e um código de vínculo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Buscar alunos") {
                HStack {
                    TextField("Nome, apelido ou e-mail", text: $searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await runSearch() } }
                    if isSearching {
                        ProgressView()
                    } else {
                        Button {
                            Task { await runSearch() }
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                    }
                }

                if let searchError {
                    Text(searchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    Text("Digite pelo menos 2 letras.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !isSearching && searchResults.isEmpty && !searchQuery.isEmpty {
                    Text("Nenhum aluno encontrado com este termo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(searchResults) { user in
                    studentRow(user)
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .navigationTitle("Buscar alunos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
            }
        }
        .sheet(item: $composeFor) { student in
            NavigationStack {
                Form {
                    Section("Para") {
                        Text(student.shownName)
                            .font(.headline)
                    }
                    Section {
                        TextEditor(text: $customMessage)
                            .frame(minHeight: 120)
                    } header: {
                        Text("Mensagem motivacional")
                    } footer: {
                        Text("Deixe em branco para usar o texto padrão. Um código de convite é anexado automaticamente.")
                    }
                }
                .navigationTitle("Enviar interesse")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { composeFor = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Enviar") {
                            Task {
                                let ok = await coach.sendMotivationalInterest(
                                    to: student,
                                    customText: customMessage
                                )
                                composeFor = nil
                                statusMessage = ok
                                    ? "Mensagem enviada para \(student.shownName)."
                                    : (coach.lastError ?? "Não foi possível enviar.")
                            }
                        }
                        .disabled(sendingUid != nil)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func studentRow(_ user: UserDirectoryEntry) -> some View {
        HStack(spacing: 12) {
            DuoMemberAvatarView(
                name: user.shownName,
                photoURL: user.photoURL,
                countryCode: user.countryCode,
                size: 48
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.shownName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    if user.flagEmoji != "🏳️" {
                        Text(user.flagEmoji)
                    }
                }
                Text(user.detailLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                Text(user.hasPersonalTrainer ? "Já possui personal" : "Sem personal no app")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(user.hasPersonalTrainer ? .orange : AppTheme.accent)
            }
            Spacer()
            if sendingUid == user.uid {
                ProgressView()
            } else if user.hasPersonalTrainer {
                Image(systemName: "person.fill.checkmark")
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    customMessage = ""
                    composeFor = user
                } label: {
                    Image(systemName: "hand.wave.fill")
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Enviar mensagem motivacional")
            }
        }
        .padding(.vertical, 4)
    }

    private func runSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return }
        isSearching = true
        searchError = nil
        statusMessage = nil
        searchResults = await coach.searchStudents(query: query)
        isSearching = false
        if searchResults.isEmpty, let err = coach.lastError {
            searchError = err
        }
    }
}
