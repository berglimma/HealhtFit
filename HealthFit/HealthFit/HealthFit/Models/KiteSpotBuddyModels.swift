import CoreLocation
import Foundation

// MARK: - Preferências e privacidade (separado do Duo)

enum KiteSpotBuddyPreferences {
    static let consentKey = "kiteSpotBuddy.consent.v1"
    static let enabledKey = "kiteSpotBuddy.enabled.nextSession"

    static var hasConsent: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    static func grantConsent() {
        UserDefaults.standard.set(true, forKey: consentKey)
    }

    static var isEnabledForNextSession: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}

enum KiteSpotBuddyPrivacy {
    static let clearNotice = """
    O Kite Spot Buddy compartilha sua posição aproximada apenas durante uma sessão ativa de kitesurf, e somente com amigos da sua equipe que também estiverem com o recurso ativo na mesma sessão.

    • Não substitui o Duo: o chat e ranking de equipe continuam sem mapa em tempo real.
    • Você pode desativar a qualquer momento ou encerrar a sessão para apagar sua posição.
    • Dados compartilhados: nome, foto (se houver), distância e direção aproximadas.
    • Alarme de ajuda: avisa colegas próximos; confirme antes de enviar e use “Estou bem” para cancelar.
    """

    static let shortLabel = "Compartilhar posição na sessão com amigos da equipe (somente kitesurf)."
}

// MARK: - Modelos

struct KiteSpotBuddyPresence: Codable, Equatable, Identifiable {
    var id: String { uid }
    let uid: String
    var displayName: String
    var photoURL: String?
    var latitude: Double
    var longitude: Double
    var needsHelp: Bool
    var helpRequestedAt: Date?
    var sessionId: String
    var updatedAt: Date
}

struct KiteSpotBuddyPeer: Codable, Equatable, Identifiable, Hashable {
    var id: String { uid }
    let uid: String
    var displayName: String
    var photoURL: String?
    var latitude: Double
    var longitude: Double
    var distanceMeters: Double
    var bearingDegrees: Double?
    var needsHelp: Bool
}

struct KiteSpotBuddyWatchPayload: Codable, Equatable {
    var peers: [KiteSpotBuddyPeer]
    var myLatitude: Double?
    var myLongitude: Double?
    var needsHelp: Bool
    var incomingHelp: KiteSpotBuddyPeer?
    var spotBuddyEnabled: Bool
}

enum KiteSpotBuddyGeo {
    static let maxRadarMeters: Double = 2_000

    static func distanceMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let a = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let b = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return a.distance(from: b)
    }

    static func bearingDegrees(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }
}
