import Combine
import CoreLocation
import CoreMotion
import Foundation

/// Captura aceleração e estima saltos (altímetro relativo + magnitude de aceleração).
/// Recebe eventos manual/Watch e marca GPS do salto.
@MainActor
final class JumpMetricsService: ObservableObject {
    @Published private(set) var jumps: [SurfJumpEvent] = []
    @Published private(set) var accelerationSamples: [SurfAccelSample] = []
    @Published private(set) var liveAccelerationG: Double = 1
    @Published private(set) var relativeAltitudeMeters: Double = 0
    @Published private(set) var isRunning = false
    @Published var lastStatusMessage: String?

    private let motion = CMMotionManager()
    private let altimeter = CMAltimeter()
    private var sessionStart: Date?
    private var baselineAltitude: Double?
    private var possibleTakeoffAltitude: Double?
    private var possibleTakeoffTime: Date?
    private var isInAir = false
    private var sampleCounter = 0
    private let sampleEvery = 4 // ~ reduz frequência de persistência
    /// Internal latest G for jump detection (not every sample publishes to UI).
    private var latestAccelerationG: Double = 1
    private var lastPublishedLiveG: Double = 1
    private var lastLiveGPublishAt: Date = .distantPast
    private var latestRelativeAltitude: Double = 0
    private var lastPublishedAltitude: Double = 0
    private var lastAltitudePublishAt: Date = .distantPast

    private var locationProvider: (() -> CLLocation?)?
    private var isPaused = false
    private let processingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.healthfit.jump.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    func configure(locationProvider: @escaping () -> CLLocation?) {
        self.locationProvider = locationProvider
    }

    func start() {
        guard !isRunning else { return }
        jumps = []
        accelerationSamples = []
        relativeAltitudeMeters = 0
        baselineAltitude = nil
        possibleTakeoffAltitude = nil
        isInAir = false
        sampleCounter = 0
        latestAccelerationG = 1
        lastPublishedLiveG = 1
        lastLiveGPublishAt = .distantPast
        latestRelativeAltitude = 0
        lastPublishedAltitude = 0
        lastAltitudePublishAt = .distantPast
        sessionStart = .now
        isRunning = true
        isPaused = false
        lastStatusMessage = "Sensores de salto ativos"
        startHardware()
    }

    /// Pausa o hardware (acel./altímetro) sem perder os saltos já capturados.
    func setPaused(_ paused: Bool) {
        guard isRunning, isPaused != paused else { return }
        isPaused = paused
        if paused {
            stopHardware()
        } else {
            startHardware()
        }
    }

    private func startHardware() {
        let motionBox = WeakMainActorBox(self)
        if motion.isDeviceMotionAvailable {
            // 10 Hz: suficiente para saltos; bem mais leve que 20 Hz na main.
            motion.deviceMotionUpdateInterval = 0.1
            motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: processingQueue) { data, _ in
                guard let data else { return }
                motionBox.run { this in
                    guard this.isRunning, !this.isPaused else { return }
                    this.handleDeviceMotion(data)
                }
            }
        }

