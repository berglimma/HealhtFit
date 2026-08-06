import Combine
import CoreMotion
import Foundation

/// Identifica tentativas, pausas e tempo efetivo de escalada com acelerômetro + giroscópio.
///
/// O processamento roda numa fila própria e só publica na main thread a ~2 Hz — a tela de
/// sessão ativa não aguenta uma atualização por amostra sem engasgar.
@MainActor
final class ClimbingMotionService: ObservableObject {
    /// Fase corrente da sessão.
    enum Phase: String {
        case idle
        case climbing
        case resting

        var label: String {
            switch self {
            case .idle: return "Aguardando movimento"
            case .climbing: return "Em parede"
            case .resting: return "Descanso"
            }
        }

        var icon: String {
            switch self {
            case .idle: return "pause.circle"
            case .climbing: return "figure.climbing"
            case .resting: return "figure.stand"
            }
        }
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var activeClimbingSeconds = 0
    @Published private(set) var restSeconds = 0
    @Published private(set) var detectedAttempts = 0
    @Published private(set) var isRunning = false
    /// Intensidade instantânea (0–1) para o medidor da UI.
    @Published private(set) var motionIntensity: Double = 0

    private let motionManager = CMMotionManager()
    private let processingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.healthfit.climbing.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    // Limiares calibrados para movimento de escalada: tronco e braços em deslocamento
    // vertical lento, com rotação frequente — diferente da cadência de corrida.
    private let climbAccelThreshold = 0.11
    private let climbGyroThreshold = 0.55
    private let restAccelThreshold = 0.045
    /// Movimento contínuo mínimo para contar como tentativa, evitando contar um ajuste de cadeirinha.
    private let minimumAttemptSeconds: TimeInterval = 8
    /// Parada mínima para encerrar a tentativa.
    private let minimumRestSeconds: TimeInterval = 12

    private var phaseStartedAt: Date?
    private var candidatePhase: Phase = .idle
    private var candidateSince: Date?
    private var currentAttemptCounted = false
    private var isPaused = false
    private var lastPublishAt = Date.distantPast

    // MARK: - Ciclo de vida

    func start() {
        guard !isRunning else { return }
        guard motionManager.isDeviceMotionAvailable else { return }

        resetCounters()
        isRunning = true
        phaseStartedAt = Date()

        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: processingQueue) { [weak self] data, _ in
            guard let data else { return }
            let accel = data.userAcceleration
            let rotation = data.rotationRate
            let accelMagnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
            let gyroMagnitude = sqrt(
                rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z
            )

            Task { @MainActor [weak self] in
                self?.ingest(accelMagnitude: accelMagnitude, gyroMagnitude: gyroMagnitude)
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        motionManager.stopDeviceMotionUpdates()
        flushPhaseTimer()
        isRunning = false
        phase = .idle
        phaseStartedAt = nil
        motionIntensity = 0
    }

    /// Pausa manual da sessão — congela os cronômetros sem descartar o acumulado.
    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        flushPhaseTimer()
        isPaused = paused
        phaseStartedAt = paused ? nil : Date()
    }

    func exportSnapshotValues() -> (active: Int, rest: Int, attempts: Int) {
        flushPhaseTimer()
        return (activeClimbingSeconds, restSeconds, detectedAttempts)
    }

    // MARK: - Processamento

    private func ingest(accelMagnitude: Double, gyroMagnitude: Double) {
        guard isRunning, !isPaused else { return }

        let isClimbingSignal = accelMagnitude > climbAccelThreshold || gyroMagnitude > climbGyroThreshold
        let isRestSignal = accelMagnitude < restAccelThreshold && gyroMagnitude < climbGyroThreshold * 0.5

        let observed: Phase
        if isClimbingSignal {
            observed = .climbing
        } else if isRestSignal {
            observed = .resting
        } else {
            // Zona morta: mantém a fase atual em vez de oscilar.
            observed = phase == .idle ? .resting : phase
        }

        evaluateTransition(to: observed)

        // Publicação throttled: a UI não precisa de 10 Hz.
        let now = Date()
        if now.timeIntervalSince(lastPublishAt) >= 0.5 {
            lastPublishAt = now
            motionIntensity = min(1, max(accelMagnitude / 0.4, gyroMagnitude / 2.0))
            refreshElapsedCounters(now: now)
        }
    }

    /// Uma fase só troca depois de se sustentar pelo tempo mínimo — evita picos isolados.
    private func evaluateTransition(to observed: Phase) {
        let now = Date()

        guard observed != phase else {
            candidatePhase = phase
            candidateSince = nil
            if phase == .climbing, !currentAttemptCounted,
               let start = phaseStartedAt,
               now.timeIntervalSince(start) >= minimumAttemptSeconds {
                currentAttemptCounted = true
                detectedAttempts += 1
            }
            return
        }

        if candidatePhase != observed {
            candidatePhase = observed
            candidateSince = now
            return
        }

        guard let candidateSince else { return }
        let sustained = now.timeIntervalSince(candidateSince)
        let required = observed == .climbing ? 1.5 : minimumRestSeconds
        guard sustained >= required else { return }

        commitPhase(observed, at: now)
    }

    private func commitPhase(_ next: Phase, at now: Date) {
        flushPhaseTimer(now: now)
        phase = next
        phaseStartedAt = now
        candidateSince = nil
        if next == .climbing {
            currentAttemptCounted = false
        }
    }

    /// Fecha o cronômetro da fase corrente somando ao acumulado.
    private func flushPhaseTimer(now: Date = Date()) {
        guard let start = phaseStartedAt else { return }
        let elapsed = Int(now.timeIntervalSince(start).rounded())
        guard elapsed > 0 else { return }

        switch phase {
        case .climbing: activeClimbingSeconds += elapsed
        case .resting: restSeconds += elapsed
        case .idle: break
        }
        phaseStartedAt = now
    }

    private func refreshElapsedCounters(now: Date) {
        flushPhaseTimer(now: now)
    }

    private func resetCounters() {
        activeClimbingSeconds = 0
        restSeconds = 0
        detectedAttempts = 0
        motionIntensity = 0
        phase = .idle
        candidatePhase = .idle
        candidateSince = nil
        currentAttemptCounted = false
        isPaused = false
    }
}
