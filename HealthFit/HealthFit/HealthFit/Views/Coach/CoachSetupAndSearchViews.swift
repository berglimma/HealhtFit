import SwiftUI

struct CoachProfileSetupView: View {
    var onSaved: () -> Void
    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var asPersonal = true
    @State private var asNutritionist = false
    @State private var cref = ""
    @State private var crn = ""
    @State private var city = ""
    @State private var stateCode = ""
    @State private var bio = ""
    @State private var directoryVisible = false
    @State private var resolvedPhotoURL: String?
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    DuoMemberAvatarView(
                        name: displayName.isEmpty ? "Coach" : displayName,
                        photoURL: resolvedPhotoURL ?? coach.myProfile?.photoURL,
                        localImage: authService.profileImage,
                        size: 64
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Foto do perfil")
                            .font(.subheadline.weight(.semibold))
                        Text("Usamos a mesma foto do seu perfil no HealthFit. Altere em Perfil se quiser atualizar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                TextField("Nome profissional", text: $displayName)
                    .textContentType(.name)
            } header: {
                Text("Identificação")
            } footer: {
                Text("Nome e foto que o aluno verá no vínculo, nas fichas, na busca e no chat.")
            }

            Section {
                Toggle("Personal trainer", isOn: $asPersonal)
                Toggle("Nutricionista", isOn: $asNutritionist)
            } header: {
                Text("Profissão")
            } footer: {
                Text("Marque só o que você exerce. Personal exige CREF; nutricionista exige CRN. Não precisa dos dois se for apenas uma área.")
            }

            if asPersonal {
                Section("CREF (personal)") {
                    TextField("Ex.: 012345-G/SP", text: $cref)
                        .textInputAutocapitalization(.characters)
                }
            }
            if asNutritionist {
                Section("CRN (nutricionista)") {
                    TextField("Ex.: 12345", text: $crn)
                        .textInputAutocapitalization(.characters)
                }
            }

            Section("Localidade (busca regional)") {
                TextField("Cidade", text: $city)
                TextField("UF (ex.: RJ)", text: $stateCode)
                    .textInputAutocapitalization(.characters)
                Toggle("Aparecer na busca de alunos", isOn: $directoryVisible)
            }

            Section("Sobre você") {
                TextField("Bio curta", text: $bio, axis: .vertical)
                    .lineLimit(3...5)
            }

            if let error {
                Text(error).foregroundStyle(.red)
            }

            Button(isSaving ? "Salvando…" : "Salvar perfil profissional") {
                Task { await save() }
            }
            .disabled(isSaving || (!asPersonal && !asNutritionist) || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("Perfil Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
            }
        }
        .onAppear(perform: prefill)
        .task { await loadProfilePhoto() }
        .onChange(of: asPersonal) { _, enabled in
            if !enabled { cref = "" }
        }
        .onChange(of: asNutritionist) { _, enabled in
            if !enabled { crn = "" }
        }
    }

    private func prefill() {
        let user = authService.currentUser
        let role = user?.accountRole ?? .student
        asPersonal = role.isPersonalProfessional
        asNutritionist = role.isNutritionProfessional
        displayName = user?.greetingName.isEmpty == false
            ? (user?.greetingName ?? "")
            : (user?.name ?? "")
        if let profile = coach.myProfile {
            displayName = profile.displayName
            cref = profile.cref ?? ""
            crn = profile.crn ?? ""
            city = profile.city
            stateCode = profile.stateCode
            bio = profile.bio
            directoryVisible = profile.isDirectoryVisible
            asPersonal = profile.professions.contains(.personal)
            asNutritionist = profile.professions.contains(.nutritionist)
            resolvedPhotoURL = profile.photoURL
        }
    }

