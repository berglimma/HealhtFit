import SwiftUI
import MessageUI
import CoreLocation

private struct TrainerMailDraft: Identifiable {
    let id = UUID()
    let recipients: [String]
    let subject: String
    let body: String
    var isHTML: Bool = false
    var attachments: [MailAttachment] = []
}

struct WorkoutSummaryView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var shareCardStore: WorkoutShareCardStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: WorkoutSession
    let onFinish: () -> Void
    /// Chamado ao tocar em Fechar — tipicamente volta à lista de treinos.
    var onReturnToWorkoutList: (() -> Void)? = nil

    @State private var mailDraft: TrainerMailDraft?
    @State private var pendingMailResult: MFMailComposeResult?
    @State private var showMailUnavailableAlert = false
    @State private var showEmailSentAlert = false
    @State private var showEmailFailedAlert = false
    @State private var emailWasSent = false
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isPreparingShare = false
    @State private var scrollToShareToken = 0

    // Mídia pós-treino (opcional — foto/vídeo com overlay estilo Strava)
    @State private var resultMedia: WorkoutResultPickedMedia?
    @State private var showMediaSourceDialog = false
    @State private var showMediaCameraPicker = false
    @State private var showMediaGalleryPicker = false
    @State private var showMediaVideoGalleryPicker = false
    @State private var showMediaVideoCameraPicker = false
    @State private var isPreparingMediaShare = false
    @State private var mediaLoadFailed = false
    @State private var pendingGalleryImage: UIImage?
    @State private var showSavePhotoToGalleryPrompt = false
    @State private var gallerySaveAlertTitle = ""
    @State private var gallerySaveAlertMessage = ""
    @State private var showGallerySaveAlert = false
    @State private var reportPDFURL: URL?
    @State private var showReportPDFShare = false
    @State private var pdfExportFailed = false

    private let shareCardAnchorID = "workoutShareCard"

    private var athleteDisplayName: String {
        authService.currentUser?.greetingName
            ?? authService.currentUser?.name
            ?? "Atleta"
    }

    private var shareMotivation: String {
        WorkoutShareCardRenderer.motivationLine(for: session)
    }

    private var isCardioSession: Bool {
        WorkoutReportBuilder.isCardioSession(session)
    }

    private var marathonReport: MarathonPerformanceReport? {
        MarathonReportBuilder.build(session: session, allSessions: workoutStore.sessionHistory)
    }

    private var surfKiteReport: SurfKiteComparisonReport? {
        SurfKiteReportBuilder.build(session: session, allSessions: workoutStore.sessionHistory)
    }

    private var waterSpotCoordinate: CLLocationCoordinate2D? {
        session.waterSport?.spot?.coordinate
    }

    private var shouldShowRouteMap: Bool {
        !session.routePoints.isEmpty
            || session.waterSport?.jumps.contains(where: { $0.coordinate != nil }) == true
            || waterSpotCoordinate != nil
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        summaryHeader
                        if session.endedEarly {
                            earlyEndSection
                        }
                        if let user = authService.currentUser,
                           user.bodyMeasurements.hasAnyValue {
                            bodyMeasurementsSection(user: user)
                        }
                        if session.targetCalories != nil {
                            calorieGoalResultSection
                        }
                        if marathonReport != nil {
                            marathonPerformanceSection
                        }
                        if let surfKiteReport {
                            surfKitePerformanceSection(report: surfKiteReport)
                        }
                        if let rowing = session.rowing {
                            rowingPerformanceSection(rowing)
                        }
                        if shouldShowRouteMap {
                            runRouteSection
                        }
                        // Musculação-only: pré-treino, breakdown por exercício e totais de força.
                        if !isCardioSession {
                            preWorkoutSection
                            exerciseBreakdown
                            totalsSection
                        }
                        emailSection
                        shareAchievementSection
                            .id(shareCardAnchorID)
                        workoutResultMediaSection
                        finishButton
                    }
                    .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                    .adaptiveContentWidth()
                }
                .background(AppTheme.background)
                .navigationTitle(session.endedEarly ? "Treino Encerrado" : "Treino Concluído")
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: scrollToShareToken) { _, _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(shareCardAnchorID, anchor: .center)
                    }
                }
            }
            .onAppear {
                shareCardStore.remember(
                    session: session,
                    athleteName: athleteDisplayName,
                    motivationLine: shareMotivation,
                    recentSessions: workoutStore.sessionHistory,
                    profileImage: authService.profileImage
                )
                // Early end: bring the share card into view (section is below email / totals).
                if session.endedEarly {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        focusShareCard()
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityShareSheet(items: shareItems) {
                showShareSheet = false
            }
        }
        .confirmationDialog(
            "Adicionar mídia do treino",
            isPresented: $showMediaSourceDialog,
            titleVisibility: .visible
        ) {
            if PhotoCaptureAvailability.isCameraAvailable {
                Button("Câmera") {
                    DispatchQueue.main.async { showMediaCameraPicker = true }
                }
            }
            Button("Galeria") {
                DispatchQueue.main.async { showMediaGalleryPicker = true }
            }
            Button("Vídeo") {
                DispatchQueue.main.async { showMediaVideoGalleryPicker = true }
            }
            if PhotoCaptureAvailability.isVideoCameraAvailable {
                Button("Gravar vídeo") {
                    DispatchQueue.main.async { showMediaVideoCameraPicker = true }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A mídia recebe duração, kcal e outros dados da sessão com a marca HealthFit. Opcional — não impede fechar o treino.")
        }
        .sheet(isPresented: $showMediaGalleryPicker) {
            LibraryImagePicker { image in
                showMediaGalleryPicker = false
                guard let image else { return }
                resultMedia = .photo(image)
                offerSavePhotoToGallery(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showMediaCameraPicker) {
            CameraImagePicker { image in
                showMediaCameraPicker = false
                guard let image else { return }
                resultMedia = .photo(image)
                offerSavePhotoToGallery(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showMediaVideoGalleryPicker) {
            LibraryVideoPicker { url in
                showMediaVideoGalleryPicker = false
                guard let url else {
                    mediaLoadFailed = true
                    return
                }
                applyPickedVideo(url: url)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showMediaVideoCameraPicker) {
            CameraVideoPicker { url in
                showMediaVideoCameraPicker = false
                guard let url else {
                    mediaLoadFailed = true
                    return
                }
                applyPickedVideo(url: url)
            }
            .ignoresSafeArea()
        }
        .alert("Não foi possível carregar a mídia", isPresented: $mediaLoadFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tente outra foto ou vídeo da galeria.")
        }
        .alert("Salvar na Galeria?", isPresented: $showSavePhotoToGalleryPrompt) {
            Button("Salvar em Fotos") {
                Task { await savePendingPhotoToGallery() }
            }
            Button("Agora não", role: .cancel) {
                pendingGalleryImage = nil
            }
        } message: {
            Text("Deseja guardar uma cópia desta foto na Galeria do iPhone?")
        }
        .alert(gallerySaveAlertTitle, isPresented: $showGallerySaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(gallerySaveAlertMessage)
        }
        .alert("Não foi possível gerar o PDF", isPresented: $pdfExportFailed) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $showReportPDFShare) {
            if let reportPDFURL {
                ActivityShareSheet(items: [reportPDFURL]) {
                    showReportPDFShare = false
                }
            }
        }
        .sheet(item: $mailDraft, onDismiss: {
            presentAlertForPendingMailResult()
        }) { draft in
            MailComposeView(
                recipients: draft.recipients,
                subject: draft.subject,
                body: draft.body,
                isHTML: draft.isHTML,
                attachments: draft.attachments
            ) { result in
                pendingMailResult = result
                mailDraft = nil
            }
        }
        .alert("E-mail enviado", isPresented: $showEmailSentAlert) {
            Button("OK") {
                focusShareCard()
            }
        } message: {
            if let user = authService.currentUser {
                Text("Relatório enviado para \(user.personalTrainerName.isEmpty ? user.personalTrainerEmail : user.personalTrainerName). Agora você pode compartilhar o card da conquista.")
            } else {
                Text("Relatório enviado com sucesso. Agora você pode compartilhar o card da conquista.")
            }
        }
        .alert("Falha no envio", isPresented: $showEmailFailedAlert) {
            Button("OK") {
                focusShareCard()
            }
        } message: {
            Text("Não foi possível enviar o e-mail. Verifique se há uma conta de e-mail configurada no iPhone (Ajustes → Mail → Contas). Você ainda pode compartilhar o card.")
        }
        .alert("E-mail indisponível", isPresented: $showMailUnavailableAlert) {
            Button("OK") {
                focusShareCard()
            }
        } message: {
            Text("Configure uma conta no app Mail (Ajustes → Mail → Contas) ou use Compartilhar para enviar o relatório por Gmail/Outlook. Você também pode compartilhar o card.")
        }
    }

    private var shareAchievementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                session.endedEarly ? "Compartilhar o que você fez hoje" : "Compartilhar conquista",
                systemImage: "square.and.arrow.up"
            )
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text(
                session.endedEarly
                    ? "Você não concluiu o treino, mas cada sessão conta — card pronto para Stories e status."
                    : "Card pronto para Stories e status — WhatsApp ou Instagram."
            )
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            WorkoutShareCardView(
                session: session,
                athleteName: athleteDisplayName,
                motivationLine: shareMotivation,
                recentSessions: workoutStore.sessionHistory,
                profileImage: authService.profileImage
            )
            .frame(maxWidth: .infinity)
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)

            Button {
                prepareAndShareCard()
            } label: {
                HStack {
                    if isPreparingShare {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(isPreparingShare ? "Preparando card..." : "Postar no WhatsApp / Instagram")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.gradientPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isPreparingShare)

            Button {
                Task { await saveShareCardToGallery() }
            } label: {
                Label("Salvar card na Galeria", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.accent)
            .disabled(isPreparingShare)

            Text("Escolha WhatsApp ou Instagram na tela de compartilhar. O nome HealthFit já vai no card.")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var workoutResultMediaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Foto ou vídeo do treino", systemImage: "photo.on.rectangle.angled")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Opcional — anexe uma foto ou vídeo com os dados da sessão e a marca HealthFit (estilo Stories).")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            if let resultMedia {
                WorkoutResultMediaOverlayView(
                    image: resultMedia.previewImage,
                    session: session,
                    isCardioSession: isCardioSession || session.isOutdoorGPSCardio,
                    showVideoBadge: resultMedia.isVideo
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(resultMedia.previewImage.size.width / max(resultMedia.previewImage.size.height, 1), contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)

                // Mesmo CTA do card de conquista: postar em redes sociais.
                Button {
                    if resultMedia.isVideo {
                        prepareAndShareVideo()
                    } else {
                        prepareAndShareMediaOverlay()
                    }
                } label: {
                    HStack {
                        if isPreparingMediaShare {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(
                            isPreparingMediaShare
                                ? "Preparando mídia..."
                                : "Postar no WhatsApp / Instagram"
                        )
                        .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.gradientPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isPreparingMediaShare)

                Button {
                    Task { await saveResultMediaToGallery() }
                } label: {
                    Label(
                        resultMedia.isVideo ? "Salvar capa na Galeria" : "Salvar foto na Galeria",
                        systemImage: "square.and.arrow.down"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
                .disabled(isPreparingMediaShare)

                if resultMedia.isVideo {
                    Button {
                        prepareAndShareMediaOverlay()
                    } label: {
                        mediaShareLabel(
                            icon: "photo.badge.arrow.down",
                            title: isPreparingMediaShare ? "Preparando..." : "Postar capa com dados",
                            secondary: true
                        )
                    }
                    .disabled(isPreparingMediaShare)
                }

                Text("Escolha WhatsApp ou Instagram na tela de compartilhar. Dados da sessão e HealthFit já vão na mídia.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    Button {
                        showMediaSourceDialog = true
                    } label: {
                        Label("Trocar mídia", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)

                    Button(role: .destructive) {
                        clearResultMedia()
                    } label: {
                        Label("Remover", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button {
                    showMediaSourceDialog = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Adicionar mídia")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.85), AppTheme.accentSecondary.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("Câmera, galeria ou vídeo · overlay com duração, km, kcal e HealthFit")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func mediaShareLabel(icon: String, title: String, secondary: Bool = false) -> some View {
        HStack {
            if isPreparingMediaShare {
                ProgressView()
                    .tint(secondary ? AppTheme.accent : .white)
            } else {
                Image(systemName: icon)
            }
            Text(title)
                .font(.headline)
        }
        .foregroundStyle(secondary ? AppTheme.accent : .white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            secondary
                ? AnyShapeStyle(AppTheme.cardBackground)
                : AnyShapeStyle(AppTheme.gradientPrimary)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(secondary ? AppTheme.accent.opacity(0.5) : .clear, lineWidth: 1)
        )
    }

    private func applyPickedVideo(url: URL) {
        if let poster = WorkoutResultMediaOverlayRenderer.posterFrame(fromVideoURL: url) {
            resultMedia = .video(url: url, poster: poster)
        } else {
            mediaLoadFailed = true
        }
    }

    private func clearResultMedia() {
        if case .video(let url, _) = resultMedia {
            try? FileManager.default.removeItem(at: url)
        }
        resultMedia = nil
    }

    @MainActor
    private func prepareAndShareMediaOverlay() {
        guard let resultMedia else { return }
        isPreparingMediaShare = true
        let image = WorkoutResultMediaOverlayRenderer.renderComposedImage(
            image: resultMedia.previewImage,
            session: session,
            isCardioSession: isCardioSession || session.isOutdoorGPSCardio,
            showVideoBadge: resultMedia.isVideo
        )
        let caption = WorkoutResultMediaOverlayRenderer.shareCaption(
            session: session,
            athleteName: athleteDisplayName
        )
        isPreparingMediaShare = false
        guard let image else { return }
        shareItems = [image, caption]
        showShareSheet = true
    }

    @MainActor
    private func prepareAndShareVideo() {
        guard case .video(let url, _) = resultMedia else { return }
        isPreparingMediaShare = true
        let caption = WorkoutResultMediaOverlayRenderer.videoShareCaption(
            session: session,
            athleteName: athleteDisplayName
        )
        isPreparingMediaShare = false
        shareItems = [url, caption]
        showShareSheet = true
    }

    @MainActor
    private func prepareAndShareCard() {
        isPreparingShare = true
        let image = WorkoutShareCardRenderer.renderImage(
            session: session,
            athleteName: athleteDisplayName,
            motivationLine: shareMotivation,
            recentSessions: workoutStore.sessionHistory,
            profileImage: authService.profileImage
        )
        let caption = WorkoutShareCardRenderer.shareCaption(
            session: session,
            athleteName: athleteDisplayName
        )
        isPreparingShare = false

        guard let image else { return }
        shareImage = image
        shareCardStore.updatePreviewImage(
            image,
            slot: session.isDuoTeamSession ? .duoTeam : .individual
        )
        shareItems = [image, caption]
        showShareSheet = true
    }

    private func offerSavePhotoToGallery(_ image: UIImage) {
        pendingGalleryImage = image
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showSavePhotoToGalleryPrompt = true
        }
    }

    private func savePendingPhotoToGallery() async {
        guard let image = pendingGalleryImage else { return }
        pendingGalleryImage = nil
        do {
            try await PhotoLibrarySaver.saveImage(image)
            gallerySaveAlertTitle = "Salvo em Fotos"
            gallerySaveAlertMessage = "A foto foi salva na sua Galeria."
        } catch {
            gallerySaveAlertTitle = "Não foi possível salvar"
            gallerySaveAlertMessage = error.localizedDescription
        }
        showGallerySaveAlert = true
    }

    @MainActor
    private func saveShareCardToGallery() async {
        isPreparingShare = true
        defer { isPreparingShare = false }
        let image = shareImage ?? WorkoutShareCardRenderer.renderImage(
            session: session,
            athleteName: athleteDisplayName,
            motivationLine: shareMotivation,
            recentSessions: workoutStore.sessionHistory,
            profileImage: authService.profileImage
        )
        guard let image else {
            gallerySaveAlertTitle = "Não foi possível salvar"
            gallerySaveAlertMessage = "A imagem do card não está disponível."
            showGallerySaveAlert = true
            return
        }
        shareImage = image
        shareCardStore.updatePreviewImage(
            image,
            slot: session.isDuoTeamSession ? .duoTeam : .individual
        )
        do {
            try await PhotoLibrarySaver.saveImage(image)
            gallerySaveAlertTitle = "Salvo em Fotos"
            gallerySaveAlertMessage = "O card de postagem foi salvo na sua Galeria."
        } catch {
            gallerySaveAlertTitle = "Não foi possível salvar"
            gallerySaveAlertMessage = error.localizedDescription
        }
        showGallerySaveAlert = true
    }

    @MainActor
    private func saveResultMediaToGallery() async {
        guard let resultMedia else { return }
        isPreparingMediaShare = true
        defer { isPreparingMediaShare = false }
        let composed = WorkoutResultMediaOverlayRenderer.renderComposedImage(
            image: resultMedia.previewImage,
            session: session,
            isCardioSession: isCardioSession || session.isOutdoorGPSCardio,
            showVideoBadge: resultMedia.isVideo
        )
        guard let composed else {
            gallerySaveAlertTitle = "Não foi possível salvar"
            gallerySaveAlertMessage = "A mídia com dados do treino não está disponível."
            showGallerySaveAlert = true
            return
        }
        do {
            try await PhotoLibrarySaver.saveImage(composed)
            gallerySaveAlertTitle = "Salvo em Fotos"
            gallerySaveAlertMessage = "A mídia do treino foi salva na sua Galeria."
        } catch {
            gallerySaveAlertTitle = "Não foi possível salvar"
            gallerySaveAlertMessage = error.localizedDescription
        }
        showGallerySaveAlert = true
    }

    @MainActor
    private func exportWorkoutPDF() {
        guard let athlete = authService.currentUser else {
            pdfExportFailed = true
            return
        }
        guard let url = WorkoutSessionPDFBuilder.makePDF(
            session: session,
            athlete: athlete,
            allSessions: workoutStore.sessionHistory
        ) else {
            pdfExportFailed = true
            return
        }
        reportPDFURL = url
        showReportPDFShare = true
    }

    @ViewBuilder
    private var emailSection: some View {
        VStack(spacing: 12) {
            if let user = authService.currentUser, user.hasPersonalTrainer {
                Button {
                    sendReportToTrainer(user: user)
                } label: {
                    Label(
                        buttonLabel,
                        systemImage: emailWasSent ? "checkmark.circle.fill" : "envelope.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(emailWasSent ? Color.green : AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(mailDraft != nil || emailWasSent)

                if emailWasSent {
                    Label("E-mail enviado", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }

                if !user.personalTrainerName.isEmpty {
                    Text("Para: \(user.personalTrainerName) · \(user.personalTrainerEmail)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Para: \(user.personalTrainerEmail)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 8) {
                    Label("E-mail do personal não cadastrado", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Cadastre o e-mail do personal no Perfil para enviar o relatório deste treino.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                exportWorkoutPDF()
            } label: {
                Label("Gerar PDF do relatório", systemImage: "doc.richtext")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var finishButton: some View {
        Button {
            // Fechar encerra o fluxo; se houver callback de lista, volta aos treinos.
            if let onReturnToWorkoutList {
                onReturnToWorkoutList()
            } else {
                onFinish()
            }
        } label: {
            Text("Fechar")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var buttonLabel: String {
        if emailWasSent { return "E-mail enviado" }
        if mailDraft != nil { return "Abrindo e-mail..." }
        return "Enviar e-mail para o Personal"
    }

    private func focusShareCard() {
        scrollToShareToken += 1
    }

    private func presentAlertForPendingMailResult() {
        guard let result = pendingMailResult else {
            // Sheet fechou sem resultado (ex.: swipe) — segue para o card.
            focusShareCard()
            return
        }
        pendingMailResult = nil

        switch result {
        case .sent:
            emailWasSent = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showEmailSentAlert = true
            }
        case .failed:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showEmailFailedAlert = true
            }
        case .cancelled, .saved:
            // Mesmo cancelando o e-mail, mostra o card de compartilhar.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                focusShareCard()
            }
        @unknown default:
            focusShareCard()
        }
    }

    @MainActor
    private func sendReportToTrainer(user: UserProfile) {
        let recipient = user.personalTrainerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipient.isEmpty else {
            showMailUnavailableAlert = true
            return
        }

        let subject = WorkoutReportBuilder.emailSubject(session: session, athleteName: user.name)
        // PNG do mapa: embutido no HTML + anexo de backup (clientes que bloqueiam data URI).
        let mapAttachment = MailComposeView.canSendMail
            ? WorkoutRouteMapRenderer.mailAttachment(for: session)
            : nil
        let mapPNGData = mapAttachment?.data
        let mapIncluded = mapPNGData != nil

        if MailComposeView.canSendMail {
            let htmlBody = WorkoutReportBuilder.emailHTMLBody(
                session: session,
                athlete: user,
                allSessions: workoutStore.sessionHistory,
                routeMapAttachmentIncluded: mapIncluded,
                routeMapPNGData: mapPNGData
            )
            pendingMailResult = nil
            mailDraft = TrainerMailDraft(
                recipients: [recipient],
                subject: subject,
                body: htmlBody,
                isHTML: true,
                attachments: mapAttachment.map { [$0] } ?? []
            )
        } else {
            // Fallback: mailto (corpo curto) ou share sheet (arquivo .txt) se Mail não estiver configurado.
            let plainBody = WorkoutReportBuilder.emailBody(
                session: session,
                athlete: user,
                allSessions: workoutStore.sessionHistory,
                routeMapAttachmentIncluded: false
            )
            if let url = MailComposeView.mailtoURL(
                recipients: [recipient],
                subject: subject,
                body: plainBody
            ) {
                UIApplication.shared.open(url) { accepted in
                    if accepted {
                        // mailto não confirma envio; segue para o card.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            focusShareCard()
                        }
                    } else {
                        shareReportAsFile(subject: subject, body: plainBody, to: recipient)
                    }
                }
            } else {
                shareReportAsFile(subject: subject, body: plainBody, to: recipient)
            }
        }
    }

    private func shareReportAsFile(subject: String, body: String, to recipient: String) {
        let enriched = """
        Para: \(recipient)

        \(body)
        """
        if let fileURL = MailComposeView.writeShareableReportFile(
            subject: subject,
            body: enriched,
            fileNamePrefix: "HealthFit-Treino"
        ) {
            shareItems = [fileURL]
            showShareSheet = true
        } else {
            showMailUnavailableAlert = true
        }
    }

    private var earlyEndCount: Int {
        let history = workoutStore.sessionHistory
        if history.contains(where: { $0.id == session.id }) {
            return WorkoutReportBuilder.earlyEndCount(from: history)
        }
        return WorkoutReportBuilder.earlyEndCount(from: [session] + history)
    }

    private var earlyEndSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: session.autoEndedByInactivity
                      ? "clock.badge.exclamationmark.fill"
                      : "exclamationmark.triangle.fill")
                    .foregroundStyle(session.autoEndedByInactivity ? .orange : .red)
                Text(session.autoEndedByInactivity
                     ? "Esqueceu de finalizar o treino"
                     : "Encerrado antecipadamente")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            if session.autoEndedByInactivity {
                Text("Poxa… o treino ficou aberto por mais de 2h30. Eu encerrei por segurança — não se preocupe, estou aqui pra te ajudar no próximo.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let justification = session.earlyEndJustification?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !justification.isEmpty {
                Text(justification)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text("Total de encerramentos antecipados: \(earlyEndCount) vez(es)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((session.autoEndedByInactivity ? Color.orange : Color.red).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func bodyMeasurementsSection(user: UserProfile) -> some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let lines = user.bodyMeasurements.reportLines(dateFormatter: formatter)
            .filter { !$0.isEmpty && $0 != "Medidas corporais:" }

        let comparison = user.latestMeasurementComparison
        let comparisonLines = (comparison?.periodDays ?? 0) >= BodyMeasurements.comparisonIntervalDays
            ? (comparison?.reportLines(dateFormatter: formatter) ?? []).filter { !$0.isEmpty }
            : []

        return VStack(alignment: .leading, spacing: 10) {
            Label("Medidas corporais", systemImage: "ruler")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if !comparisonLines.isEmpty {
                Divider()
                ForEach(Array(comparisonLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var summaryHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: session.endedEarly ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(session.endedEarly ? Color.red : AppTheme.accent)

            Text(session.workoutTitle)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            if session.autoEndedByInactivity {
                Text("Encerrado automaticamente — você esqueceu de finalizar (mais de 2h30)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else if session.endedEarly {
                Text("Treino encerrado sem conclusão completa")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 20) {
                SummaryStat(
                    value: DurationFormatting.format(seconds: Int(session.duration)),
                    label: "Duração total",
                    icon: "clock.fill"
                )
                if isCardioSession {
                    if session.caloriesBurned > 0 {
                        SummaryStat(
                            value: "\(Int(session.caloriesBurned))",
                            label: "kcal",
                            icon: "flame.fill"
                        )
                    }
                    if session.averageHeartRate > 0 {
                        SummaryStat(
                            value: String(format: "%.0f", session.averageHeartRate),
                            label: "BPM",
                            icon: "heart.fill"
                        )
                    }
                } else {
                    SummaryStat(
                        value: "\(session.completedExercises)/\(session.totalExercises)",
                        label: "Exercícios",
                        icon: "list.bullet"
                    )
                    if session.caloriesBurned > 0 {
                        SummaryStat(
                            value: "\(Int(session.caloriesBurned))",
                            label: "kcal",
                            icon: "flame.fill"
                        )
                    }
                }
            }

            if isCardioSession, session.pausedDurationSeconds > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(Color(red: 0.35, green: 0.58, blue: 1.0))
                    Text("Pausa: \(DurationFormatting.format(seconds: session.pausedDurationSeconds))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("Ativo: \(DurationFormatting.format(seconds: session.activeDurationSeconds))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    @ViewBuilder
    private var calorieGoalResultSection: some View {
        if let target = session.targetCalories, target > 0 {
            let burned = Int(session.caloriesBurned)
            let exceeded = burned >= target
            let superation = burned - target

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: exceeded ? "flame.circle.fill" : "target")
                        .foregroundStyle(exceeded ? .orange : AppTheme.accentSecondary)
                    Text("Meta de calorias")
                        .font(.headline)
                }

                HStack {
                    Text("\(burned) / \(target) kcal")
                        .font(.title3.bold())
                        .foregroundStyle(exceeded ? .orange : AppTheme.textPrimary)
                    Spacer()
                    Text(exceeded ? "Atingida" : "Parcial")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(exceeded ? .green : AppTheme.textSecondary)
                }

                ProgressView(value: min(Double(burned) / Double(target), 1.0))
                    .tint(exceeded ? .orange : AppTheme.accentSecondary)

                if superation > 0 {
                    Text(MotivationMessages.cardioCalorieExceededMessage(
                        currentCalories: burned,
                        targetCalories: target
                    ))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    @ViewBuilder
    private var marathonPerformanceSection: some View {
        if let report = marathonReport {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text("Performance Maratona")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                }

                HStack(spacing: 16) {
                    SummaryStat(
                        value: String(format: "%.2f km", report.distanceKm),
                        label: "Percorridos",
                        icon: "map.fill"
                    )
                    SummaryStat(
                        value: report.formattedTime,
                        label: "Tempo",
                        icon: "clock.fill"
                    )
                    SummaryStat(
                        value: report.formattedPace.replacingOccurrences(of: " /km", with: ""),
                        label: "Ritmo",
                        icon: "speedometer"
                    )
                }

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    Label("Meta \(String(format: "%.0f", report.targetDistanceKm)) km", systemImage: "target")
                    Spacer()
                    Text(report.goalReached ? "Atingida" : "Parcial")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(report.goalReached ? .green : AppTheme.accentSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Projeções com este ritmo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack {
                        Label("Meia (21,1 km)", systemImage: "flag.checkered")
                        Spacer()
                        Text(report.formattedHalfMarathonProjection)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                    }
                    HStack {
                        Label("Maratona (42,2 km)", systemImage: "trophy.fill")
                        Spacer()
                        Text(report.formattedMarathonProjection)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                HStack {
                    Label("Volume semanal", systemImage: "calendar")
                    Spacer()
                    Text(String(format: "%.1f km", report.weeklyRunningKm))
                        .font(.subheadline.weight(.semibold))
                }

                if let previous = report.previousBestSeconds, let delta = report.improvementSeconds {
                    HStack {
                        Label("Melhor marca anterior", systemImage: "medal.fill")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(PaceFormatting.formatDuration(seconds: previous))
                                .font(.subheadline.weight(.semibold))
                            if delta < 0 {
                                Text("Novo recorde! −\(abs(delta / 60)) min")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            } else if delta > 0 {
                                Text("+\(delta / 60) min vs recorde")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            } else {
                                Text("Empate com recorde")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.accentSecondary)
                            }
                        }
                    }
                }

                Text(report.readinessMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 4)

                if !report.coachingTips.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    Text("Orientações")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(report.coachingTips, id: \.self) { tip in
                        Label(tip, systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    private func surfKitePerformanceSection(report: SurfKiteComparisonReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: report.session.waterSport?.isKitesurf == true
                      ? CardioExercise.kitesurfSystemImage
                      : CardioExercise.surfSystemImage)
                    .foregroundStyle(AppTheme.accent)
                Text(report.session.waterSport?.isKitesurf == true ? "Performance Kitesurf" : "Performance Surf")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 12) {
                SummaryStat(
                    value: "\(report.jumpCount)",
                    label: "Saltos",
                    icon: "arrow.up.to.line"
                )
                SummaryStat(
                    value: String(format: "%.1f m", report.maxJumpMeters),
                    label: "Maior",
                    icon: "arrow.up.circle"
                )
                SummaryStat(
                    value: String(format: "%.1f g", report.maxAccelerationG),
                    label: "Pico g",
                    icon: "waveform.path.ecg"
                )
            }

            if report.distanceKm > 0 {
                Label(String(format: "%.2f km de percurso GPS", report.distanceKm), systemImage: "map")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let spot = report.spotName {
                Label("SPOT: \(spot)", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let wind = report.windSummary {
                Label("Vento: \(wind)", systemImage: "wind")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let tide = report.tideSummary {
                Label("Maré: \(tide)", systemImage: "water.waves")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let mode = report.ridingModeLabel {
                Text("Modo: \(mode)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let board = report.boardLabel {
                Text("Prancha: \(board)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let eq = report.equipmentLabel {
                Text("Kite: \(eq)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let prev = report.previousBestJumpMeters, prev > 0 {
                HStack {
                    Label("Recorde anterior", systemImage: "medal.fill")
                    Spacer()
                    Text(String(format: "%.2f m", prev))
                        .font(.subheadline.weight(.semibold))
                }
                if let delta = report.jumpDeltaVsBest {
                    if delta > 0 {
                        Text(String(format: "Novo recorde de salto! +%.2f m", delta))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    } else if delta < 0 {
                        Text(String(format: "%.2f m vs recorde", delta))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            Text("Comparado com \(report.sessionsCompared) sessão(ões) na modalidade")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                shareSurfKitePDF(report: report)
            } label: {
                Label("Exportar PDF Surf / Kite", systemImage: "doc.richtext")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentSecondary)
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func rowingPerformanceSection(_ r: RowingSessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "figure.rower")
                    .foregroundStyle(AppTheme.accent)
                Text("Performance Remo")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(r.boatType.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            HStack(spacing: 12) {
                SummaryStat(
                    value: RowingMetricsMath.formatSPM(r.averageSPM),
                    label: "SPM méd.",
                    icon: "metronome.fill"
                )
                SummaryStat(
                    value: r.formattedAverageSplit,
                    label: "Split /500 m",
                    icon: "timer"
                )
                SummaryStat(
                    value: "\(r.totalStrokes)",
                    label: "Remadas",
                    icon: "arrow.left.arrow.right"
                )
            }

            HStack(spacing: 12) {
                SummaryStat(
                    value: String(format: "%.1f m", r.metersPerStroke),
                    label: "m/remada",
                    icon: "ruler"
                )
                SummaryStat(
                    value: String(format: "%.0f", r.efficiencyScore),
                    label: "Eficiência",
                    icon: "chart.bar.fill"
                )
                SummaryStat(
                    value: String(format: "%.0f%%", r.asymmetryPercent),
                    label: "Assimetria",
                    icon: "arrow.left.and.right"
                )
            }

            Label(
                String(
                    format: "Estabilidade %.0f · Equilíbrio %.0f · Esq. %.0f%% / Dir. %.0f%%",
                    r.stabilityScore,
                    r.balanceScore,
                    r.leftSideShare * 100,
                    r.rightSideShare * 100
                ),
                systemImage: "gyroscope"
            )
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)

            if r.bestSplitSecondsPer500m != nil {
                Text("Melhor split: \(r.formattedBestSplit) /500 m")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            Text(r.symmetryInsight)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    @MainActor
    private func shareSurfKitePDF(report: SurfKiteComparisonReport) {
        guard let url = SurfKiteReportBuilder.makePDF(report: report, athleteName: athleteDisplayName) else {
            return
        }
        shareItems = [url]
        showShareSheet = true
    }

    @ViewBuilder
    private var runRouteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundStyle(AppTheme.accent)
                Text({
                    if session.isOutdoorCyclingSession { return "Rota do pedal" }
                    if session.isOutdoorWalkingSession { return "Rota da caminhada" }
                    if session.isWaterSportSession {
                        return session.waterSport?.isKitesurf == true ? "Rota do kitesurf" : "Rota do surf"
                    }
                    return "Rota da corrida"
                }())
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if let steps = session.stepCount {
                    Label("\(steps) passos", systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            RunRouteMapView(
                routePoints: session.routePoints,
                userCoordinate: session.routePoints.last?.coordinate ?? waterSpotCoordinate,
                followUser: false,
                showsUserLocation: false,
                height: session.isWaterSportSession || session.isOutdoorGPSCardio ? 300 : 260,
                performanceMetric: session.routePerformanceMetric,
                jumpEvents: session.waterSport?.jumps ?? [],
                allows3DMode: true,
                spotCoordinate: waterSpotCoordinate,
                spotTitle: session.waterSport?.spot?.name,
                prefers3DInitially: session.routePoints.count >= 2
            )

            if session.routePoints.count >= 2 {
                Text(RoutePerformanceColoring.legendText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            } else if session.isWaterSportSession, session.routePoints.isEmpty {
                Text(waterSpotCoordinate != nil
                     ? "Mapa do SPOT de partida · sem rota GPS completa nesta sessão."
                     : "Sem pontos GPS registrados nesta sessão.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let distance = session.completedDistanceKm {
                Text(String(format: "%.2f km percorridos · %d pontos GPS", distance, session.routePoints.count))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let jumps = session.waterSport?.jumps, !jumps.isEmpty {
                Text("\(jumps.count) salto(s) · ciano = subida · laranja = descida (sobre o GPS)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    @ViewBuilder
    private var preWorkoutSection: some View {
        if session.tookPreWorkout != nil || !preWorkoutHistory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pré-treino")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                if let tookPreWorkout = session.tookPreWorkout {
                    HStack {
                        Label("Neste treino", systemImage: "bolt.fill")
                        Spacer()
                        Text(tookPreWorkout ? "Sim, tomei" : "Não tomei")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tookPreWorkout ? AppTheme.accent : AppTheme.textSecondary)
                    }
                }

                HStack {
                    Label("Usou pré-treino", systemImage: "checkmark.circle.fill")
                    Spacer()
                    Text("\(lifetimePreWorkoutSummary.usedCount)x")
                        .font(.subheadline.weight(.semibold))
                }

                HStack {
                    Label("Não usou", systemImage: "xmark.circle.fill")
                    Spacer()
                    Text("\(lifetimePreWorkoutSummary.notUsedCount)x")
                        .font(.subheadline.weight(.semibold))
                }

                if !preWorkoutHistory.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    Text("Todas as respostas")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)

                    ForEach(preWorkoutHistory) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.workoutTitle)
                                    .font(.caption.weight(.medium))
                                Text(entry.date, format: .dateTime.day().month().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Text(entry.tookPreWorkout ? "Sim" : "Não")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(entry.tookPreWorkout ? AppTheme.accent : AppTheme.textSecondary)
                        }
                    }
                }
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    private var preWorkoutHistory: [PreWorkoutSessionEntry] {
        WorkoutReportBuilder.preWorkoutEntries(from: workoutStore.sessionHistory)
    }

    private var lifetimePreWorkoutSummary: PreWorkoutUsageSummary {
        PreWorkoutUsageSummary.from(sessions: workoutStore.sessionHistory)
    }

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isCardioSession ? "Detalhes do Cardio" : "Tempo por Exercício")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(session.exerciseRecords) { record in
                HStack(spacing: 12) {
                    Image(systemName: record.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(record.isCompleted ? AppTheme.accent : AppTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.exerciseName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        if let weightLabel = record.weightComparisonLabel {
                            Text(weightLabel)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        if record.restSeconds > 0 {
                            Text("Descanso: \(DurationFormatting.format(seconds: record.restSeconds))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Text(DurationFormatting.format(seconds: record.elapsedSeconds))
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(record.isCompleted ? AppTheme.accent : AppTheme.textSecondary)
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private var totalsSection: some View {
        if !isCardioSession {
            VStack(spacing: 12) {
                HStack {
                    Label("Tempo nos exercícios", systemImage: "figure.strengthtraining.traditional")
                    Spacer()
                    Text(DurationFormatting.format(seconds: session.totalExerciseSeconds))
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                }

                HStack {
                    Label("Descanso total", systemImage: "timer")
                    Spacer()
                    Text(DurationFormatting.format(seconds: session.totalRestSeconds))
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }
}

private struct SummaryStat: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

import UIKit
