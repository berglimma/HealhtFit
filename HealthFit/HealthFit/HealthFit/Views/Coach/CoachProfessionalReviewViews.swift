import Charts
import FirebaseFirestore
import PhotosUI
import SwiftUI

// MARK: - Resumo IAssistente para o profissional

struct CoachProfessionalReviewView: View {
    let link: CoachLink

    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService
    @State private var snapshot: ProfessionalReviewSnapshot?
    @State private var statusMessage: String?
    @State private var isLoading = true
    @State private var todayPhotos: [DailyMealPhotoShare] = []
    @State private var photoListener: ListenerRegistration?
    @State private var viewingPhoto: DailyMealPhotoShare?
    @State private var loadedImage: UIImage?

    var body: some View {
        List {
            Section {
                Text("Indicadores gerados pelo IAssistente a partir de nutrição, sono, treino, peso, medidas e metas do profissional. Não constitui diagnóstico.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                Section { ProgressView("Carregando resumo…") }
            } else if let snapshot {
                Section("Indicadores") {
                    metricRow("Adesão alimentar", "\(snapshot.mealAdherencePercent)%")
                    metricRow("Proteína média", "\(snapshot.averageProteinGramsPerDay) g/dia")
                    metricRow("Meta", "\(snapshot.proteinGoalGramsPerDay) g/dia")
                    metricRow("Sono médio", snapshot.sleepFormatted)
                    metricRow("Treinos realizados", "\(snapshot.workoutsCompleted)/\(snapshot.workoutsExpected)")
                    metricRow("Peso", snapshot.weightDeltaLabel)
                    metricRow("Circunferência abdominal", snapshot.waistDeltaLabel)
                    Text("Atualizado \(snapshot.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("Pontos que merecem revisão pelo profissional") {
                    ForEach(snapshot.reviewPoints, id: \.self) { point in
                        Label(point, systemImage: "exclamationmark.bubble")
                            .font(.subheadline)
                    }
                }

                if !snapshot.professionalGoals.isEmpty {
                    Section("Metas do profissional") {
                        ForEach(snapshot.professionalGoals, id: \.self) { Text($0) }
                    }
                }

                if !snapshot.dataSources.isEmpty {
                    Section("Fontes cruzadas") {
                        Text(snapshot.dataSources.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    Text("Ainda sem resumo do aluno. Peça para abrir o app (o IAssistente publica automaticamente).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if todayPhotos.isEmpty {
                    Text("Nenhuma foto nutricional pendente hoje. Após visualizada, a foto é apagada.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todayPhotos) { photo in
                        Button {
                            Task { await openPhoto(photo) }
                        } label: {
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundStyle(AppTheme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(photo.mealLabel.isEmpty ? "Refeição do dia" : photo.mealLabel)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(photo.createdAt.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("Ver 1×")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.accentSecondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Nutrição fotográfica do dia")
            } footer: {
                Text("O nutricionista visualiza apenas no dia. Depois de abrir, a foto é excluída.")
            }

            if let statusMessage {
                Section { Text(statusMessage).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Revisão IAssistente")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onAppear { startPhotoListener() }
        .onDisappear { stopPhotoListener() }
        .sheet(item: $viewingPhoto) { photo in
            NavigationStack {
                VStack(spacing: 12) {
                    if let loadedImage {
                        Image(uiImage: loadedImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ProgressView("Carregando foto…")
                    }
                    if !photo.note.isEmpty {
                        Text(photo.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Ao fechar, esta foto será apagada.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accentSecondary)
                    Spacer()
                }
                .padding()
                .navigationTitle(photo.mealLabel.isEmpty ? "Foto do dia" : photo.mealLabel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fechar e apagar") {
                            Task { await closeAndDelete(photo) }
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppTheme.accent)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        snapshot = try? await ProfessionalReviewFirestoreService.fetchReview(linkId: link.id)
    }

    private func startPhotoListener() {
        stopPhotoListener()
        photoListener = ProfessionalReviewFirestoreService.listenTodayPhotos(linkId: link.id) { items in
            Task { @MainActor in todayPhotos = items }
        }
    }

    private func stopPhotoListener() {
        photoListener?.remove()
        photoListener = nil
    }

    private func openPhoto(_ photo: DailyMealPhotoShare) async {
        viewingPhoto = photo
        loadedImage = nil
        guard let urlString = photo.downloadURL, let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            loadedImage = UIImage(data: data)
        } catch {
            statusMessage = "Não foi possível carregar a foto."
        }
    }

    private func closeAndDelete(_ photo: DailyMealPhotoShare) async {
        let uid = authService.currentUser?.id ?? ""
        try? await ProfessionalReviewFirestoreService.markPhotoViewedAndDelete(photo, viewerUid: uid)
        viewingPhoto = nil
        loadedImage = nil
        statusMessage = "Foto visualizada e removida."
        todayPhotos.removeAll { $0.id == photo.id }
    }
}

// MARK: - Aluno envia foto do dia

struct StudentDailyMealPhotoShareView: View {
    let link: CoachLink

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var mealLabel = "Almoço"
    @State private var note = ""
    @State private var isUploading = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                Text("A nutricionista vê a foto só hoje. Depois de abrir, ela é apagada automaticamente.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Refeição") {
                TextField("Ex.: Almoço, Jantar…", text: $mealLabel)
                TextField("Observação (opcional)", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section("Foto") {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(image == nil ? "Escolher foto" : "Trocar foto", systemImage: "camera.fill")
                }
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            if let statusMessage {
                Section { Text(statusMessage).font(.caption) }
            }
            Section {
                Button {
                    Task { await send() }
                } label: {
                    if isUploading { ProgressView() }
                    else { Text("Enviar para nutricionista") }
                }
                .disabled(image == nil || isUploading || mealLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Foto do dia")
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    image = ui
                }
            }
        }
    }

    private func send() async {
        guard let image else { return }
        isUploading = true
        defer { isUploading = false }
        do {
            _ = try await ProfessionalReviewFirestoreService.publishDailyMealPhoto(
                link: link,
                image: image,
                mealLabel: mealLabel,
                note: note
            )
            statusMessage = "Enviado. Disponível só hoje para a nutricionista."
            self.image = nil
            pickerItem = nil
            note = ""
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

// MARK: - Relatório de consultas / atendimento

struct CoachConsultationAttendanceReportView: View {
    @ObservedObject private var coach = CoachService.shared
    @EnvironmentObject private var authService: AuthService
    @State private var shareURL: URL?
    @State private var showShare = false

    private var bookings: [ConsultationBooking] {
        let uid = authService.currentUser?.id ?? ""
        return coach.myLinks
            .filter { $0.coachUid == uid }
            .flatMap { coach.consultationsByLink[$0.id] ?? [] }
    }

    private var report: ConsultationAttendanceReport {
        ConsultationAttendanceAnalyzer.buildReport(bookings: bookings, days: 30)
    }

    var body: some View {
        List {
            Section("Últimos 30 dias") {
                LabeledContent("Total", value: "\(report.totalBookings)")
                LabeledContent("Confirmadas", value: "\(report.confirmed)")
                LabeledContent("Concluídas", value: "\(report.completed)")
                LabeledContent("Canceladas", value: "\(report.cancelled)")
                LabeledContent("Taxa de conclusão", value: "\(report.showRatePercent)%")
            }

            Section("Atendimentos por dia da semana") {
                Chart(report.byWeekday) { row in
                    BarMark(
                        x: .value("Dia", row.label),
                        y: .value("Consultas", row.count)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                }
                .frame(height: 180)
                .listRowBackground(AppTheme.cardBackground)
            }

            Section("Volume diário") {
                Chart(report.byDay) { row in
                    LineMark(
                        x: .value("Dia", row.date),
                        y: .value("Consultas", row.count)
                    )
                    .foregroundStyle(AppTheme.accentSecondary)
                    AreaMark(
                        x: .value("Dia", row.date),
                        y: .value("Consultas", row.count)
                    )
                    .foregroundStyle(AppTheme.accentSecondary.opacity(0.2))
                }
                .frame(height: 160)
                .listRowBackground(AppTheme.cardBackground)
            }

            Section("Exportar") {
                Button {
                    exportPDF()
                } label: {
                    Label("Exportar relatório PDF", systemImage: "square.and.arrow.up")
                }
            }

            Section("Agendamentos recentes") {
                ForEach(report.recent.prefix(15)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.confirmedScheduleLabel)
                            .font(.subheadline.weight(.semibold))
                        Text("\(item.studentName) · \(item.status.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Relatório de consultas")
        .sheet(isPresented: $showShare) {
            if let shareURL {
                CoachShareSheetView(activityItems: [shareURL])
            }
        }
    }

    private func exportPDF() {
        let name = authService.currentUser?.greetingName.isEmpty == false
            ? (authService.currentUser?.greetingName ?? "Profissional")
            : (authService.currentUser?.name ?? "Profissional")
        let data = ConsultationReportPDFBuilder.buildPDF(report: report, coachName: name)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HealthFit-Consultas-\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        shareURL = url
        showShare = true
    }
}

/// UIKit share sheet wrapper.
struct CoachShareSheetView: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
