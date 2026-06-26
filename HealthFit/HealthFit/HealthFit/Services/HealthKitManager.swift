import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationError: String?
    @Published var dailyMetrics: [DailyHealthMetric] = []
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Double = 0
    @Published var currentHeartRate: Double = 0
    @Published var restingHeartRate: Double = 0

    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKQuery?

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(stepCount) }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeEnergy) }
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(heartRate) }
        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(restingHR) }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(bodyMass) }
        if let workout = HKObjectType.workoutType() as HKObjectType? { types.insert(workout) }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeEnergy) }
        if let workout = HKObjectType.workoutType() as HKSampleType? { types.insert(workout) }
        return types
    }

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthKitAvailable else {
            authorizationError = "HealthKit não disponível neste dispositivo"
            loadMockData()
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            await fetchWeeklyMetrics()
            startHeartRateObserver()
        } catch {
            authorizationError = error.localizedDescription
            loadMockData()
        }
    }

    func fetchWeeklyMetrics() async {
        guard isHealthKitAvailable, isAuthorized else {
            loadMockData()
            return
        }

        var metrics: [DailyHealthMetric] = []
        let calendar = Calendar.current

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) else { continue }
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }

            let steps = await fetchCumulativeSum(.stepCount, unit: .count(), from: start, to: end)
            let calories = await fetchCumulativeSum(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
            let rhr = await fetchDiscreteAverage(
                .restingHeartRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                from: start,
                to: end
            )

            metrics.append(DailyHealthMetric(
                date: start,
                steps: Int(steps),
                activeCalories: calories,
                restingHeartRate: rhr,
                workoutMinutes: Int.random(in: 20...60)
            ))
        }

        guard !metrics.isEmpty else {
            loadMockData()
            return
        }

        dailyMetrics = metrics
        if let today = metrics.last {
            todaySteps = today.steps
            todayCalories = today.activeCalories
            restingHeartRate = today.restingHeartRate
        }
    }

    func saveWorkout(duration: TimeInterval, calories: Double, heartRate: Double) async {
        guard isHealthKitAvailable, isAuthorized else { return }

        let startDate = Date().addingTimeInterval(-duration)
        let endDate = Date()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        do {
            try await builder.beginCollection(at: startDate)

            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let energy = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
                let sample = HKQuantitySample(
                    type: energyType,
                    quantity: energy,
                    start: startDate,
                    end: endDate
                )
                try await builder.addSamples([sample])
            }

            try await builder.addMetadata(["averageHeartRate": heartRate])
            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()
        } catch {
            // Mantém o mesmo comportamento tolerante a falhas do salvamento anterior.
        }
    }

    private func fetchCumulativeSum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        await fetchStatistic(identifier, unit: unit, from: start, to: end, options: .cumulativeSum) { result, unit in
            result?.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
    }

    private func fetchDiscreteAverage(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        await fetchStatistic(identifier, unit: unit, from: start, to: end, options: .discreteAverage) { result, unit in
            result?.averageQuantity()?.doubleValue(for: unit) ?? 0
        }
    }

    private func fetchStatistic(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date,
        options: HKStatisticsOptions,
        extract: @escaping (HKStatistics?, HKUnit) -> Double
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, result, error in
                if error != nil {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: extract(result, unit))
            }
            healthStore.execute(query)
        }
    }

    private func startHeartRateObserver() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            Task { @MainActor in
                await self?.fetchLatestHeartRate()
            }
        }
        heartRateQuery = query
        healthStore.execute(query)
    }

    private func fetchLatestHeartRate() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    Task { @MainActor in
                        self?.currentHeartRate = bpm
                    }
                }
                continuation.resume()
            }
            healthStore.execute(query)
        }
    }

    private func loadMockData() {
        let calendar = Calendar.current
        dailyMetrics = (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            return DailyHealthMetric(
                date: calendar.startOfDay(for: date),
                steps: Int.random(in: 5000...12000),
                activeCalories: Double.random(in: 200...600),
                restingHeartRate: Double.random(in: 58...72),
                workoutMinutes: Int.random(in: 0...75)
            )
        }
        if let today = dailyMetrics.last {
            todaySteps = today.steps
            todayCalories = today.activeCalories
            restingHeartRate = today.restingHeartRate
            currentHeartRate = Double.random(in: 65...85)
        }
    }
}
