import Combine
import Foundation

enum LiveHeartRateSource: String, Equatable {
    case appleWatch
    case bluetooth
    case healthKit
    case none

    var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .bluetooth: return "Bluetooth"
        case .healthKit: return "Apple Saúde"
        case .none: return "—"
        }
    }
}

/// Unifica BPM / kcal / passos com prioridade: Apple Watch > BLE > HealthKit.
@MainActor
final class LiveMetricsHub: ObservableObject {
    static let shared = LiveMetricsHub()

    @Published private(set) var heartRateBPM: Double = 0
    @Published private(set) var heartRateSource: LiveHeartRateSource = .none
    @Published private(set) var liveCalories: Double = 0
    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var todayActiveCalories: Double = 0

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let watch = WatchConnectivityManager.shared
        let ble = BluetoothHeartRateService.shared
        let health = HealthKitManager.shared

        Publishers.CombineLatest3(
            watch.$watchHeartRate,
            ble.$heartRateBPM,
            health.$currentHeartRate
        )
        .combineLatest(health.$restingHeartRate)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] heartRates, resting in
            self?.resolveHeartRate(
                watchBPM: heartRates.0,
                bleBPM: heartRates.1,
                healthBPM: heartRates.2,
                restingBPM: resting
            )
        }
        .store(in: &cancellables)

        Publishers.CombineLatest3(
            watch.$watchCalories,
            watch.$watchSteps,
            health.$todaySteps
        )
        .combineLatest(health.$todayCalories)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] tuple, todayCalories in
            guard let self else { return }
            let (watchCalories, watchSteps, healthSteps) = tuple
            self.liveCalories = max(0, watchCalories)
            self.todaySteps = max(healthSteps, watchSteps)
            self.todayActiveCalories = max(0, todayCalories)
        }
        .store(in: &cancellables)
    }

    private func resolveHeartRate(
        watchBPM: Double,
        bleBPM: Double,
        healthBPM: Double,
        restingBPM: Double
    ) {
        if watchBPM > 0 {
            heartRateBPM = watchBPM
            heartRateSource = .appleWatch
            return
        }
        if bleBPM > 0 {
            heartRateBPM = bleBPM
            heartRateSource = .bluetooth
            return
        }
        if healthBPM > 0 {
            heartRateBPM = healthBPM
            heartRateSource = .healthKit
            return
        }
        if restingBPM > 0 {
            heartRateBPM = restingBPM
            heartRateSource = .healthKit
            return
        }
        heartRateBPM = 0
        heartRateSource = .none
    }
}
