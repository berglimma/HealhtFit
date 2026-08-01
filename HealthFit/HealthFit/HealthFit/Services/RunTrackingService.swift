import Combine
import CoreLocation
import CoreMotion
import Foundation

/// Rastreia GPS, passos e estado de movimento durante uma corrida (estilo Strava).
@MainActor
final class RunTrackingService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var locationDeniedMessage: String?
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var routePoints: [RouteCoordinate] = []
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var currentSpeedMetersPerSecond: Double = 0
    @Published private(set) var activityState: RunningActivityState = .unknown
    @Published private(set) var stepCount: Int = 0
    @Published private(set) var isPedometerAvailable: Bool = false
    @Published private(set) var isTracking = false

    private let locationManager = CLLocationManager()
    private let pedometer = CMPedometer()
    private let motionActivityManager = CMMotionActivityManager()
    private var sessionStartDate: Date?
    private var lastAcceptedLocation: CLLocation?
    private var usesPedometerSteps = false
    private var motionActivityAvailable = false

    var distanceKm: Double { distanceMeters / 1_000.0 }

    var hasUsableRoute: Bool { routePoints.count >= 2 }

    var startCoordinate: CLLocationCoordinate2D? {
        routePoints.first?.coordinate
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
        isPedometerAvailable = CMPedometer.isStepCountingAvailable()
        motionActivityAvailable = CMMotionActivityManager.isActivityAvailable()
    }

    func prepareForRun() {
        locationDeniedMessage = nil
        requestLocationPermissionIfNeeded()
    }

    func start() {
        guard !isTracking else { return }
        locationDeniedMessage = nil
        sessionStartDate = .now
        routePoints = []
        distanceMeters = 0
        stepCount = 0
        currentSpeedMetersPerSecond = 0
        activityState = .unknown
        lastAcceptedLocation = nil
        usesPedometerSteps = false
        isTracking = true

        requestLocationPermissionIfNeeded()
        startLocationUpdatesIfAuthorized()
        startPedometer()
        startMotionActivityUpdates()
    }

    func stop() {
        guard isTracking else { return }
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        pedometer.stopUpdates()
        if motionActivityAvailable {
            motionActivityManager.stopActivityUpdates()
        }
        if !usesPedometerSteps {
            stepCount = max(stepCount, RunTrackingMath.estimatedSteps(distanceKm: distanceKm))
        }
    }

    /// Distância GPS quando há rota; caso contrário `nil` (usar estimativa por ritmo).
    var gpsDistanceKmIfAvailable: Double? {
        guard distanceMeters > 5 else { return nil }
        return distanceKm
    }

    private func requestLocationPermissionIfNeeded() {
        let status = locationManager.authorizationStatus
        authorizationStatus = status
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Escalona para Always para continuar a rota com a tela bloqueada.
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            locationDeniedMessage = "Localização negada. Ative em Ajustes → HealthFit → Localização para ver o mapa da corrida."
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }

    private func startLocationUpdatesIfAuthorized() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return }
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.startUpdatingLocation()
        locationManager.requestLocation()
    }

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable(), let start = sessionStartDate else {
            isPedometerAvailable = false
            return
        }
        isPedometerAvailable = true
        pedometer.startUpdates(from: start) { [weak self] data, error in
            guard let self, error == nil, let data else { return }
            let steps = data.numberOfSteps.intValue
            Task { @MainActor in
                self.usesPedometerSteps = true
                self.stepCount = max(0, steps)
            }
        }
    }

    private func startMotionActivityUpdates() {
        guard motionActivityAvailable else { return }
        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            Task { @MainActor in
                self.applyMotionActivity(activity)
            }
        }
    }

    private func applyMotionActivity(_ activity: CMMotionActivity) {
        let next: RunningActivityState
        if activity.running {
            next = .running
        } else if activity.walking {
            next = .walking
        } else if activity.stationary {
            next = .stationary
        } else if activity.automotive || activity.cycling {
            next = .stationary
        } else {
            return
        }
        // Confiança baixa: não sobrescreve classificação por GPS recente.
        if activity.confidence == .low, currentSpeedMetersPerSecond > 0.3 {
            return
        }
        activityState = next
    }

    private func accept(_ location: CLLocation) {
        // Filtra leituras ruins / saltos GPS.
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 40 else { return }
        if let last = lastAcceptedLocation {
            let delta = location.distance(from: last)
            let dt = location.timestamp.timeIntervalSince(last.timestamp)
            if dt <= 0 { return }
            // Rejeita saltos absurdos (> ~8 m/s médios com gap curto, típico de glitch).
            if delta > 80, dt < 5 { return }
            if delta >= 1 {
                distanceMeters += delta
            }
        }

        lastAcceptedLocation = location
        currentLocation = location
        if location.speed >= 0 {
            currentSpeedMetersPerSecond = location.speed
            // GPS como fallback / reforço quando CoreMotion não classifica.
            if !motionActivityAvailable || activityState == .unknown {
                activityState = RunTrackingMath.activityState(fromSpeedMetersPerSecond: location.speed)
            } else if activityState == .stationary || activityState == .walking || activityState == .running {
                // Suaviza: se GPS discorda fortemente, atualiza.
                let gpsState = RunTrackingMath.activityState(fromSpeedMetersPerSecond: location.speed)
                if gpsState != activityState, abs(location.speed - impliedSpeed(for: activityState)) > 1.2 {
                    activityState = gpsState
                }
            }
        } else if activityState == .unknown {
            activityState = .stationary
        }

        let point = RouteCoordinate(location: location)
        if let last = routePoints.last {
            let moved = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: location)
            if moved < 2 { return }
        }
        routePoints.append(point)

        if !usesPedometerSteps {
            stepCount = RunTrackingMath.estimatedSteps(distanceKm: distanceKm)
        }
    }

    private func impliedSpeed(for state: RunningActivityState) -> Double {
        switch state {
        case .stationary, .unknown: return 0
        case .walking: return 1.4
        case .running: return 3.0
        }
    }
}

extension RunTrackingService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                locationDeniedMessage = nil
                if isTracking {
                    if status == .authorizedWhenInUse {
                        locationManager.requestAlwaysAuthorization()
                    }
                    startLocationUpdatesIfAuthorized()
                }
            case .denied, .restricted:
                locationDeniedMessage = "Localização negada. Ative em Ajustes → HealthFit → Localização para ver o mapa da corrida."
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            guard isTracking else { return }
            accept(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                locationDeniedMessage = "Localização negada. Ative em Ajustes → HealthFit → Localização para ver o mapa da corrida."
            }
            #if DEBUG
            print("RunTrackingService location error: \(error.localizedDescription)")
            #endif
        }
    }
}