        let altimeterBox = WeakMainActorBox(self)
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: processingQueue) { data, _ in
                guard let data else { return }
                let alt = data.relativeAltitude.doubleValue
                altimeterBox.run { this in
                    guard this.isRunning, !this.isPaused else { return }
                    if this.baselineAltitude == nil {
                        this.baselineAltitude = alt
                    }
                    let relative = alt - (this.baselineAltitude ?? 0)
                    this.publishAltitudeIfNeeded(relative)
                    this.evaluateAltitudeJump()
                }
            }
        }
    }

    private func stopHardware() {
        motion.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }

    func stop() {
        isRunning = false
        isPaused = false
        stopHardware()
    }

    /// Marcação manual (iPhone) ou botão do Watch.
    func markJump(
        heightMeters: Double? = nil,
        peakG: Double? = nil,
        source: JumpEventSource = .manual,
        at location: CLLocation? = nil
    ) {
        let h = max(heightMeters ?? estimatedLiveHeight(), 0.3)
        let g = max(peakG ?? liveAccelerationG, 1)
        let loc = location ?? locationProvider?()
        let event = SurfJumpEvent(
            heightMeters: h,
            peakAccelerationG: g,
            airtimeSeconds: nil,
            latitude: loc?.coordinate.latitude,
            longitude: loc?.coordinate.longitude,
            source: source
        )
        jumps.append(event)
        lastStatusMessage = String(format: "Salto #%d · %.1f m", jumps.count, h)
    }

    /// Evento vindo do Apple Watch (giroscópio/acelerômetro ou botão “Marcar salto”).
    func ingestWatchJump(heightMeters: Double, peakG: Double, airtime: Double?) {
        let loc = locationProvider?()
        let event = SurfJumpEvent(
            heightMeters: max(0.2, heightMeters),
            peakAccelerationG: max(1, peakG),
            airtimeSeconds: airtime,
            latitude: loc?.coordinate.latitude,
            longitude: loc?.coordinate.longitude,
            source: .appleWatch
        )
        jumps.append(event)
        accelerationSamples.append(
            SurfAccelSample(accelerationG: max(1, peakG), source: .appleWatch)
        )
        lastStatusMessage = String(format: "Salto Watch · %.1f m", heightMeters)
    }

    func ingestWatchAcceleration(_ g: Double) {
        latestAccelerationG = max(0.1, g)
        publishLiveAccelerationIfNeeded(latestAccelerationG)
        sampleCounter += 1
        if sampleCounter % sampleEvery == 0 {
            accelerationSamples.append(SurfAccelSample(accelerationG: latestAccelerationG, source: .appleWatch))
            trimSamples()
        }
    }

    var maxJumpHeightMeters: Double { jumps.map(\.heightMeters).max() ?? 0 }
    var jumpCount: Int { jumps.count }

    func exportSnapshot() -> (jumps: [SurfJumpEvent], samples: [SurfAccelSample]) {
        (jumps, accelerationSamples)
    }

    // MARK: - Internals

    private func handleDeviceMotion(_ data: CMDeviceMotion) {
        let u = data.userAcceleration
        let mag = sqrt(u.x * u.x + u.y * u.y + u.z * u.z)
        // userAcceleration is in g; total ~ magnitude of user
        latestAccelerationG = max(0.1, mag)
        publishLiveAccelerationIfNeeded(latestAccelerationG)
        sampleCounter += 1
        if sampleCounter % sampleEvery == 0 {
            accelerationSamples.append(
                SurfAccelSample(accelerationG: latestAccelerationG, source: .iphone)
            )
            trimSamples()
        }

        // Detecção simples: pico de aceleração + altitude relativa
        if mag > 2.8, !isInAir {
            isInAir = true
            possibleTakeoffAltitude = latestRelativeAltitude
            possibleTakeoffTime = .now
        } else if isInAir, mag < 0.6 {
            if let takeoff = possibleTakeoffAltitude, let t0 = possibleTakeoffTime {
                let height = max(0, latestRelativeAltitude - takeoff)
                let air = Date().timeIntervalSince(t0)
                if height >= 0.4 || air >= 0.35 {
                    let loc = locationProvider?()
                    jumps.append(
                        SurfJumpEvent(
                            heightMeters: max(height, estimatedHeightFromAirtime(air)),
                            peakAccelerationG: latestAccelerationG,
                            airtimeSeconds: air,
                            latitude: loc?.coordinate.latitude,
                            longitude: loc?.coordinate.longitude,
                            source: .iphone
                        )
                    )
                }
            }
            isInAir = false
            possibleTakeoffAltitude = nil
            possibleTakeoffTime = nil
        }
    }

    /// UI at ~5 Hz (or on meaningful change) so ActiveCardioView does not redraw at 20 Hz.
    private func publishLiveAccelerationIfNeeded(_ g: Double) {
        let now = Date()
        let delta = abs(g - lastPublishedLiveG)
        guard delta >= 0.08 || now.timeIntervalSince(lastLiveGPublishAt) >= 0.2 else { return }
        liveAccelerationG = g
        lastPublishedLiveG = g
        lastLiveGPublishAt = now
    }

    private func publishAltitudeIfNeeded(_ relative: Double) {
        latestRelativeAltitude = relative
        let now = Date()
        let delta = abs(relative - lastPublishedAltitude)
        guard delta >= 0.05 || now.timeIntervalSince(lastAltitudePublishAt) >= 0.25 else { return }
        relativeAltitudeMeters = relative
        lastPublishedAltitude = relative
        lastAltitudePublishAt = now
    }

    private func evaluateAltitudeJump() {
        // Altitude-only refinement handled with motion path above.
    }

    private func estimatedLiveHeight() -> Double {
        // Ordem de grandeza: altitude relativa positiva ou proxy airtime
        max(0.5, latestRelativeAltitude * 0.85)
    }

    private func estimatedHeightFromAirtime(_ air: TimeInterval) -> Double {
        // h ≈ 1/2 * g * (t/2)^2 com t tempo no ar
        let half = max(0.1, air / 2)
        return 0.5 * 9.81 * half * half
    }

    private func trimSamples() {
        if accelerationSamples.count > 600 {
            accelerationSamples = Array(accelerationSamples.suffix(600))
        }
        if jumps.count > 200 {
            jumps = Array(jumps.suffix(200))
        }
    }
}
