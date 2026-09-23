import MapKit
import SwiftUI
import UIKit

/// Sheet estilo Strava Flyover: preview 3D MapKit + vídeo com marca HealthFit e métricas.
struct RouteFlyoverSheet: View {
    let session: WorkoutSession
    let athleteName: String

    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var flyProgress: Double = 0
    @State private var isPreviewPlaying = true
    @State private var previewTask: Task<Void, Never>?

    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportedURL: URL?
    @State private var exportError: String?

    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var galleryAlertTitle = ""
    @State private var galleryAlertMessage = ""
    @State private var showGalleryAlert = false
    @State private var storiesUnavailable = false

    private var metrics: RouteFlyoverMetrics {
        RouteFlyoverMetrics.make(session: session, athleteName: athleteName)
    }

    private var coordinates: [CLLocationCoordinate2D] {
        session.routePoints.map(\.coordinate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    previewCard
                    metricsCard
                    actionsCard
                    if let exportError {
                        Text(exportError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Flyover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onAppear { startPreviewLoop() }
            .onDisappear {
                previewTask?.cancel()
                previewTask = nil
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityShareSheet(items: shareItems) {
                    showShareSheet = false
                }
            }
            .alert(galleryAlertTitle, isPresented: $showGalleryAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(galleryAlertMessage)
            }
            .alert("Instagram Stories", isPresented: $storiesUnavailable) {
                Button("Compartilhar de outro jeito") {
                    Task { await shareVideo() }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Abra o Instagram ou use Compartilhar para enviar o Flyover.")
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "film.stack")
                    .foregroundStyle(AppTheme.accent)
                Text("Sobrevoo 3D")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button(isPreviewPlaying ? "Pausar" : "Reproduzir") {
                    if isPreviewPlaying {
                        isPreviewPlaying = false
                        previewTask?.cancel()
                    } else {
                        isPreviewPlaying = true
                        startPreviewLoop()
                    }
                }
                .font(.caption.weight(.semibold))
            }

            ZStack(alignment: .bottomLeading) {
                Map(position: $cameraPosition) {
                    if coordinates.count >= 2 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(
                                Color.white.opacity(0.25),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                            )
                        MapPolyline(coordinates: revealedCoordinates)
                            .stroke(
                                AppTheme.accent,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                            )
                    }
                    if let tip = revealedCoordinates.last {
                        Annotation("Agora", coordinate: tip) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().fill(AppTheme.accent).frame(width: 8, height: 8))
                        }
                    }
                }
                .mapStyle(.imagery(elevation: .realistic))
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 8) {
                    Image("BrandHeart")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text("HealthFit Flyover")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.45))
                .clipShape(Capsule())
                .padding(12)
            }

            if isExporting {
                ProgressView(value: exportProgress)
                    .tint(AppTheme.accent)
                Text("Gerando vídeo… \(Int(exportProgress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var metricsCard: some View {
        HStack(spacing: 12) {
            metricChip(label: "Distância", value: metrics.distanceText)
            metricChip(label: "Tempo", value: metrics.durationText)
            metricChip(label: metrics.secondaryLabel.capitalized, value: metrics.secondaryValue)
        }
    }

    private func metricChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionsCard: some View {
        VStack(spacing: 12) {
            Button {
                Task { _ = await generateVideoIfNeeded(force: true) }
            } label: {
                HStack {
                    if isExporting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles.rectangle.stack")
                    }
                    Text(isExporting ? "Gerando Flyover…" : (exportedURL == nil ? "Gerar vídeo Flyover" : "Gerar novamente"))
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.gradientPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isExporting || session.routePoints.count < 2)

            Button {
                Task { await shareVideo() }
            } label: {
                Label("Compartilhar no WhatsApp / Instagram", systemImage: "paperplane.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .disabled(isExporting)

            Button {
                Task { await shareToInstagramStories() }
            } label: {
                Label("Stories do Instagram", systemImage: "camera.filters")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.accent)
            .disabled(isExporting)

            Button {
                Task { await saveToGallery() }
            } label: {
                Label("Salvar no dispositivo", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.accent)
            .disabled(isExporting)

            Text("Vídeo vertical (Stories) com marca HealthFit, \(metrics.modalityTitle.lowercased()) e métricas do percurso.")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var revealedCoordinates: [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }
        let count = max(2, Int(Double(coordinates.count - 1) * flyProgress) + 1)
        return Array(coordinates.prefix(count))
    }

    private func startPreviewLoop() {
        previewTask?.cancel()
        guard coordinates.count >= 2 else { return }
        previewTask = Task { @MainActor in
            while !Task.isCancelled && isPreviewPlaying {
                for step in 0...80 {
                    guard !Task.isCancelled, isPreviewPlaying else { return }
                    let t = Double(step) / 80.0
                    flyProgress = t
                    applyCamera(at: t)
                    try? await Task.sleep(nanoseconds: 90_000_000)
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }

    private func applyCamera(at progress: Double) {
        guard coordinates.count >= 2 else { return }
        let idx = min(coordinates.count - 1, max(0, Int(Double(coordinates.count - 1) * progress)))
        let center = coordinates[idx]
        let lookAhead = coordinates[min(coordinates.count - 1, idx + max(1, coordinates.count / 20))]
        let heading = bearing(from: center, to: lookAhead)
        let span = routeSpanMeters()
        let distance = max(500, min(span * 2.2, 14_000)) * (1.15 - 0.25 * sin(progress * .pi))
        let camera = MapCamera(
            centerCoordinate: center,
            distance: distance,
            heading: heading,
            pitch: 58
        )
        withAnimation(.easeInOut(duration: 0.12)) {
            cameraPosition = .camera(camera)
        }
    }

    private func routeSpanMeters() -> CLLocationDistance {
        guard let first = coordinates.first else { return 1_200 }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let latM = max(maxLat - minLat, 0.002) * 111_320
        let lonM = max(maxLon - minLon, 0.002) * 111_320 * max(cos(first.latitude * .pi / 180), 0.2)
        return max(latM, lonM)
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    @MainActor
    private func generateVideoIfNeeded(force: Bool = false) async -> URL? {
        if let exportedURL, !force { return exportedURL }
        guard session.routePoints.count >= 2 else {
            exportError = RouteFlyoverVideoExporter.ExportError.tooFewPoints.localizedDescription
            return nil
        }
        isExporting = true
        exportProgress = 0
        exportError = nil
        defer { isExporting = false }
        do {
            let url = try await RouteFlyoverVideoExporter.export(
                routePoints: session.routePoints,
                performanceMetric: session.routePerformanceMetric,
                metrics: metrics
            ) { value in
                exportProgress = value
            }
            exportedURL = url
            return url
        } catch {
            exportError = error.localizedDescription
            return nil
        }
    }

    @MainActor
    private func shareVideo() async {
        guard let url = await generateVideoIfNeeded() else { return }
        shareItems = [url, metrics.caption]
        showShareSheet = true
    }

    @MainActor
    private func saveToGallery() async {
        guard let url = await generateVideoIfNeeded() else { return }
        do {
            try await PhotoLibrarySaver.saveVideo(at: url)
            galleryAlertTitle = "Salvo em Fotos"
            galleryAlertMessage = "O Flyover foi salvo na Galeria do iPhone."
        } catch {
            galleryAlertTitle = "Não foi possível salvar"
            galleryAlertMessage = error.localizedDescription
        }
        showGalleryAlert = true
    }

    @MainActor
    private func shareToInstagramStories() async {
        guard let url = await generateVideoIfNeeded() else { return }
        let scheme = URL(string: "instagram-stories://share")!
        guard UIApplication.shared.canOpenURL(scheme) else {
            storiesUnavailable = true
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pasteboardItems: [[String: Any]] = [[
                "com.instagram.sharedSticker.backgroundVideo": data,
                "com.instagram.sharedSticker.appID": Bundle.main.bundleIdentifier ?? "luan.com.healthfit.app"
            ]]
            UIPasteboard.general.setItems(
                pasteboardItems,
                options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
            )
            var components = URLComponents(string: "instagram-stories://share")!
            components.queryItems = [
                URLQueryItem(
                    name: "source_application",
                    value: Bundle.main.bundleIdentifier ?? "luan.com.healthfit.app"
                )
            ]
            if let openURL = components.url {
                await UIApplication.shared.open(openURL)
            }
        } catch {
            exportError = error.localizedDescription
            storiesUnavailable = true
        }
    }
}
