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
    @State private var tideLabel = "Enchente"
    @State private var tideHeightMeters: Double = 1.2
    @Environment(\.dismiss) private var dismiss
    @StateObject private var spotLocator = SpotLocationHelper()

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
            waterSportSetup: waterSetup
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                if exercise.supportsCustomDistanceGoals {
                    outdoorDistanceSection
                }
                if exercise.isWaterSport {
                    waterSportSetupSection
                }
                if exercise.supportsSwimmingPool {
                    swimmingPoolSection
                    swimmingLapsSection
                }
                calorieGoalSection
                intensitySection
                summarySection
                startButton
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
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
            if exercise.isWaterSport {
                spotLocator.requestLocation()
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 72, height: 72)
                Image(systemName: exercise.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.accent)
            }

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
                        Text(km == km.rounded() ? "\(Int(km))" : String(format: "%.1f", km))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
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

                Text("3. Modo de velejo")
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

            Text(exercise.isKitesurf ? "2. Tipo de prancha" : "Tipo de prancha")
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

            Text("Maré e vento")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
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

            Picker("Maré", selection: $tideLabel) {
                ForEach(WindDirectionLabels.tidePresets, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.accent)

            HStack {
                Text("Altura maré \(String(format: "%.1f", tideHeightMeters)) m")
                Spacer()
            }
            .foregroundStyle(AppTheme.textPrimary)
            Slider(value: $tideHeightMeters, in: 0...4, step: 0.1)
                .tint(AppTheme.accent)

            if exercise.isKitesurf {
                Text("No treino: altura de saltos via giroscópio Apple Watch + iPhone, pontos no mapa, gráficos e relatório PDF.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
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
                Text("Durante o treino você conta as voltas. Uma volta = comprimento da piscina (\(Int(resolvedPoolMeters)) m).")
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
                Text("Sem meta de voltas — conte livremente e encerre quando quiser.")
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

    private func cyclingSpeedLabel(for intensity: CardioIntensity) -> String {
        switch intensity {
        case .low: return "~18 km/h"
        case .medium: return "~22 km/h"
        case .high: return "~28 km/h"
        }
    }

    private var summarySection: some View {
        VStack(spacing: 10) {
            if config.isFreeRun {
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
            if config.isFreeRun || config.hasDistanceTarget || config.isOutdoorCyclingSession {
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
            guard workoutStore.startCardioSession(config: config) else { return }
            watchConnectivity.startCardioOnWatch(
                workoutName: config.title,
                targetSeconds: config.targetDurationSeconds,
                exerciseName: config.exercise.name,
                targetCalories: config.targetCalories,
                waterSportMode: config.isWaterSportSession,
                isKitesurf: config.isKitesurfSession
            )
            let athleteName = authService.currentUser?.greetingName ?? "Atleta"
            NotificationService.shared.deliverCardioStartNotification(
                sessionTitle: config.title,
                athleteName: athleteName
            )
            // MainTabView hosts ActiveCardioView for the whole session (minimize-safe).
            workoutStore.resumeActiveWorkout()
            dismiss()
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
}

struct CardioExerciseCard: View {
    let exercise: CardioExercise

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.accentSecondary.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: exercise.icon)
                    .font(.title2)
                    .foregroundStyle(AppTheme.accentSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text({
                    if exercise.supportsDistanceGoals {
                        return "\(exercise.description) · livre ou 5–40 km"
                    }
                    if exercise.supportsSwimmingPool {
                        return "\(exercise.description) · piscina e voltas"
                    }
                    if exercise.supportsOutdoorGPS {
                        return "\(exercise.description) · mapa GPS"
                    }
                    return exercise.description
                }())
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

// MARK: - GPS do SPOT no setup

@MainActor
final class SpotLocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var statusMessage = "Obtendo GPS…"

    private let manager = CLLocationManager()

    override init() {
        super.init()
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
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            } else if manager.authorizationStatus == .denied {
                statusMessage = "Permissão de localização negada."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let loc = locations.last {
                coordinate = loc.coordinate
                statusMessage = "Localização sincronizada com o mapa."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            statusMessage = error.localizedDescription
        }
    }
}
