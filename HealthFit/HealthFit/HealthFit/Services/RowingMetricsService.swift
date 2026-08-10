import Combine
import CoreMotion
import Foundation

/// Detecta remadas e métricas de remo via acelerômetro + giroscópio (DeviceMotion).
/// SPM, split /500 m, m/remada, aceleração, equilíbrio e simetria E/D.
@MainActor
final class RowingMetricsService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var strokeCount = 0
    /// SPM instantâneo (janela recente).
    @Published private(set) var strokeRateSPM: Double = 0
    @Published private(set) var averageSPM: Double = 0
    @Published private(set) var peakSPM: Double = 0
    /// Split em segundos por 500 m (menor = melhor).
    @Published private(set) var splitSecondsPer500m: Double?
    @Published private(set) var bestSplitSecondsPer500m: Double?
    @Published private(set) var metersPerStroke: Double = 0
    @Published private(set) var efficiencyScore: Double = 0
    @Published private(set) var speedMps: Double = 0
    @Published private(set) var accelerationMps2: Double = 0
    @Published private(set) var decelerationMps2: Double = 0
    /// 0–100 — menor oscilação de roll/giro = mais estável.
    @Published private(set) var stabilityScore: Double = 75
    /// 0–100 — barco mais centrado / menos roll médio.
    @Published private(set) var balanceScore: Double = 75
    @Published private(set) var leftSideShare: Double = 0.5
    @Published private(set) var rightSideShare: Double = 0.5
    @Published private(set) var asymmetryPercent: Double = 0
    @Published private(set) var spmZone: RowingSPMZone = .unknown
    @Published private(set) var distanceMeters: Double = 0
    @Published var lastStatusMessage: String?
    @Published var boatType: RowingBoatType = .singleSkiff

    private let motion = CMMotionManager()
    private var sessionStart: Date?
    private var isPaused = false

    // Stroke detection state
    private var strokeTimestamps: [Date] = []
    private var lastStrokeAt: Date = .distantPast
    private var prevSmoothLong: Double = 0
    private var smoothLong: Double = 0
    private var rising = false
    private var peakCandidate: Double = 0

    // Symmetry / balance accumulators
    private var leftPeakSum: Double = 0
    private var rightPeakSum: Double = 0
    private var rollSamples: [Double] = []
    private var gyroSamples: [Double] = []
    private var accelPosSamples: [Double] = []
    private var accelNegSamples: [Double] = []
    private var peakSpeedMps: Double = 0
    private var lastSpeedMps: Double = 0

    private let minStrokeInterval: TimeInterval = 0.42 // ~143 SPM max
    private let maxStrokeInterval: TimeInterval = 3.5 // ~17 SPM min
    private let peakThreshold: Double = 0.22 // m/s² user accel long axis
    private let samplePublishEvery = 3
    private var sampleCounter = 0
    private let processingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.healthfit.rowing.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    private var totalElapsedForAvg: TimeInterval {
        guard let start = sessionStart else { return 0 }
        return Date().timeIntervalSince(start)
    }

    func start(boat: RowingBoatType = .singleSkiff) {
        guard !isRunning else { return }
        boatType = boat
        resetMetrics()
        sessionStart = .now
        isRunning = true
        isPaused = false
        lastStatusMessage = "Sensores de remo ativos (acel. + giro)"
        startHardware()
    }

    private func startHardware() {
        let box = WeakMainActorBox(self)
        if motion.isDeviceMotionAvailable {
            // ~12 Hz: detecta remadas com bem menos custo que 25 Hz.
            motion.deviceMotionUpdateInterval = 0.08
            motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: processingQueue) { data, _ in
                guard let data else { return }
                box.run { this in
                    this.handleDeviceMotion(data)
                }
            }
        } else {
            lastStatusMessage = "DeviceMotion indisponível neste dispositivo"
        }
    }

    func stop() {
        isRunning = false
        isPaused = false
        motion.stopDeviceMotionUpdates()
        recomputeDerivedMetrics()
    }

    func setPaused(_ paused: Bool) {
        guard isRunning, isPaused != paused else { return }
        isPaused = paused
        if paused {
            motion.stopDeviceMotionUpdates()
        } else {
            startHardware()
        }
    }

    /// Distância e velocidade da sessão (GPS no barco; estimativa no erg).
    func updateKinematics(distanceMeters: Double, speedMetersPerSecond: Double, elapsedSeconds: Double) {
        self.distanceMeters = max(0, distanceMeters)
        let speed = max(0, speedMetersPerSecond)
        if speed > peakSpeedMps { peakSpeedMps = speed }
        speedMps = speed

        let delta = speed - lastSpeedMps
        if delta > 0.05 {
            accelPosSamples.append(min(delta * 2.5, 6))
            if accelPosSamples.count > 80 { accelPosSamples.removeFirst(accelPosSamples.count - 80) }
            accelerationMps2 = accelPosSamples.suffix(12).reduce(0, +) / Double(min(12, accelPosSamples.count))
        } else if delta < -0.05 {
            accelNegSamples.append(min(abs(delta) * 2.5, 6))
            if accelNegSamples.count > 80 { accelNegSamples.removeFirst(accelNegSamples.count - 80) }
            decelerationMps2 = accelNegSamples.suffix(12).reduce(0, +) / Double(min(12, accelNegSamples.count))
        }
        lastSpeedMps = speed

        if let split = RowingMetricsMath.splitSecondsPer500m(speedMetersPerSecond: speed) {
            splitSecondsPer500m = split
            if bestSplitSecondsPer500m == nil || split < (bestSplitSecondsPer500m ?? .greatestFiniteMagnitude) {
                // Só conta split “melhor” com velocidade estável.
                if speed > 0.8 {
                    bestSplitSecondsPer500m = split
                }
            }
        } else if let avg = RowingMetricsMath.splitSecondsPer500m(
            distanceMeters: distanceMeters,
            elapsedSeconds: elapsedSeconds
        ) {
            splitSecondsPer500m = avg
        }

        metersPerStroke = RowingMetricsMath.metersPerStroke(
            distanceMeters: distanceMeters,
            strokes: strokeCount
        )
        recomputeEfficiency()
    }

    /// Reforço de aceleração lateral vinda do Apple Watch (quando disponível).
    func ingestWatchSideLoad(lateralG: Double) {
        guard isRunning, !isPaused, lateralG.isFinite else { return }
        // lateralG > 0 ≈ direito; < 0 ≈ esquerdo (convenção app).
        if lateralG >= 0 {
            rightPeakSum += abs(lateralG)
        } else {
            leftPeakSum += abs(lateralG)
        }
        updateSymmetry()
    }

    func exportSnapshot() -> RowingSessionSnapshot {
        recomputeDerivedMetrics()
        let avgSplit: Double? = {
            if let s = splitSecondsPer500m { return s }
            return RowingMetricsMath.splitSecondsPer500m(
                distanceMeters: distanceMeters,
                elapsedSeconds: max(1, totalElapsedForAvg)
            )
        }()
        return RowingSessionSnapshot(
            boatType: boatType,
            totalStrokes: strokeCount,
            averageSPM: averageSPM,
            peakSPM: peakSPM,
            averageSplitSecondsPer500m: avgSplit,
            bestSplitSecondsPer500m: bestSplitSecondsPer500m,
            metersPerStroke: metersPerStroke,
            efficiencyScore: efficiencyScore,
            stabilityScore: stabilityScore,
            balanceScore: balanceScore,
            leftSideShare: leftSideShare,
            rightSideShare: rightSideShare,
            asymmetryPercent: asymmetryPercent,
            peakSpeedMps: peakSpeedMps,
            averageAcceleration: accelerationMps2,
            averageDeceleration: decelerationMps2,
            distanceMeters: distanceMeters
        )
    }

    // MARK: - Motion

    private func handleDeviceMotion(_ data: CMDeviceMotion) {
        guard isRunning, !isPaused else { return }

        let ua = data.userAcceleration
        // Eixo longitudinal: prioriza y (remo com phone na base / bolso); fallback z.
        let longRaw = abs(ua.y) > abs(ua.z) * 0.85 ? ua.y : ua.z
        let lateral = ua.x
        let roll = data.attitude.roll
        let gyroMag = sqrt(
            data.rotationRate.x * data.rotationRate.x
                + data.rotationRate.y * data.rotationRate.y
                + data.rotationRate.z * data.rotationRate.z
        )

        // EMA suaviza ruído.
        smoothLong = smoothLong * 0.70 + longRaw * 0.30
        let delta = smoothLong - prevSmoothLong
        prevSmoothLong = smoothLong

        sampleCounter += 1
        if sampleCounter % samplePublishEvery == 0 {
            rollSamples.append(roll)
            gyroSamples.append(gyroMag)
            if rollSamples.count > 120 { rollSamples.removeFirst(rollSamples.count - 120) }
            if gyroSamples.count > 120 { gyroSamples.removeFirst(gyroSamples.count - 120) }
            updateStabilityAndBalance()
        }

        // Detecção de pico na fase de propulsão (userAcceleration positiva ao longo).
        if delta > 0.01 {
            rising = true
            peakCandidate = max(peakCandidate, smoothLong)
        } else if rising, delta < -0.008 {
            // Pico confirmado ao começar a descer.
            if peakCandidate >= peakThreshold {
                registerStrokeIfValid(peakLongitudinal: peakCandidate, lateral: lateral, roll: roll)
            }
            rising = false
            peakCandidate = 0
        }
    }

    private func registerStrokeIfValid(peakLongitudinal: Double, lateral: Double, roll: Double) {
        let now = Date()
        let dt = now.timeIntervalSince(lastStrokeAt)
        guard dt >= minStrokeInterval else { return }
        // Evita “fantasma” após pausa longa sem reabrir sequência (OK).
        if dt > maxStrokeInterval * 3, strokeCount > 0 {
            // Reinicia cadência mas conta a remada.
        }

        lastStrokeAt = now
        strokeTimestamps.append(now)
        if strokeTimestamps.count > 40 {
            strokeTimestamps.removeFirst(strokeTimestamps.count - 40)
        }
        strokeCount += 1

        // Simetria: roll e lateral — positivo ~ direito, negativo ~ esquerdo.
        let sideSignal = lateral * 0.65 + sin(roll) * 0.35
        if sideSignal >= 0 {
            rightPeakSum += abs(sideSignal) + peakLongitudinal * 0.15
        } else {
            leftPeakSum += abs(sideSignal) + peakLongitudinal * 0.15
        }
        updateSymmetry()
        recomputeSPM()
        metersPerStroke = RowingMetricsMath.metersPerStroke(
            distanceMeters: distanceMeters,
            strokes: strokeCount
        )
        recomputeEfficiency()

        lastStatusMessage = String(
            format: "Remada #%d · %.0f SPM · %@",
            strokeCount,
            strokeRateSPM,
            spmZone.rawValue
        )
    }

    private func recomputeSPM() {
        let now = Date()
        let window = strokeTimestamps.filter { now.timeIntervalSince($0) <= 20 }
        if window.count >= 2, let first = window.first, let last = window.last {
            let span = last.timeIntervalSince(first)
            if span > 0.4 {
                let instant = Double(window.count - 1) / span * 60.0
                strokeRateSPM = min(max(instant, 0), 55)
            }
        } else if strokeCount >= 1, let start = sessionStart {
            let elapsed = now.timeIntervalSince(start)
            if elapsed > 5 {
                strokeRateSPM = Double(strokeCount) / elapsed * 60.0
            }
        }

        if let start = sessionStart {
            let elapsed = max(1, now.timeIntervalSince(start))
            averageSPM = Double(strokeCount) / elapsed * 60.0
        }
        if strokeRateSPM > peakSPM {
            peakSPM = strokeRateSPM
        }
        spmZone = RowingSPMZone.classify(spm: strokeRateSPM)
    }

    private func updateSymmetry() {
        let total = leftPeakSum + rightPeakSum
        guard total > 0.001 else {
            leftSideShare = 0.5
            rightSideShare = 0.5
            asymmetryPercent = 0
            return
        }
        leftSideShare = leftPeakSum / total
        rightSideShare = rightPeakSum / total
        asymmetryPercent = abs(leftSideShare - rightSideShare) * 100.0
    }

    private func updateStabilityAndBalance() {
        guard !rollSamples.isEmpty else { return }
        let meanRoll = rollSamples.reduce(0, +) / Double(rollSamples.count)
        let rollVar = rollSamples.reduce(0.0) { $0 + ($1 - meanRoll) * ($1 - meanRoll) }
            / Double(rollSamples.count)
        let rollStd = sqrt(rollVar)

        let meanGyro = gyroSamples.isEmpty
            ? 0
            : gyroSamples.reduce(0, +) / Double(gyroSamples.count)

        // Menor oscilação → maior estabilidade.
        let stabilityRaw = 100 - min(100, rollStd * 180 + meanGyro * 25)
        stabilityScore = max(0, min(100, stabilityRaw))

        // Equilíbrio: roll médio próximo de 0.
        let balanceRaw = 100 - min(100, abs(meanRoll) * 120)
        balanceScore = max(0, min(100, balanceRaw))
        recomputeEfficiency()
    }

    private func recomputeEfficiency() {
        efficiencyScore = RowingMetricsMath.efficiencyScore(
            metersPerStroke: metersPerStroke,
            speedMps: speedMps,
            stabilityScore: stabilityScore,
            balanceScore: balanceScore,
            asymmetryPercent: asymmetryPercent
        )
    }

    private func recomputeDerivedMetrics() {
        recomputeSPM()
        updateSymmetry()
        updateStabilityAndBalance()
        metersPerStroke = RowingMetricsMath.metersPerStroke(
            distanceMeters: distanceMeters,
            strokes: strokeCount
        )
        recomputeEfficiency()
    }

    private func resetMetrics() {
        strokeCount = 0
        strokeRateSPM = 0
        averageSPM = 0
        peakSPM = 0
        splitSecondsPer500m = nil
        bestSplitSecondsPer500m = nil
        metersPerStroke = 0
        efficiencyScore = 0
        speedMps = 0
        accelerationMps2 = 0
        decelerationMps2 = 0
        stabilityScore = 75
        balanceScore = 75
        leftSideShare = 0.5
        rightSideShare = 0.5
        asymmetryPercent = 0
        spmZone = .unknown
        distanceMeters = 0
        strokeTimestamps = []
        lastStrokeAt = .distantPast
        prevSmoothLong = 0
        smoothLong = 0
        rising = false
        peakCandidate = 0
        leftPeakSum = 0
        rightPeakSum = 0
        rollSamples = []
        gyroSamples = []
        accelPosSamples = []
        accelNegSamples = []
        peakSpeedMps = 0
        lastSpeedMps = 0
        sampleCounter = 0
    }
}
