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

    private var locationProvider: (() -> CLLocation?)?

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
        sessionStart = .now
        isRunning = true
        lastStatusMessage = "Sensores de salto ativos"

        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 0.05
            motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.handleDeviceMotion(data)
            }
        }

        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                let alt = data.relativeAltitude.doubleValue
                if self.baselineAltitude == nil {
                    self.baselineAltitude = alt
                }
                self.relativeAltitudeMeters = alt - (self.baselineAltitude ?? 0)
                self.evaluateAltitudeJump()
            }
        }
    }

    func stop() {
        isRunning = false
        motion.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
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
        liveAccelerationG = g
        sampleCounter += 1
        if sampleCounter % sampleEvery == 0 {
            accelerationSamples.append(SurfAccelSample(accelerationG: g, source: .appleWatch))
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
        liveAccelerationG = max(0.1, mag)
        sampleCounter += 1
        if sampleCounter % sampleEvery == 0 {
            accelerationSamples.append(
                SurfAccelSample(accelerationG: liveAccelerationG, source: .iphone)
            )
            trimSamples()
        }

        // Detecção simples: pico de aceleração + altitude relativa
        if mag > 2.8, !isInAir {
            isInAir = true
            possibleTakeoffAltitude = relativeAltitudeMeters
            possibleTakeoffTime = .now
        } else if isInAir, mag < 0.6 {
            if let takeoff = possibleTakeoffAltitude, let t0 = possibleTakeoffTime {
                let height = max(0, relativeAltitudeMeters - takeoff)
                let air = Date().timeIntervalSince(t0)
                if height >= 0.4 || air >= 0.35 {
                    let loc = locationProvider?()
                    jumps.append(
                        SurfJumpEvent(
                            heightMeters: max(height, estimatedHeightFromAirtime(air)),
                            peakAccelerationG: liveAccelerationG,
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

    private func evaluateAltitudeJump() {
        // Altitude-only refinement handled with motion path above.
    }

    private func estimatedLiveHeight() -> Double {
        // Ordem de grandeza: altitude relativa positiva ou proxy airtime
        max(0.5, relativeAltitudeMeters * 0.85)
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
