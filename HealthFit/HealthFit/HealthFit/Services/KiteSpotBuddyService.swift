import Combine
import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class KiteSpotBuddyService: ObservableObject {
    static let shared = KiteSpotBuddyService()

    @Published private(set) var peers: [KiteSpotBuddyPeer] = []
    @Published private(set) var incomingHelpAlert: KiteSpotBuddyPeer?
    @Published private(set) var needsHelp = false
    @Published private(set) var isActive = false

    private var listener: ListenerRegistration?
    private var heartbeatTask: Task<Void, Never>?
    private var sessionId: String?
    private var latestLocation: CLLocation?
    private var displayName = ""
    private var photoURL: String?
    private var teammateUIDs: Set<String> = []
    private var dismissedHelpUIDs: Set<String> = []

    private init() {}

    var canStart: Bool {
        KiteSpotBuddyPreferences.hasConsent && KiteSpotBuddyPreferences.isEnabledForNextSession
    }

    static func resolvedPhotoURL(for uid: String) -> String? {
        for team in DuoTeamService.shared.teams {
            if let member = team.members.first(where: { $0.uid == uid }),
               let url = member.photoURL,
               !url.isEmpty {
                return url
            }
        }
        return nil
    }

    func start(sessionId: String, displayName: String, photoURL: String?) {
        guard canStart else { return }
        guard KiteSpotBuddyFirestoreService.isAvailable,
              let uid = Auth.auth().currentUser?.uid else { return }

        stop()
        self.sessionId = sessionId
        self.displayName = displayName
        self.photoURL = photoURL
        self.teammateUIDs = Self.collectTeammateUIDs(excluding: uid)
        isActive = true
        needsHelp = false
        incomingHelpAlert = nil
        dismissedHelpUIDs.removeAll()

        listener = KiteSpotBuddyFirestoreService.listenVisiblePresence { [weak self] docs in
            Task { @MainActor in
                self?.applySnapshot(docs)
            }
        }

        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.heartbeat()
                try? await Task.sleep(for: .seconds(20))
            }
        }

        Task { await heartbeat() }
    }

    func updateLocation(_ location: CLLocation) {
        latestLocation = location
    }

    func requestHelp() async {
        guard isActive, let uid = Auth.auth().currentUser?.uid else { return }
        needsHelp = true
        try? await KiteSpotBuddyFirestoreService.setNeedsHelp(uid: uid, needsHelp: true)
        syncToWatch()
    }

    func cancelHelp() async {
        guard isActive, let uid = Auth.auth().currentUser?.uid else { return }
        needsHelp = false
        try? await KiteSpotBuddyFirestoreService.setNeedsHelp(uid: uid, needsHelp: false)
        syncToWatch()
    }

    func dismissIncomingHelp() {
        if let uid = incomingHelpAlert?.uid {
            dismissedHelpUIDs.insert(uid)
        }
        incomingHelpAlert = nil
        syncToWatch()
    }

    func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        listener?.remove()
        listener = nil

        if let uid = Auth.auth().currentUser?.uid {
            Task { await KiteSpotBuddyFirestoreService.deletePresence(uid: uid) }
        }

        isActive = false
        needsHelp = false
        peers = []
        incomingHelpAlert = nil
        sessionId = nil
        latestLocation = nil
        syncToWatch()
    }

    private func heartbeat() async {
        guard isActive,
              let uid = Auth.auth().currentUser?.uid,
              let sessionId,
              let location = latestLocation else { return }

        do {
            try await KiteSpotBuddyFirestoreService.upsertPresence(
                uid: uid,
                displayName: displayName,
                photoURL: photoURL,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                sessionId: sessionId,
                needsHelp: needsHelp
            )
        } catch {
            #if DEBUG
            print("[HealthFit] Kite Spot Buddy heartbeat: \(error.localizedDescription)")
            #endif
        }
        syncToWatch()
    }

    private func applySnapshot(_ docs: [QueryDocumentSnapshot]) {
        guard let myUID = Auth.auth().currentUser?.uid else { return }
        let myCoord = latestLocation?.coordinate

        var nextPeers: [KiteSpotBuddyPeer] = []
        var helpCandidate: KiteSpotBuddyPeer?

        for doc in docs {
            guard let presence = KiteSpotBuddyFirestoreService.parsePresence(doc.data(), documentId: doc.documentID),
                  presence.uid != myUID,
                  teammateUIDs.contains(presence.uid) else { continue }

            let peerCoord = CLLocationCoordinate2D(latitude: presence.latitude, longitude: presence.longitude)
            let distance = myCoord.map { KiteSpotBuddyGeo.distanceMeters(from: $0, to: peerCoord) } ?? .greatestFiniteMagnitude
            guard distance <= KiteSpotBuddyGeo.maxRadarMeters else { continue }

            let bearing = myCoord.map { KiteSpotBuddyGeo.bearingDegrees(from: $0, to: peerCoord) }
            let peer = KiteSpotBuddyPeer(
                uid: presence.uid,
                displayName: presence.displayName,
                photoURL: presence.photoURL,
                latitude: presence.latitude,
                longitude: presence.longitude,
                distanceMeters: distance,
                bearingDegrees: bearing,
                needsHelp: presence.needsHelp
            )
            nextPeers.append(peer)

            if presence.needsHelp, !dismissedHelpUIDs.contains(presence.uid) {
                if helpCandidate == nil || distance < (helpCandidate?.distanceMeters ?? .greatestFiniteMagnitude) {
                    helpCandidate = peer
                }
            }
        }

        nextPeers.sort { $0.distanceMeters < $1.distanceMeters }
        peers = nextPeers
        incomingHelpAlert = helpCandidate
        syncToWatch()
    }

    private func syncToWatch() {
        let payload = KiteSpotBuddyWatchPayload(
            peers: peers,
            myLatitude: latestLocation?.coordinate.latitude,
            myLongitude: latestLocation?.coordinate.longitude,
            needsHelp: needsHelp,
            incomingHelp: incomingHelpAlert,
            spotBuddyEnabled: isActive
        )
        WatchConnectivityManager.shared.sendKiteSpotBuddyToWatch(payload)
    }

    private static func collectTeammateUIDs(excluding myUID: String) -> Set<String> {
        var uids = Set<String>()
        for team in DuoTeamService.shared.teams {
            let modalities = team.effectiveModalities
            let supportsKite = modalities.contains(.kitesurf) || modalities.contains(.mixed)
                || modalities.count == DuoTeamModality.selectableCases.count
            guard supportsKite else { continue }
            for member in team.members {
                guard let uid = member.uid, uid != myUID else { continue }
                uids.insert(uid)
            }
        }
        return uids
    }
}
