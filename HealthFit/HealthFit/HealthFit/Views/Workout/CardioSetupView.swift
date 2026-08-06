import SwiftUI
import CoreLocation
import Combine

struct CardioSetupView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let exercise: CardioExercise
    @State private var selectedIntensity: CardioIntensity = .medium
    @State private var selectedDistance: RunningDistance = .five
    @State private var distanceMode: DistanceSetupMode = .free
    @State private var customKmText = "8"
    @State private var useCalorieGoal = false
    @State private var selectedCalorieGoal = 300
    @State private var selectedPool: PoolLength = .twentyFive
    @State private var customPoolMeters: Int = 25
    @State private var useCustomPool = false
    @State private var useLapGoal = false
    @State private var targetLaps: Int = 20
    // Surf / Kitesurf
    @State private var kiteEquipment: KiteEquipmentType = .tubeKite
            @State private var selectedBoard: WaterBoardCatalog = .twinTip
    @State private var boardSearch = ""
    @State private var ridingMode: KiteRidingMode = .bigAir
    @State private var spotName = ""
    @State private var useCurrentLocationAsSpot = true
    @State private var windSpeedKmh: Double = 18
    @State private var windDirectionDegrees: Double = 90
    @State private var tideLabel = "Não informado"
    @State private var tideHeightMeters: Double = 0
    @State private var selectedRowingBoat: RowingBoatType = .singleSkiff
    // Escalada
    @State private var climbingDiscipline: ClimbingDiscipline = .sport
    @State private var climbingGradeSystem: ClimbingGradeSystem = .brazilian
    @State private var climbingTargetGradeLabel: String?
    @State private var climbingArea: ClimbingArea?
    @State private var climbingAreaName = ""
    @State private var climbingUsesMotion = true
    @State private var showsClimbingMap = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var spotLocator = SpotLocationHelper()
    @State private var showWindConditions = false
    @State private var windSnapshot: OpenMeteoWindService.Snapshot?
    @State private var isLoadingWind = false
    @State private var windLoadError: String?

    private static let caloriePresets = [100, 150, 200, 250, 300, 350, 400, 500, 600, 800]
    private static let lapPresets = [10, 20, 30, 40, 50, 60, 80, 100]
    private static let outdoorKmPresets: [Double] = [3, 5, 8, 10, 15, 20, 30, 40]

    private enum DistanceSetupMode: Hashable {
        case free
        case preset(RunningDistance)
        case custom

        var isFree: Bool {
            if case .free = self { return true }
            return false
        }
    }

    private var resolvedPoolMeters: Double {
        if useCustomPool {
            return Double(min(max(customPoolMeters, 10), 100))
        }
        return selectedPool.meters
    }

    private var parsedCustomKm: Double {
        let normalized = customKmText.replacingOccurrences(of: ",", with: ".")
        let value = Double(normalized) ?? 5
        return min(max(value, 0.5), 300)
    }

    private var waterSetup: WaterSportSetup? {
        makeWaterSetup(windSpeedKmh: windSpeedKmh, windDirectionDegrees: windDirectionDegrees)
    }

    private func makeWaterSetup(
        windSpeedKmh: Double,
        windDirectionDegrees: Double
    ) -> WaterSportSetup? {
        guard exercise.isWaterSport else { return nil }
        var spot = WaterSpotInfo(name: spotName.trimmingCharacters(in: .whitespacesAndNewlines))
        if useCurrentLocationAsSpot, let c = spotLocator.coordinate {
            spot.latitude = c.latitude
            spot.longitude = c.longitude
            if spot.name.isEmpty {
                spot.name = "Spot GPS"
            }
        }
        let conditions = WindTideConditions(
            windSpeedKmh: windSpeedKmh,
            windDirectionDegrees: windDirectionDegrees,
            windLabel: WindDirectionLabels.label(degrees: windDirectionDegrees),
            tideLabel: tideLabel,
            tideHeightMeters: tideHeightMeters
        )
        return WaterSportSetup(
            kiteEquipment: exercise.isKitesurf ? kiteEquipment : nil,
            boardType: selectedBoard,
            ridingMode: exercise.isKitesurf ? ridingMode : nil,
            spot: spot,
            conditions: conditions
        )
    }

    private var filteredBoards: [WaterBoardCatalog] {
        let base = exercise.isKitesurf ? WaterBoardCatalog.kiteBoards : WaterBoardCatalog.surfBoards
        let q = boardSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.rawValue.lowercased().contains(q) || $0.detail.lowercased().contains(q)
        }
    }

    private var config: CardioWorkoutConfig {
        makeConfig()
    }

    private func makeConfig(windSnapshot: OpenMeteoWindService.Snapshot? = nil) -> CardioWorkoutConfig {
        let speed = windSnapshot.map { min(max($0.windSpeedKmh, 0), 60) } ?? windSpeedKmh
        let direction = windSnapshot.map { min(max($0.windDirectionDegrees, 0), 359) } ?? windDirectionDegrees

        let supportsKm = exercise.supportsCustomDistanceGoals
        let isFree = supportsKm && distanceMode.isFree

        let preset: RunningDistance? = {
            guard supportsKm, case .preset(let d) = distanceMode else { return nil }
            return d
        }()

        let customKm: Double? = {
            guard supportsKm, case .custom = distanceMode else { return nil }
            return parsedCustomKm
        }()

        return CardioWorkoutConfig(
            exercise: exercise,
            intensity: selectedIntensity,
            runningDistance: exercise.supportsDistanceGoals ? preset : nil,
            targetCalories: useCalorieGoal ? selectedCalorieGoal : nil,
            isFreeRun: isFree || exercise.isWaterSport,
            poolLengthMeters: exercise.supportsSwimmingPool ? resolvedPoolMeters : nil,
            targetSwimLaps: exercise.supportsSwimmingPool && useLapGoal ? targetLaps : nil,
            customTargetDistanceKm: customKm ?? {
                if supportsKm, !exercise.supportsDistanceGoals, case .preset(let d) = distanceMode {
                    return d.kilometers
                }
                return nil
            }(),
            waterSportSetup: makeWaterSetup(windSpeedKmh: speed, windDirectionDegrees: direction),
            rowingSetup: exercise.isRowing ? RowingSetup(boatType: selectedRowingBoat) : nil,
            climbingSetup: climbingSetup
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                modalityLogbookLink
                if exercise.supportsCustomDistanceGoals {
                    outdoorDistanceSection
                }
                if exercise.isWaterSport {
                    waterSportSetupSection
                }
                if exercise.isRowing {
                    rowingSetupSection
                }
                if exercise.isClimbing {
                    climbingSetupSection
                }
                if exercise.supportsSwimmingPool {
                    swimmingPoolSection
                    swimmingLapsSection
                }
                if !exercise.isWaterSport {
                    calorieGoalSection
                    intensitySection
                    if exercise.supportsDistanceGoals {
                        runningWindSection
                    }
                    if exercise.isRowing {
                        rowingSPMZonesInfoSection
                    }
                }
                summarySection
                startButton
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showWindConditions) {
            WaterWindConditionsView(
                title: exercise.isKitesurf ? "Vento e maré — Kitesurf" : "Vento e maré — Surf",
                preferredCoordinate: spotLocator.coordinate,
                locationHint: spotName.isEmpty ? nil : spotName,
                startButtonTitle: exercise.isKitesurf ? "Iniciar Kitesurf" : "Iniciar Surf",
                isKitesurf: exercise.isKitesurf,
                onStart: { snap in
                    if let snap {
                        applyWindSnapshot(snap)
                    }
                    showWindConditions = false
                    startCardioSession(windSnapshot: snap ?? windSnapshot)
                },
                onCancel: {
                    showWindConditions = false
                }
            )
            .presentationDetents([.large])
        }
        .onAppear {
            if exercise.supportsDistanceGoals {
                distanceMode = .preset(.five)
            } else if exercise.supportsCustomDistanceGoals {
                distanceMode = .custom
                customKmText = exercise.isOutdoorCycling ? "20" : "5"
            }
            if exercise.isSurf {
                selectedBoard = .shortboard
            } else if exercise.isKitesurf {
                selectedBoard = .twinTip
            }
            if exercise.isWaterSport || exercise.supportsDistanceGoals {
                spotLocator.requestLocation()
                Task { await preloadWind(force: false) }
            }
        }
        .onChange(of: spotLocator.coordinate?.latitude) { _, _ in
            let shouldLoad = exercise.isWaterSport || exercise.supportsDistanceGoals
            guard shouldLoad, spotLocator.coordinate != nil, windSnapshot == nil else { return }
            Task { await preloadWind(force: false) }
        }
    }

    @MainActor
    private func preloadWind(force: Bool) async {
        guard exercise.isWaterSport || exercise.supportsDistanceGoals else { return }
        isLoadingWind = true
        windLoadError = nil
        let preferred = spotLocator.coordinate
        let hint = spotName.trimmingCharacters(in: .whitespacesAndNewlines)
        let (coord, label) = OpenMeteoWindService.shared.resolveLocation(
            preferred: preferred,
            preferredLabel: hint.isEmpty ? nil : hint
        )
        do {
            let result = try await OpenMeteoWindService.shared.fetch(
                latitude: coord.latitude,
                longitude: coord.longitude,
                locationLabel: label,
                forceRefresh: force
            )
            windSnapshot = result
            applyWindSnapshot(result)
        } catch {
            windLoadError = (error as? LocalizedError)?.errorDescription
                ?? (exercise.isWaterSport
                    ? "Não foi possível carregar vento e maré."
                    : "Não foi possível carregar o vento.")
        }
        isLoadingWind = false
    }

    /// Diário da modalidade (dentro de Natação / Bike / Surf / Kite).
    @ViewBuilder
    private var modalityLogbookLink: some View {
        if exercise.supportsSwimmingPool {
            NavigationLink(value: SwimmingLogbookRoute()) {
                modalityLogbookRow(
                    title: "Diário de natação",
                    subtitle: "Histórico, distância, ritmo e calorias",
                    icon: "book.pages.fill",
                    tint: .cyan
                )
            }
            .buttonStyle(.plain)
        } else if exercise.isOutdoorCycling {
            NavigationLink(value: BikeLogbookRoute()) {
                modalityLogbookRow(
                    title: "Diário de bike",
                    subtitle: "Problemas, manutenção e vida útil das peças",
                    icon: "book.pages.fill",
                    tint: .green
                )
            }
            .buttonStyle(.plain)
        } else if exercise.isKitesurf {
            NavigationLink(value: SurfKiteLogbookRoute(kitesurfOnly: true)) {
                modalityLogbookRow(
                    title: "Diário de kite surf",
                    subtitle: "Saltos, SPOT, vento e comparativo",
                    icon: CardioExercise.kitesurfSystemImage,
                    tint: .cyan
                )
            }
            .buttonStyle(.plain)
        } else if exercise.isSurf {
            NavigationLink(value: SurfKiteLogbookRoute(kitesurfOnly: false)) {
                modalityLogbookRow(
                    title: "Diário de surf",
                    subtitle: "SPOT, condições e comparativo de sessões",
                    icon: CardioExercise.surfSystemImage,
                    tint: .cyan
                )
            }
            .buttonStyle(.plain)
        } else if exercise.isClimbing {
            NavigationLink(value: ClimbingLogbookRoute()) {
                modalityLogbookRow(
                    title: "Diário de escalada",
                    subtitle: "Progressão por grau, vias e inspeção de equipamento",
                    icon: "book.pages.fill",
                    tint: .orange
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func modalityLogbookRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func applyWindSnapshot(_ snap: OpenMeteoWindService.Snapshot) {
        windSpeedKmh = min(max(snap.windSpeedKmh, 0), 60)
        windDirectionDegrees = min(max(snap.windDirectionDegrees, 0), 359)
        let tide = snap.estimatedTideLabel
        if tide != "Não informado" {
            tideLabel = tide
        }
        if let h = snap.displayTideHeightMeters {
            tideHeightMeters = min(max(h, 0), 6)
        }
        OpenMeteoWindService.shared.saveLastKnown(
            coordinate: CLLocationCoordinate2D(latitude: snap.latitude, longitude: snap.longitude),
            label: snap.locationLabel
        )
    }

    private var headerSection: some View {
        HStack(spacing: 14) {
            ModalityCoverArt(
                systemImage: exercise.icon,
                colors: exercise.coverColors
            )
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(exercise.coverColors.first?.opacity(0.55) ?? AppTheme.accent.opacity(0.4), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(exercise.description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Label(String(format: "~%.0f kcal/min (média)", exercise.caloriesPerMinute), systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accentSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var outdoorDistanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(distanceSectionTitle)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Button {
                distanceMode = .free
            } label: {
                freeDistanceRow
            }
            .buttonStyle(.plain)

            Text("Ou escolha uma distância:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Self.outdoorKmPresets, id: \.self) { km in
                    Button {
                        selectPresetKm(km)
                    } label: {
                        let isSelected: Bool = {
                            if case .preset(let d) = distanceMode, abs(d.kilometers - km) < 0.05 { return true }
                            if case .custom = distanceMode, abs(parsedCustomKm - km) < 0.05 { return true }
                            return false
                        }()
                        VStack(spacing: 2) {
                            Text(km == km.rounded() ? "\(Int(km))" : String(format: "%.1f", km))
                                .font(.subheadline.weight(.semibold))
                            Text("KM")
                                .font(.caption2.weight(.semibold))
                                .opacity(isSelected ? 0.9 : 0.7)
                        }
                        .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    distanceMode = .custom
                    if parsedCustomKm < 0.5 { customKmText = "5" }
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Personalizar km")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if case .custom = distanceMode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .foregroundStyle({
                        if case .custom = distanceMode { return AppTheme.accent }
                        return AppTheme.textPrimary
                    }())
                    .padding()
                    .background({
                        if case .custom = distanceMode { return AppTheme.accent.opacity(0.12) }
                        return AppTheme.cardBackground
                    }())
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if case .custom = distanceMode {
                    HStack {
                        TextField("km", text: $customKmText)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(AppTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("km")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Stepper(value: Binding(
                        get: { parsedCustomKm },
                        set: { customKmText = formatKmInput($0) }
                    ), in: 0.5...300, step: 0.5) {
                        Text("Meta: \(formatKmInput(parsedCustomKm)) km")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }

    private var distanceSectionTitle: String {
        if exercise.isOutdoorCycling { return "Meta de pedal (km)" }
        if exercise.isOutdoorWalking { return "Meta de caminhada (km)" }
        return "Modo da corrida"
    }

    private var freeDistanceRow: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(distanceMode.isFree ? AppTheme.accent.opacity(0.25) : AppTheme.cardBackground)
                    .frame(width: 52, height: 52)
                Image(systemName: exercise.icon)
                    .font(.title2)
                    .foregroundStyle(distanceMode.isFree ? AppTheme.accent : AppTheme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Sem meta de km")
                    .font(.headline)
                    .foregroundStyle(distanceMode.isFree ? AppTheme.accent : AppTheme.textPrimary)
                Text("Acompanhe livremente — encerre quando quiser.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            if distanceMode.isFree {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding()
        .background(distanceMode.isFree ? AppTheme.accent.opacity(0.12) : AppTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(distanceMode.isFree ? AppTheme.accent : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func selectPresetKm(_ km: Double) {
        if exercise.supportsDistanceGoals, let match = RunningDistance(rawValue: Int(km.rounded())), abs(match.kilometers - km) < 0.05 {
            selectedDistance = match
            distanceMode = .preset(match)
        } else {
            customKmText = formatKmInput(km)
            distanceMode = .custom
            if exercise.supportsDistanceGoals, let match = RunningDistance(rawValue: Int(km.rounded())) {
                selectedDistance = match
            }
        }
    }

    private func formatKmInput(_ km: Double) -> String {
        if abs(km - km.rounded()) < 0.05 {
            return "\(Int(km.rounded()))"
        }
        return String(format: "%.1f", km)
    }

    private var waterSportSetupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(exercise.isKitesurf ? "Setup Kitesurf" : "Setup Surf")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if exercise.isKitesurf {
                Text("1. Tipo de equipamento (kite)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(KiteEquipmentType.allCases) { item in
                        Button {
                            kiteEquipment = item
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(item.rawValue, systemImage: item.icon)
                                    .font(.caption.weight(.semibold))
                                Text(item.detail)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(kiteEquipment == item ? AppTheme.accent.opacity(0.2) : AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(kiteEquipment == item ? AppTheme.accent : Color.clear, lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.textPrimary)
                    }
                }

                Text("2. Modo de velejo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(KiteRidingMode.allCases) { mode in
                    Button {
                        ridingMode = mode
                    } label: {
                        HStack {
                            Image(systemName: mode.icon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue).font(.subheadline.weight(.semibold))
                                Text(mode.detail).font(.caption2).foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            if ridingMode == mode {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.accent)
                            }
                        }
                        .padding(12)
                        .background(ridingMode == mode ? AppTheme.accent.opacity(0.12) : AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textPrimary)
                }
            }

            Text(exercise.isKitesurf ? "3. Tipo de prancha" : "Tipo de prancha")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextField("Buscar prancha…", text: $boardSearch)
                .padding(10)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(AppTheme.textPrimary)
            ForEach(filteredBoards) { board in
                Button {
                    selectedBoard = board
                } label: {
                    HStack {
                        Image(systemName: board.icon)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(board.rawValue).font(.subheadline.weight(.semibold))
                            Text(board.detail).font(.caption2).foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        if selectedBoard == board {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(12)
                    .background(selectedBoard == board ? AppTheme.accent.opacity(0.12) : AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
            }

            Text(exercise.isKitesurf ? "4. SPOT de partida" : "SPOT de partida")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextField("Nome do local / praia / spot", text: $spotName)
                .padding(10)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(AppTheme.textPrimary)
            Toggle("Sincronizar partida com GPS (mapa)", isOn: $useCurrentLocationAsSpot)
                .tint(AppTheme.accent)
                .foregroundStyle(AppTheme.textPrimary)
            if let c = spotLocator.coordinate {
                Text(String(format: "GPS: %.5f, %.5f", c.latitude, c.longitude))
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
            } else if useCurrentLocationAsSpot {
                Text(spotLocator.statusMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Button {
                spotLocator.requestLocation()
            } label: {
                Label("Atualizar localização", systemImage: "location.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(AppTheme.accent)

            preStartWindPanel

            if exercise.isKitesurf {
                Text("No treino: altura de saltos via giroscópio Apple Watch + iPhone, pontos no mapa, gráficos e relatório PDF.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    /// Painel de vento + maré (Open-Meteo / Marine) exibido no setup antes de iniciar.
    private var preStartWindPanel: some View {
        ZStack {
            TransparentOceanWavesView(
                tint: Color.cyan,
                baseOpacity: 0.16,
                waveCount: 3
            )
            .frame(height: 120)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .clipped()
            .opacity(0.85)

            TransparentWindLinesView(
                directionDegrees: windSnapshot?.windDirectionDegrees ?? windDirectionDegrees,
                speedKmh: windSnapshot?.windSpeedKmh ?? windSpeedKmh,
                tint: Color.cyan.opacity(0.95),
                baseOpacity: 0.65,
                lineCount: 7
            )
            .frame(height: 88)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Vento e maré", systemImage: "wind")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Button {
                        Task { await preloadWind(force: true) }
                    } label: {
                        if isLoadingWind {
                            ProgressView()
                                .tint(AppTheme.accent)
                        } else {
                            Label("Atualizar", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .foregroundStyle(AppTheme.accent)
                    .disabled(isLoadingWind)
                }

                if isLoadingWind && windSnapshot == nil {
                    HStack(spacing: 10) {
                        ProgressView().tint(AppTheme.accent)
                        Text("Buscando vento e maré (Open-Meteo)…")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if let snap = windSnapshot {
                    Text(snap.beachSportMessage(isKitesurf: exercise.isKitesurf))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .fixedSize(horizontal: false, vertical: true)

                    setupTideCard(snap)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        windMetricTile(title: "Vento", value: String(format: "%.0f km/h", snap.windSpeedKmh), icon: "wind")
                        windMetricTile(
                            title: "Direção",
                            value: "\(Int(snap.windDirectionDegrees.rounded()))° · \(snap.windLabel)",
                            icon: "safari"
                        )
                        if let gusts = snap.windGustsKmh {
                            windMetricTile(title: "Rajadas", value: String(format: "%.0f km/h", gusts), icon: "tornado")
                        }
                        if let wave = snap.waveHeightMeters {
                            windMetricTile(title: "Ondas", value: String(format: "%.1f m", wave), icon: "water.waves")
                        }
                        if let period = snap.wavePeriodSeconds {
                            windMetricTile(title: "Período", value: String(format: "%.0f s", period), icon: "timer")
                        }
                        windMetricTile(title: "Atualizado", value: snap.updatedAtText, icon: "clock")
                    }

                    if !snap.marineHours.isEmpty {
                        Text("Próximas horas")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(snap.marineHours.prefix(6)) { hour in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(hour.hourLabel)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(AppTheme.accent)
                                        if let sea = hour.seaLevelMeters {
                                            Text(String(format: "%+.2f m", sea))
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(AppTheme.textPrimary)
                                        }
                                        if let wave = hour.waveHeightMeters {
                                            Text(String(format: "%.1f m ↗", wave))
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.background.opacity(0.55))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    Text(snap.locationLabel)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                } else if let windLoadError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(AppTheme.accentSecondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(windLoadError)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Ative a internet e a localização, depois toque em Atualizar.")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    HStack {
                        Text("Vento \(Int(windSpeedKmh)) km/h")
                        Spacer()
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                    Slider(value: $windSpeedKmh, in: 0...60, step: 1)
                        .tint(AppTheme.accent)
                    HStack {
                        Text("Direção \(Int(windDirectionDegrees))° · \(WindDirectionLabels.label(degrees: windDirectionDegrees))")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    Slider(value: $windDirectionDegrees, in: 0...359, step: 5)
                        .tint(AppTheme.accentSecondary)
                } else {
                    Text("Condições serão carregadas assim que a localização e a internet estiverem prontas.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding()
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    /// Card de maré com altura real (internet) e selo de favorabilidade.
    private func setupTideCard(_ snap: OpenMeteoWindService.Snapshot) -> some View {
        let fav = snap.favorability(isKitesurf: exercise.isKitesurf)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Maré", systemImage: "water.waves")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(fav.badgeLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(setupFavColor(fav))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(setupFavColor(fav).opacity(0.16))
                    .clipShape(Capsule())
            }
            if let sea = snap.seaLevelHeightMeters {
                Text(String(format: "%+.2f m MSL", sea))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
            } else if let h = snap.displayTideHeightMeters {
                Text(String(format: "%.2f m", h))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Text(snap.estimatedTideLabel)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            if fav == .favorable {
                Text(exercise.isKitesurf
                     ? "Maré e vento favoráveis — boa janela de kite."
                     : "Maré favorável — boas chances no pico.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.green)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(fav == .favorable ? Color.green.opacity(0.12) : AppTheme.background.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(fav == .favorable ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    private func setupFavColor(_ fav: TideWindFavorability) -> Color {
        switch fav {
        case .favorable: return .green
        case .moderate: return AppTheme.accentSecondary
        case .unfavorable: return .orange
        case .unknown: return AppTheme.textSecondary
        }
    }

    private func windMetricTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.75)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.background.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Remo

    private var rowingSetupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Embarcação")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Escolha o barco para calibrar equilíbrio e simetria (Single, Double, Four) ou o ergométrico.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(RowingBoatType.allCases) { boat in
                Button {
                    selectedRowingBoat = boat
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: boat.icon)
                            .font(.title3)
                            .foregroundStyle(selectedRowingBoat == boat ? .white : AppTheme.accent)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(boat.rawValue)
                                .font(.headline)
                                .foregroundStyle(selectedRowingBoat == boat ? .white : AppTheme.textPrimary)
                            Text(boat.detail)
                                .font(.caption)
                                .foregroundStyle(
                                    selectedRowingBoat == boat
                                    ? .white.opacity(0.85)
                                    : AppTheme.textSecondary
                                )
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        if selectedRowingBoat == boat {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding()
                    .background(selectedRowingBoat == boat ? AppTheme.accent : AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if selectedRowingBoat.emphasizesBalance {
                Label(
                    "Sensores do iPhone e Apple Watch medem oscilações, equilíbrio do barco e simetria E/D.",
                    systemImage: "gyroscope"
                )
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Escalada

    private var climbingSetupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Modalidade")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                    ForEach(ClimbingDiscipline.allCases) { discipline in
                        Button {
                            climbingDiscipline = discipline
                            climbingGradeSystem = discipline.preferredGradeSystem
                            climbingTargetGradeLabel = nil
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: discipline.icon)
                                Text(discipline.rawValue)
                                    .font(.caption.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                climbingDiscipline == discipline ? AppTheme.accent : AppTheme.cardBackground,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .foregroundStyle(climbingDiscipline == discipline ? .black : AppTheme.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(climbingDiscipline.detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Graduação")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Picker("Sistema", selection: $climbingGradeSystem) {
                    ForEach(ClimbingGradeSystem.allCases) { system in
                        Text(system.rawValue).tag(system)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: climbingGradeSystem) { _, _ in
                    climbingTargetGradeLabel = nil
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(climbingGradeSystem.ladder, id: \.self) { label in
                            Button {
                                climbingTargetGradeLabel = climbingTargetGradeLabel == label ? nil : label
                            } label: {
                                Text(label)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        climbingTargetGradeLabel == label ? AppTheme.accentSecondary : AppTheme.cardBackground,
                                        in: Capsule()
                                    )
                                    .foregroundStyle(climbingTargetGradeLabel == label ? .black : AppTheme.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                Text(climbingTargetGradeLabel == nil
                     ? "Meta de grau opcional — escolha para acompanhar a sessão contra o objetivo."
                     : "Meta da sessão: \(climbingTargetGradeLabel ?? "")")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if climbingDiscipline.isOutdoor {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Setor")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    TextField("Nome do setor ou via", text: $climbingAreaName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(AppTheme.textPrimary)

                    Button {
                        showsClimbingMap = true
                    } label: {
                        Label("Escolher no mapa de áreas", systemImage: "map.fill")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)

                    if let climbingArea {
                        Label(
                            "\(climbingArea.name) · \(climbingArea.gradeRange)",
                            systemImage: "mappin.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                    }

                    Label(
                        "Com o setor definido, eu busco chuva, vento e risco de raios durante a sessão.",
                        systemImage: "cloud.bolt.rain"
                    )
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $climbingUsesMotion) {
                    Text("Detectar tentativas pelos sensores")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .tint(AppTheme.accent)

                Text("Acelerômetro e giroscópio separam tempo em parede, pausas e número de tentativas.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            climbingGearWarning
        }
        .sheet(isPresented: $showsClimbingMap) {
            NavigationStack {
                ClimbingMapView { area in
                    climbingArea = area
                    climbingAreaName = area.name
                }
            }
        }
    }

    @ViewBuilder
    private var climbingGearWarning: some View {
        let gear = ClimbingGearService.shared
        let flagged = gear.overdueItems + gear.dueSoonItems
        if !flagged.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Equipamento para inspecionar", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accentSecondary)

                ForEach(flagged.prefix(3)) { item in
                    Text("• \(item.alertMessage)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppTheme.accentSecondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var climbingSetup: ClimbingSetup? {
        guard exercise.isClimbing else { return nil }
        return ClimbingSetup(
            discipline: climbingDiscipline,
            gradeSystem: climbingGradeSystem,
            targetGrade: climbingTargetGradeLabel.map {
                ClimbingGrade(system: climbingGradeSystem, label: $0)
            },
            areaName: climbingAreaName,
            areaLatitude: climbingArea?.latitude,
            areaLongitude: climbingArea?.longitude,
            usesMotionDetection: climbingUsesMotion
        )
    }

    private var rowingSPMZonesInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Faixas de SPM (Stroke Rate)")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Stroke rate em remadas por minuto. Split /500 m (quanto menor, melhor) e eficiência saem da distância, remadas e sensores.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(
                    [RowingSPMZone.recovery, .endurance, .technical, .race, .sprint],
                    id: \.self
                ) { zone in
                    HStack {
                        Circle()
                            .fill(zone.color)
                            .frame(width: 8, height: 8)
                        Text(zone.rangeLabel)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 56, alignment: .leading)
                        Text(zone.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(zone.tip)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Indicadores na sessão", systemImage: "chart.bar.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                Text("• Split /500 m · metros por remada · velocidade")
                Text("• Aceleração / desaceleração · estabilidade · equilíbrio")
                Text("• Simetria esquerda × direita (risco de lesão se assimétrico)")
            }
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.accent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var swimmingPoolSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tamanho da piscina")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Usado para calcular distância, ritmo e o diário de bordo.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(PoolLength.allCases) { pool in
                    Button {
                        useCustomPool = false
                        selectedPool = pool
                        customPoolMeters = pool.rawValue
                    } label: {
                        let isSelected = !useCustomPool && selectedPool == pool
                        VStack(spacing: 6) {
                            Text(pool.label)
                                .font(.headline)
                            Text(pool.description)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 6)
                        .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                useCustomPool = true
            } label: {
                HStack {
                    Image(systemName: "ruler")
                    Text("Personalizado")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if useCustomPool {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .foregroundStyle(useCustomPool ? AppTheme.accent : AppTheme.textPrimary)
                .padding()
                .background(useCustomPool ? AppTheme.accent.opacity(0.12) : AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if useCustomPool {
                Stepper(value: $customPoolMeters, in: 10...100, step: 1) {
                    HStack {
                        Text("Comprimento")
                        Spacer()
                        Text("\(customPoolMeters) m")
                            .font(.headline)
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }

    private var swimmingLapsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meta de voltas")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Toggle("Meta voltas", isOn: $useLapGoal)
                    .labelsHidden()
                    .tint(AppTheme.accent)
            }

            if useLapGoal {
                Text("Com o Apple Watch, as voltas são contadas automaticamente. Uma volta = comprimento da piscina (\(Int(resolvedPoolMeters)) m). Sem Watch, você pode ajustar manualmente.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Self.lapPresets, id: \.self) { laps in
                        Button {
                            targetLaps = laps
                        } label: {
                            Text("\(laps)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(targetLaps == laps ? .white : AppTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(targetLaps == laps ? AppTheme.accent : AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Stepper(value: $targetLaps, in: 1...500, step: 1) {
                    HStack {
                        Label("Voltas", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text("\(targetLaps)")
                            .font(.headline)
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .foregroundStyle(AppTheme.textPrimary)

                let meters = Double(targetLaps) * resolvedPoolMeters
                HStack {
                    Label("Distância da meta", systemImage: "ruler")
                    Spacer()
                    Text(meters >= 1000
                          ? String(format: "%.2f km", meters / 1000)
                          : "\(Int(meters.rounded())) m")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }
                .foregroundStyle(AppTheme.textPrimary)
            } else {
                Text("Sem meta de voltas — o Watch conta automaticamente; você também pode ajustar na tela e encerrar quando quiser.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var calorieGoalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meta de calorias")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Toggle("Meta kcal", isOn: $useCalorieGoal)
                    .labelsHidden()
                    .tint(AppTheme.accentSecondary)
            }

            if useCalorieGoal {
                Text("Defina quantas calorias pretende gastar neste cardio.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Self.caloriePresets, id: \.self) { kcal in
                        Button {
                            selectedCalorieGoal = kcal
                        } label: {
                            Text("\(kcal)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedCalorieGoal == kcal ? .white : AppTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedCalorieGoal == kcal ? AppTheme.accentSecondary : AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Stepper(value: $selectedCalorieGoal, in: 50...1200, step: 25) {
                    HStack {
                        Label("Personalizado", systemImage: "flame.fill")
                        Spacer()
                        Text("\(selectedCalorieGoal) kcal")
                            .font(.headline)
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                }
                .foregroundStyle(AppTheme.textPrimary)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "applewatch")
                        .foregroundStyle(AppTheme.accent)
                    Text("Sem meta definida — as calorias serão acompanhadas em tempo real pelo Apple Watch durante o treino.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Intensidade")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(CardioIntensity.allCases) { intensity in
                Button {
                    selectedIntensity = intensity
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: intensity.icon)
                            .font(.title2)
                            .foregroundStyle(selectedIntensity == intensity ? .white : intensity.color)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(intensity.rawValue)
                                .font(.headline)
                                .foregroundStyle(selectedIntensity == intensity ? .white : AppTheme.textPrimary)
                            Text(intensity.description)
                                .font(.caption)
                                .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.85) : AppTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                            if exercise.supportsSwimmingPool {
                                Text("Ritmo ref.: \(intensity.formattedSwimPace())")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.9) : intensity.color)
                            } else if exercise.supportsCustomDistanceGoals && !distanceMode.isFree {
                                if exercise.isOutdoorCycling {
                                    Text("Velocidade ref.: \(cyclingSpeedLabel(for: intensity))")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.9) : intensity.color)
                                } else {
                                    Text("Ritmo alvo: \(intensity.formattedPace())")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.9) : intensity.color)
                                }
                            } else if exercise.supportsCustomDistanceGoals && distanceMode.isFree {
                                if exercise.isOutdoorCycling {
                                    Text("Velocidade ref.: \(cyclingSpeedLabel(for: intensity))")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.9) : intensity.color)
                                } else {
                                    Text("Ritmo de referência: \(intensity.formattedPace())")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.9) : intensity.color)
                                }
                            } else {
                                Text("\(intensity.durationMinutes) min sugeridos")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.9) : intensity.color)
                            }
                        }

                        Spacer()

                        if selectedIntensity == intensity {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding()
                    .background(selectedIntensity == intensity ? intensity.color : AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Vento na Corrida

    /// Card animado de vento + melhor orientação de percurso (abaixo da intensidade).
    private var runningWindSection: some View {
        let dir = windSnapshot?.windDirectionDegrees ?? windDirectionDegrees
        let speed = windSnapshot?.windSpeedKmh ?? windSpeedKmh
        let guide = RunningWindGuide.make(speedKmh: speed, directionDegrees: dir)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Vento e posição", systemImage: "wind")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    Task { await preloadWind(force: true) }
                } label: {
                    if isLoadingWind {
                        ProgressView()
                            .tint(AppTheme.accent)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .foregroundStyle(AppTheme.accent)
                .disabled(isLoadingWind)
            }

            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                            .stroke(AppTheme.accent.opacity(0.28), lineWidth: 1)
                    )

                TransparentWindLinesView(
                    directionDegrees: dir,
                    speedKmh: max(speed, 6),
                    tint: AppTheme.accent.opacity(0.95),
                    baseOpacity: 0.55,
                    lineCount: 8
                )
                .frame(height: 168)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 12) {
                    if isLoadingWind && windSnapshot == nil {
                        HStack(spacing: 10) {
                            ProgressView().tint(AppTheme.accent)
                            Text("Buscando vento e posição…")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.top, 4)
                    } else if let error = windLoadError, windSnapshot == nil {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button("Tentar de novo") {
                            Task { await preloadWind(force: true) }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            runningWindCompass(directionDegrees: dir, speedKmh: speed)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(guide.intensityTitle)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.accent)

                                HStack(spacing: 6) {
                                    Image(systemName: "speedometer")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.accent)
                                    Text(String(format: "%.0f km/h", speed))
                                        .font(.title3.weight(.bold).monospacedDigit())
                                        .foregroundStyle(AppTheme.textPrimary)
                                }

                                Text("Direção: \(Int(dir.rounded()))° · \(guide.fromLabel)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)

                                Text("Vento de \(guide.fromLabel) → \(guide.towardLabel)")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label("Melhor posição para correr", systemImage: "figure.run")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.accent)

                            Text(guide.bestPositionSummary)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 8) {
                                runningDirectionChip(
                                    title: "Ida",
                                    detail: "contra · \(guide.outboundLabel)",
                                    icon: "arrow.up.right"
                                )
                                runningDirectionChip(
                                    title: "Volta",
                                    detail: "a favor · \(guide.returnLabel)",
                                    icon: "arrow.down.left"
                                )
                            }

                            Text(guide.detailTip)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.10))
                        )

                        if let snap = windSnapshot {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.caption2)
                                Text(snap.locationLabel)
                                    .lineLimit(1)
                                Spacer()
                                Text(snap.updatedAtText)
                            }
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(14)
            }
            .frame(minHeight: 160)
        }
    }

    private func runningWindCompass(directionDegrees: Double, speedKmh: Double) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.92 + 0.08 * sin(t * (1.4 + min(speedKmh, 40) / 35.0))
            let spinBoost = sin(t * 2.2) * 6

            ZStack {
                Circle()
                    .stroke(AppTheme.accent.opacity(0.25), lineWidth: 2)
                    .frame(width: 72, height: 72)

                ForEach(["N", "L", "S", "O"], id: \.self) { mark in
                    Text(mark)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .offset(y: mark == "N" ? -28 : mark == "S" ? 28 : 0)
                        .offset(x: mark == "L" ? 28 : mark == "O" ? -28 : 0)
                }

                Image(systemName: "location.north.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .rotationEffect(.degrees(directionDegrees + spinBoost))
                    .scaleEffect(pulse)
                    .shadow(color: AppTheme.accent.opacity(0.45), radius: 6, y: 0)

                Text("VENTO")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(AppTheme.textSecondary)
                    .offset(y: 22)
            }
            .frame(width: 76, height: 76)
        }
        .accessibilityLabel("Direção do vento \(Int(directionDegrees.rounded())) graus")
    }

    private func runningDirectionChip(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.background.opacity(0.55))
        )
    }

    private func cyclingSpeedLabel(for intensity: CardioIntensity) -> String {
        switch intensity {
        case .low: return "~18 km/h"
        case .medium: return "~22 km/h"
        case .high: return "~28 km/h"
        }
    }

    private var summarySection: some View {
        VStack(spacing: 10) {
            if exercise.isWaterSport {
                HStack {
                    Label("Modalidade", systemImage: exercise.icon)
                    Spacer()
                    Text(exercise.isKitesurf ? "Kitesurf" : "Surf")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
                if exercise.isKitesurf {
                    HStack {
                        Label("Equipamento", systemImage: kiteEquipment.icon)
                        Spacer()
                        Text(kiteEquipment.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                    HStack {
                        Label("Modo de velejo", systemImage: ridingMode.icon)
                        Spacer()
                        Text(ridingMode.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                }
                HStack {
                    Label("Prancha", systemImage: selectedBoard.icon)
                    Spacer()
                    Text(selectedBoard.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }
                HStack {
                    Label("Vento", systemImage: "wind")
                    Spacer()
                    Text("\(Int(windSpeedKmh)) km/h · \(WindDirectionLabels.label(degrees: windDirectionDegrees))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                if let snap = windSnapshot, let gusts = snap.windGustsKmh {
                    HStack {
                        Label("Rajadas", systemImage: "tornado")
                        Spacer()
                        Text(String(format: "%.0f km/h", gusts))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                }
                HStack {
                    Label("Maré", systemImage: "water.waves")
                    Spacer()
                    Text(tideLabel == "Não informado" || tideLabel.isEmpty
                         ? "Aguardando…"
                         : String(format: "%@ · %.2f m", tideLabel, tideHeightMeters))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                if let snap = windSnapshot {
                    let fav = snap.favorability(isKitesurf: exercise.isKitesurf)
                    HStack {
                        Label("Condição", systemImage: fav == .favorable ? "checkmark.seal.fill" : "info.circle")
                        Spacer()
                        Text(fav.badgeLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(setupFavColor(fav))
                    }
                }
            } else if config.isFreeRun {
                HStack {
                    Label("Modo", systemImage: exercise.icon)
                    Spacer()
                    Text(exercise.supportsCustomDistanceGoals ? "Sem meta de km" : "Apenas corrida")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
                if exercise.isOutdoorCycling {
                    HStack {
                        Label("Velocidade de referência", systemImage: "speedometer")
                        Spacer()
                        Text(cyclingSpeedLabel(for: selectedIntensity))
                            .font(.headline)
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                } else if exercise.supportsCustomDistanceGoals {
                    HStack {
                        Label("Ritmo de referência", systemImage: "speedometer")
                        Spacer()
                        Text(selectedIntensity.formattedPace())
                            .font(.headline)
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                }
            } else if config.hasDistanceTarget {
                HStack {
                    Label("Distância meta", systemImage: exercise.icon)
                    Spacer()
                    Text(String(format: abs(config.targetDistanceKm - config.targetDistanceKm.rounded()) < 0.05
                                   ? "%.0f km"
                                   : "%.1f km",
                                 config.targetDistanceKm))
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
                HStack {
                    Label("Tempo estimado", systemImage: "clock.fill")
                    Spacer()
                    Text(PaceFormatting.formatDuration(seconds: config.targetDurationSeconds))
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
                if exercise.isOutdoorCycling {
                    HStack {
                        Label("Velocidade alvo", systemImage: "speedometer")
                        Spacer()
                        Text(cyclingSpeedLabel(for: selectedIntensity))
                            .font(.headline)
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                } else {
                    HStack {
                        Label("Ritmo alvo", systemImage: "speedometer")
                        Spacer()
                        Text(selectedIntensity.formattedPace())
                            .font(.headline)
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                }
            } else if config.isSwimmingSession {
                HStack {
                    Label("Piscina", systemImage: "figure.pool.swim")
                    Spacer()
                    Text("\(Int(config.resolvedPoolLengthMeters)) m")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
                if let laps = config.targetSwimLaps, laps > 0 {
                    HStack {
                        Label("Meta de voltas", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text("\(laps)")
                            .font(.headline)
                            .foregroundStyle(AppTheme.accent)
                    }
                    HStack {
                        Label("Distância meta", systemImage: "ruler")
                        Spacer()
                        Text(String(format: "%.0f m", config.targetDistanceKm * 1000))
                            .font(.headline)
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                    HStack {
                        Label("Tempo estimado", systemImage: "clock.fill")
                        Spacer()
                        Text(PaceFormatting.formatDuration(seconds: config.targetDurationSeconds))
                            .font(.headline)
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                HStack {
                    Label("Ritmo ref.", systemImage: "speedometer")
                    Spacer()
                    Text(selectedIntensity.formattedSwimPace())
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            } else {
                HStack {
                    Label("Duração sugerida", systemImage: "clock.fill")
                    Spacer()
                    Text("\(selectedIntensity.durationMinutes) min")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
            }
            if exercise.isWaterSport {
                HStack {
                    Label("Calorias", systemImage: "flame.fill")
                    Spacer()
                    Text("GPS + Watch em tempo real")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            } else if config.isFreeRun || config.hasDistanceTarget || config.isOutdoorCyclingSession {
                HStack {
                    Label("Calorias (referência)", systemImage: "flame.fill")
                    Spacer()
                    Text("Acompanhe durante o treino")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            } else if config.isSwimmingSession {
                let estimateSeconds = max(config.targetDurationSeconds, selectedIntensity.durationMinutes * 60)
                let meters = config.targetDistanceKm > 0
                    ? config.targetDistanceKm * 1000
                    : Double(20) * config.resolvedPoolLengthMeters
                let est = config.estimatedSwimCalories(
                    elapsedSeconds: estimateSeconds,
                    distanceMeters: meters,
                    weightKg: authService.currentUser?.weight ?? 70
                )
                HStack {
                    Label("Calorias estimadas", systemImage: "flame.fill")
                    Spacer()
                    Text("~\(Int(est.rounded())) kcal")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            } else {
                HStack {
                    Label("Calorias estimadas", systemImage: "flame.fill")
                    Spacer()
                    Text("~\(Int(config.estimatedCalories(for: config.targetDurationSeconds))) kcal")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            }
            if config.hasCalorieGoal {
                HStack {
                    Label("Meta de calorias", systemImage: "target")
                    Spacer()
                    Text("\(config.targetCalories ?? 0) kcal")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var startButton: some View {
        Button {
            if exercise.isWaterSport {
                showWindConditions = true
            } else {
                startCardioSession()
            }
        } label: {
            Label(
                {
                    if config.isRunningSession { return "Iniciar Corrida" }
                    if config.isSwimmingSession { return "Iniciar Natação" }
                    if config.isOutdoorCyclingSession { return "Iniciar Pedal" }
                    if config.isOutdoorWalkingSession { return "Iniciar Caminhada" }
                    if config.isKitesurfSession { return "Iniciar Kitesurf" }
                    if config.isSurfSession { return "Iniciar Surf" }
                    return "Iniciar Cardio"
                }(),
                systemImage: "play.fill"
            )
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private func startCardioSession(windSnapshot: OpenMeteoWindService.Snapshot? = nil) {
        let sessionConfig = makeConfig(windSnapshot: windSnapshot)
        guard workoutStore.startCardioSession(config: sessionConfig) else { return }
        watchConnectivity.startCardioOnWatch(
            workoutName: sessionConfig.title,
            targetSeconds: sessionConfig.targetDurationSeconds,
            exerciseName: sessionConfig.exercise.name,
            targetCalories: sessionConfig.targetCalories,
            waterSportMode: sessionConfig.isWaterSportSession,
            isKitesurf: sessionConfig.isKitesurfSession,
            swimmingMode: sessionConfig.isSwimmingSession,
            poolLengthMeters: sessionConfig.resolvedPoolLengthMeters
        )
        let athleteName = authService.currentUser?.greetingName ?? "Atleta"
        NotificationService.shared.deliverCardioStartNotification(
            sessionTitle: sessionConfig.title,
            athleteName: athleteName
        )
        // MainTabView hosts ActiveCardioView for the whole session (minimize-safe).
        workoutStore.resumeActiveWorkout()
        dismiss()
    }
}

/// Card de modalidade cardio — mesmo formato hero da musculação (imagem + gradiente + título).
struct CardioExerciseCard: View {
    let exercise: CardioExercise
    /// Plano mínimo quando a modalidade exige upgrade.
    var lockedByPlan: PlanTier? = nil

    private var featureLabel: String {
        if exercise.supportsDistanceGoals { return "Livre ou 5–40 km" }
        if exercise.supportsSwimmingPool { return "Piscina e voltas" }
        if exercise.supportsOutdoorGPS { return "Mapa GPS" }
        if exercise.isStationaryBike { return "Indoor · sem GPS" }
        if exercise.isWaterSport { return "Spot e condições" }
        return String(format: "~%.0f kcal/min", exercise.caloriesPerMinute)
    }

    private var featureIcon: String {
        if exercise.supportsDistanceGoals || exercise.supportsCustomDistanceGoals { return "map" }
        if exercise.supportsSwimmingPool { return "figure.pool.swim" }
        if exercise.supportsOutdoorGPS || exercise.isWaterSport { return "location.fill" }
        if exercise.isStationaryBike { return "house.fill" }
        return "flame.fill"
    }

    var body: some View {
        WorkoutProgramHeroCard(
            title: exercise.name,
            subtitle: exercise.description,
            accent: exercise.coverColors.first ?? AppTheme.accentSecondary,
            imageName: exercise.coverImageName,
            systemImage: exercise.icon,
            coverColors: exercise.coverColors,
            footerLabels: [(icon: featureIcon, text: featureLabel)],
            lockedByPlan: lockedByPlan
        )
    }
}

// MARK: - Guia de vento para corrida

/// Orienta percurso ida/volta com base no vento (ida contra, volta a favor).
struct RunningWindGuide: Equatable {
    let fromLabel: String
    let towardLabel: String
    let outboundLabel: String
    let returnLabel: String
    let intensityTitle: String
    let bestPositionSummary: String
    let detailTip: String

    static func make(speedKmh: Double, directionDegrees: Double) -> RunningWindGuide {
        let from = WindDirectionLabels.label(degrees: directionDegrees)
        let toward = WindDirectionLabels.label(degrees: directionDegrees + 180)
        // Correr em direção à origem do vento = contra o vento.
        let outbound = from
        let returnDir = toward

        let intensity: String
        let tip: String
        let summary: String

        switch speedKmh {
        case ..<8:
            intensity = "Vento fraco"
            summary = "Qualquer direção é confortável. No ida e volta, prefira o eixo \(outbound)–\(returnDir)."
            tip = "Aproveite para focar no ritmo; o vento quase não muda o esforço."
        case 8..<18:
            intensity = "Vento moderado"
            summary = "Melhor percurso: eixo \(outbound)–\(returnDir). Saia para \(outbound) (contra) e volte para \(returnDir) (a favor)."
            tip = "Ida contra o vento aquece bem sem deixar a volta estafante no vento de frente."
        case 18..<28:
            intensity = "Vento forte"
            summary = "Priorize ida/volta no eixo \(outbound)–\(returnDir): contra (\(outbound)) na ida e a favor (\(returnDir)) na volta."
            tip = "Evite longos trechos laterais (vento de lado); se possível, use trechos com abrigo natural."
        default:
            intensity = "Vento muito forte"
            summary = "Se exposto, use o eixo \(outbound)–\(returnDir) com ida contra e volta a favor. Prefira rotas abrigadas."
            tip = "Reduza a meta de ritmo e proteja o rosto; em rajadas, encurte o trecho aberto."
        }

        return RunningWindGuide(
            fromLabel: from,
            towardLabel: toward,
            outboundLabel: outbound,
            returnLabel: returnDir,
            intensityTitle: intensity,
            bestPositionSummary: summary,
            detailTip: tip
        )
    }
}

// MARK: - GPS do SPOT no setup

@MainActor
final class SpotLocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var statusMessage = "Obtendo GPS…"

    private let manager = CLLocationManager()
    private nonisolated(unsafe) weak var nonisolatedWeakSelf: SpotLocationHelper?

    override init() {
        super.init()
        nonisolatedWeakSelf = self
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        statusMessage = "Solicitando localização…"
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            statusMessage = "Permissão de localização negada."
        default:
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        WeakMainActorBox.schedule(nonisolatedWeakSelf) { this in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                this.manager.requestLocation()
            } else if status == .denied {
                this.statusMessage = "Permissão de localização negada."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        WeakMainActorBox.schedule(nonisolatedWeakSelf) { this in
            this.coordinate = loc.coordinate
            this.statusMessage = "Localização sincronizada com o mapa."
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        WeakMainActorBox.schedule(nonisolatedWeakSelf) { this in
            this.statusMessage = message
        }
    }
}