    private func loadProfilePhoto() async {
        guard let uid = authService.currentUser?.id else { return }
        if let url = await CoachService.resolveCoachPhotoURL(userId: uid) {
            resolvedPhotoURL = url
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        error = nil

        var professions: [CoachProfession] = []
        if asPersonal { professions.append(.personal) }
        if asNutritionist { professions.append(.nutritionist) }

        guard !professions.isEmpty else {
            error = "Selecione ao menos uma profissão."
            return
        }
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = "Informe o nome profissional."
            return
        }
        if asPersonal && cref.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = "Informe o CREF para personal. CRN não é necessário se você não for nutricionista."
            return
        }
        if asNutritionist && crn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = "Informe o CRN para nutricionista. CREF não é necessário se você não for personal."
            return
        }

        let ok = await coach.saveProfessionalProfile(
            displayName: displayName,
            professions: professions,
            cref: asPersonal ? cref : nil,
            crn: asNutritionist ? crn : nil,
            city: city,
            stateCode: stateCode,
            bio: bio,
            specialties: [],
            isDirectoryVisible: directoryVisible
        )
        if ok {
            onSaved()
            dismiss()
        } else {
            error = coach.lastError ?? "Não foi possível salvar."
        }
    }
}

struct CoachInviteCreateView: View {
    @ObservedObject private var coach = CoachService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var profession: CoachProfession = .personal
    @State private var created: CoachInvite?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Tipo de vínculo") {
                Picker("Profissão", selection: $profession) {
                    Text(CoachProfession.personal.title).tag(CoachProfession.personal)
                    Text(CoachProfession.nutritionist.title).tag(CoachProfession.nutritionist)
                }
                .pickerStyle(.segmented)
            }

            if let created {
                Section("Código para o aluno") {
                    Text(created.code)
                        .font(.largeTitle.bold().monospaced())
                        .frame(maxWidth: .infinity)
                    Text("Válido por 7 dias. O aluno entra em Coach → Entrar com código.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ShareLink(item: "Seu código HealthFit Coach: \(created.code)")
                }
            }

            if let error {
                Text(error).foregroundStyle(.red)
            }

            Button("Gerar convite") {
                Task {
                    if let invite = await coach.createStudentInvite(profession: profession) {
                        created = invite
                        error = nil
                    } else {
                        error = coach.lastError
                    }
                }
            }
        }
        .navigationTitle("Convidar aluno")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
            }
        }
    }
}

struct CoachSearchView: View {
    @ObservedObject private var coach = CoachService.shared
    @State private var nameQuery = ""
    @State private var city = ""
    @State private var stateCode = ""
    @State private var profession: CoachProfession? = .personal
    @State private var results: [CoachProfessionalProfile] = []
    @State private var isLoading = false
    @State private var didSearch = false

    var body: some View {
        List {
            Section {
                TextField("Nome do profissional", text: $nameQuery)
                    .textContentType(.name)
                TextField("Cidade", text: $city)
                TextField("UF", text: $stateCode)
                    .textInputAutocapitalization(.characters)
                Picker("Profissão", selection: Binding(
                    get: { profession ?? .personal },
                    set: { profession = $0 }
                )) {
                    Text("Personal").tag(CoachProfession.personal)
                    Text("Nutricionista").tag(CoachProfession.nutritionist)
                }
                Button(isLoading ? "Buscando…" : "Buscar") {
                    Task { await runSearch() }
                }
                .disabled(isLoading)
            } header: {
                Text("Filtros")
            } footer: {
                Text("Busque por nome, cidade e/ou UF. Só aparecem profissionais com perfil visível na busca.")
            }

            Section("Resultados") {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Buscando…")
                            .foregroundStyle(.secondary)
                    }
                } else if results.isEmpty {
                    Text(didSearch
                          ? "Nenhum profissional encontrado com esses filtros."
                          : "Faça uma busca para ver profissionais.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { profile in
                        CoachSearchResultCard(profile: profile)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .navigationTitle("Buscar Coach")
    }

    private func runSearch() async {
        isLoading = true
        defer {
            isLoading = false
            didSearch = true
        }
        results = await coach.searchCoaches(
            name: nameQuery.isEmpty ? nil : nameQuery,
            city: city.isEmpty ? nil : city,
            stateCode: stateCode.isEmpty ? nil : stateCode,
            profession: profession
        )
    }
}

struct CoachSearchResultCard: View {
    let profile: CoachProfessionalProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                DuoMemberAvatarView(
                    name: profile.displayName,
                    photoURL: profile.photoURL,
                    size: 56
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)

                    Text(profile.formationSummary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    ForEach(profile.credentialLines, id: \.self) { line in
                        Text(line)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    if profile.credentialLines.isEmpty {
                        Text(profile.credentialSummary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Text(profile.locationLabel)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
            }

            Text("Peça o código de convite ao profissional para vincular.")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.15), lineWidth: 1)
        )
    }
}
