import SwiftUI
import CoreLocation
import Combine
import MapKit

struct PulsePersonProfileCard: View {
    let person: PulsePerson
    let followStatus: PulseFollowStatus
    var notifyPosts: Bool = true
    var onFollow: () -> Void
    var onAccept: (() -> Void)? = nil
    var onDecline: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(0.55),
                        AppTheme.accentSecondary.opacity(0.35),
                        AppTheme.cardBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 88)
                .overlay {
                    Image(systemName: person.communityFocus.systemImage)
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.35))
                }

                HStack {
                    Spacer()
                    Text(person.communityFocus.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                        .padding(8)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.25))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Text(String(person.displayName.prefix(1)).uppercased())
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.accent)
                        }
                    Text(person.flagEmoji)
                        .font(.caption)
                        .padding(2)
                        .background(Circle().fill(AppTheme.cardBackground))
                        .offset(x: 4, y: 4)
                }
                .offset(y: -18)
                .padding(.bottom, -18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(person.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(person.flagEmoji) \(person.countryName) · \(person.regionLabel)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(person.bio.isEmpty ? L10n.Pulse.noBio : person.bio)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                followButton
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    @ViewBuilder
    private var followButton: some View {
        switch followStatus {
        case .none:
            Button(L10n.Pulse.follow, action: onFollow)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.accent)
                .clipShape(Capsule())
        case .requested:
            Button(L10n.Pulse.requested) { onCancel?() }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
        case .following:
            Text(L10n.Pulse.following)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(Capsule())
        case .incoming:
            HStack(spacing: 6) {
                Button(L10n.Pulse.accept) { onAccept?() }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
                Button(L10n.Pulse.decline) { onDecline?() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

struct PulsePeopleSearchView: View {
    @ObservedObject var store: PulseLocalStore
    let currentUserId: String
    let currentUserName: String
    let currentUserEmail: String
    let currentCountryCode: String

    @StateObject private var locationHelper = PulsePeopleLocationHelper()
    @State private var query = ""
    @State private var preferCountry = ""
    @State private var preferState = ""
    @State private var preferCity = ""
    @State private var notifyOnFollow = true
    @State private var locationStatus = ""
    @State private var bioDraft = ""
    @State private var isSearchingRemote = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var bioFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            myBioEditor

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.accent)
                TextField("Buscar todos os usuários…", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if isSearchingRemote {
                    ProgressView()
                        .controlSize(.small)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            Text("Resultados da sua região primeiro; depois outros países.")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Menu {
                        Button("Usar país do perfil") {
                            preferCountry = resolvedProfileCountry
                        }
                        Button(L10n.Pulse.allCountries) { preferCountry = "" }
                        ForEach(CountryOption.catalog) { country in
                            Button("\(country.flagEmoji) \(country.name)") {
                                preferCountry = country.code
                            }
                        }
                    } label: {
                        Label(
                            preferCountry.isEmpty
                                ? L10n.Pulse.country
                                : "\(CountryOption.flagEmoji(for: preferCountry)) \(CountryOption.option(for: preferCountry)?.name ?? preferCountry)",
                            systemImage: "globe"
                        )
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppTheme.cardBackground)
                        .clipShape(Capsule())
                    }

                    Button {
                        locationHelper.requestLocation()
                    } label: {
                        Label(
                            locationHelper.isResolving ? "Localizando…" : L10n.Pulse.useLocation,
                            systemImage: "location.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent.opacity(0.18))
                        .foregroundStyle(AppTheme.accent)
                        .clipShape(Capsule())
                    }
                    .disabled(locationHelper.isResolving)
                }

                HStack(spacing: 8) {
                    TextField(L10n.Pulse.state, text: $preferState)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppTheme.cardBackground)
                        .clipShape(Capsule())

                    TextField(L10n.Pulse.city, text: $preferCity)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppTheme.cardBackground)
                        .clipShape(Capsule())
                }

                if !locationStatus.isEmpty {
                    Text(locationStatus)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .onChange(of: locationHelper.resolvedPlace) { _, place in
                guard let place else { return }
                if let code = place.countryCode, !code.isEmpty {
                    preferCountry = code
                }
                preferState = place.state
                preferCity = place.city
                locationStatus = place.summary
                store.upsertMyProfile(
                    userId: currentUserId,
                    displayName: currentUserName,
                    emailHint: currentUserEmail,
                    countryCode: preferCountry.isEmpty ? currentCountryCode : preferCountry,
                    state: preferState,
                    city: preferCity
                )
            }
            .onChange(of: locationHelper.statusMessage) { _, message in
                if locationHelper.resolvedPlace == nil {
                    locationStatus = message
                }
            }

            Toggle(isOn: $notifyOnFollow) {
                Text("Receber notificações de postagens ao seguir")
                    .font(.caption)
            }
            .tint(AppTheme.accent)
            .padding(.horizontal, 16)

            if !store.incomingFollowRequests(for: currentUserId).isEmpty {
                incomingSection
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if nearbyPeople.isEmpty && worldwidePeople.isEmpty {
                        emptySearchState
                    } else {
                        if !nearbyPeople.isEmpty {
                            peopleSection(
                                title: "Na sua região",
                                subtitle: regionSectionSubtitle,
                                people: nearbyPeople
                            )
                        }
                        if !worldwidePeople.isEmpty {
                            peopleSection(
                                title: "Outros países",
                                subtitle: "Usuários do app fora da sua região",
                                people: worldwidePeople
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .padding(.top, 8)
        .onAppear {
            store.upsertMyProfile(
                userId: currentUserId,
                displayName: currentUserName,
                emailHint: currentUserEmail,
                countryCode: currentCountryCode
            )
            bioDraft = store.person(id: currentUserId)?.bio ?? ""
            if preferCountry.isEmpty {
                preferCountry = resolvedProfileCountry
            }
            if preferState.isEmpty {
                preferState = store.person(id: currentUserId)?.state ?? ""
            }
            if preferCity.isEmpty {
                preferCity = store.person(id: currentUserId)?.city ?? ""
            }
            Task { await store.refreshFromCloud(currentUserId: currentUserId) }
        }
        .onChange(of: query) { _, _ in
            scheduleRemoteSearch()
        }
        .onChange(of: preferCountry) { _, _ in
            scheduleRemoteSearch()
        }
        .onChange(of: preferState) { _, _ in
            scheduleRemoteSearch()
        }
        .onChange(of: preferCity) { _, _ in
            scheduleRemoteSearch()
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private var resolvedProfileCountry: String {
        let fromProfile = store.person(id: currentUserId)?.countryCode ?? ""
        if !fromProfile.isEmpty { return fromProfile }
        return currentCountryCode
    }

    private var activePreferCountry: String {
        preferCountry.isEmpty ? resolvedProfileCountry : preferCountry
    }

    private var activePreferState: String? {
        preferState.isEmpty ? nil : preferState
    }

    private var activePreferCity: String? {
        preferCity.isEmpty ? nil : preferCity
    }

    private var regionSectionSubtitle: String {
        var parts: [String] = []
        if let city = activePreferCity { parts.append(city) }
        if let state = activePreferState { parts.append(state) }
        if !activePreferCountry.isEmpty {
            parts.append(CountryOption.option(for: activePreferCountry)?.name ?? activePreferCountry)
        }
        return parts.isEmpty
            ? "Prioridade por proximidade"
            : "Prioridade: \(parts.joined(separator: ", "))"
    }

    private var rankedPeople: [PulsePerson] {
        // Sem filtro duro de país — lista todos e ordena por região.
        store.searchPeople(
            query: query,
            countryCode: nil,
            state: nil,
            city: nil,
            preferCountryCode: activePreferCountry,
            preferState: activePreferState,
            preferCity: activePreferCity
        )
        .filter { $0.id != currentUserId }
    }

    private var nearbyPeople: [PulsePerson] {
        store.partitionPeopleByLocality(
            rankedPeople,
            preferCountryCode: activePreferCountry,
            preferState: activePreferState,
            preferCity: activePreferCity
        ).nearby
    }

    private var worldwidePeople: [PulsePerson] {
        store.partitionPeopleByLocality(
            rankedPeople,
            preferCountryCode: activePreferCountry,
            preferState: activePreferState,
            preferCity: activePreferCity
        ).worldwide
    }

    private var emptySearchState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2.crop.square.stack")
                .font(.title2)
                .foregroundStyle(AppTheme.textSecondary)
            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2
                 ? "Digite pelo menos 2 letras para buscar no app inteiro."
                 : "Nenhum usuário encontrado.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        }
    }

    private func peopleSection(title: String, subtitle: String, people: [PulsePerson]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ForEach(people) { person in
                personCard(person)
            }
        }
    }

    private func personCard(_ person: PulsePerson) -> some View {
        PulsePersonProfileCard(
            person: person,
            followStatus: store.followStatus(from: currentUserId, to: person.id),
            notifyPosts: notifyOnFollow,
            onFollow: {
                store.requestFollow(from: currentUserId, to: person.id, notifyPosts: notifyOnFollow)
            },
            onAccept: {
                store.acceptFollow(from: person.id, to: currentUserId)
            },
            onDecline: {
                store.declineFollow(from: person.id, to: currentUserId)
            },
            onCancel: {
                store.cancelFollowRequest(from: currentUserId, to: person.id)
            }
        )
    }

    private func scheduleRemoteSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            isSearchingRemote = false
            return
        }
        let country = activePreferCountry
        let state = activePreferState
        let city = activePreferCity
        let userId = currentUserId
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearchingRemote = true }
            _ = await store.searchPeopleRemotely(
                query: trimmed,
                currentUserId: userId,
                countryCode: nil,
                state: nil,
                city: nil,
                preferCountryCode: country,
                preferState: state,
                preferCity: city
            )
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearchingRemote = false }
        }
    }

    private var myBioEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Pulse.yourBio)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            TextField("Até \(PulseExperimental.maxBioCharacters) caracteres…", text: $bioDraft, axis: .vertical)
                .lineLimit(2...3)
                .font(.subheadline)
                .focused($bioFocused)
                .onChange(of: bioDraft) { _, newValue in
                    if newValue.count > PulseExperimental.maxBioCharacters {
                        bioDraft = String(newValue.prefix(PulseExperimental.maxBioCharacters))
                    }
                }

            HStack {
                Text("\(bioDraft.count)/\(PulseExperimental.maxBioCharacters)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button(L10n.Pulse.saveBio) {
                    store.upsertMyProfile(
                        userId: currentUserId,
                        displayName: currentUserName,
                        emailHint: currentUserEmail,
                        countryCode: preferCountry.isEmpty ? currentCountryCode : preferCountry,
                        state: preferState,
                        city: preferCity,
                        bio: bioDraft
                    )
                    bioFocused = false
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .disabled(bioDraft == (store.person(id: currentUserId)?.bio ?? ""))
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var incomingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pedidos para seguir você")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)

            ForEach(store.incomingFollowRequests(for: currentUserId)) { rel in
                if let person = store.people.first(where: { $0.id == rel.fromUserId }) {
                    PulsePersonProfileCard(
                        person: person,
                        followStatus: .incoming,
                        onFollow: {},
                        onAccept: { store.acceptFollow(from: person.id, to: currentUserId) },
                        onDecline: { store.declineFollow(from: person.id, to: currentUserId) }
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

struct PulseResolvedPlace: Equatable {
    var countryCode: String?
    var state: String
    var city: String

    var summary: String {
        var labels: [String] = []
        if !city.isEmpty { labels.append(city) }
        if !state.isEmpty { labels.append(state) }
        if let countryCode, !countryCode.isEmpty {
            labels.append(CountryOption.option(for: countryCode)?.name ?? countryCode)
        }
        return labels.isEmpty ? "Localização aplicada" : "Perto de \(labels.joined(separator: ", "))"
    }
}

@MainActor
final class PulsePeopleLocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var resolvedPlace: PulseResolvedPlace?
    @Published var statusMessage = ""
    @Published var isResolving = false

    private let manager = CLLocationManager()
    private nonisolated(unsafe) weak var nonisolatedWeakSelf: PulsePeopleLocationHelper?

    override init() {
        super.init()
        nonisolatedWeakSelf = self
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        resolvedPlace = nil
        isResolving = true
        statusMessage = "Solicitando localização…"
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isResolving = false
            statusMessage = "Permissão de localização negada. Ative em Ajustes."
        default:
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard let this = nonisolatedWeakSelf else { return }
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                this.manager.requestLocation()
            } else if status == .denied || status == .restricted {
                this.isResolving = false
                this.statusMessage = "Permissão de localização negada. Ative em Ajustes."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            guard let this = nonisolatedWeakSelf else { return }
            this.statusMessage = "Resolvendo cidade…"
            this.reverseGeocode(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            guard let this = nonisolatedWeakSelf else { return }
            this.isResolving = false
            this.statusMessage = message
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                isResolving = false
                statusMessage = "Não foi possível obter cidade/estado."
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let mapItems = try await request.mapItems
                    self.isResolving = false
                    guard let item = mapItems.first else {
                        self.statusMessage = "Não foi possível obter cidade/estado."
                        return
                    }
                    let reps = item.addressRepresentations
                    let city = reps?.cityName ?? ""
                    let state: String = {
                        guard let context = reps?.cityWithContext, !context.isEmpty else { return "" }
                        guard let cityName = reps?.cityName, !cityName.isEmpty else { return context }
                        var rest = context
                        if rest.hasPrefix(cityName) {
                            rest = String(rest.dropFirst(cityName.count))
                        }
                        return rest.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
                    }()
                    let code = reps?.region?.identifier.uppercased()
                    self.resolvedPlace = PulseResolvedPlace(
                        countryCode: code,
                        state: state,
                        city: city
                    )
                } catch {
                    self.isResolving = false
                    self.statusMessage = error.localizedDescription
                }
            }
            return
        }

        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            let errorDescription = error?.localizedDescription
            let hasPlace = placemarks?.first != nil
            let code = placemarks?.first?.isoCountryCode?.uppercased()
            let state = placemarks?.first?.administrativeArea ?? placemarks?.first?.subAdministrativeArea ?? ""
            let city = placemarks?.first?.locality ?? placemarks?.first?.subLocality ?? placemarks?.first?.name ?? ""
            WeakMainActorBox.schedule(self) { this in
                this.isResolving = false
                if let errorDescription {
                    this.statusMessage = errorDescription
                    return
                }
                guard hasPlace else {
                    this.statusMessage = "Não foi possível obter cidade/estado."
                    return
                }
                this.resolvedPlace = PulseResolvedPlace(
                    countryCode: code,
                    state: state,
                    city: city
                )
            }
        }
    }
}

struct PulseCommunitiesView: View {
    @ObservedObject var store: PulseLocalStore
    let currentUserId: String
    let currentUserName: String

    @State private var chatPartner: PulsePerson?

    private var activeCommunities: [PulseCommunity] {
        let thematic = PulseCommunity.thematicCases.filter { store.joinedCommunities.contains($0) }
        let modalities = PulseCommunity.cardioModalityCases.filter { store.joinedCommunities.contains($0) }
        return thematic + modalities
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.Pulse.dashboardCommunities)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 16)

                Text("Ative um tema para ele aparecer no Feed (ao lado de Todos) e nos posts como ATIVO.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)

                if !activeCommunities.isEmpty {
                    activeCommunitiesStrip
                    activeCommunityPostsSection
                }

                ForEach(PulseCommunity.thematicCases) { community in
                    let isActive = store.joinedCommunities.contains(community)
                    Button {
                        store.toggleCommunity(community)
                        if store.joinedCommunities.contains(community) {
                            store.selectedCommunity = community
                        } else if store.selectedCommunity == community {
                            store.selectedCommunity = nil
                        }
                    } label: {
                        WorkoutProgramHeroCard(
                            title: community.title,
                            subtitle: isActive
                                ? "ATIVO no Feed e nos posts · toque para sair"
                                : "Toque para ativar no Feed e nos posts",
                            accent: AppTheme.accent,
                            imageName: community.coverAsset,
                            systemImage: community.systemImage,
                            eyebrow: isActive ? L10n.Pulse.active.uppercased() : "ENTRAR",
                            footerLabels: [
                                (icon: community.systemImage, text: community.title),
                                (icon: "person.3.fill", text: "Pulse")
                            ]
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .opacity(isActive ? 1 : 0.75)

                    if community == .cardio {
                        cardioModalitiesSection
                    }
                }

                if PulseExperimental.isChatEnabledInBuild {
                    communityChatSection
                }
            }
            .padding(.vertical, 12)
        }
        .onAppear {
            if PulseExperimental.isChatEnabledInBuild {
                store.ensureCommunityChatDemoFollowers(for: currentUserId)
            }
        }
        .sheet(item: $chatPartner) { person in
            if PulseExperimental.isChatEnabledInBuild {
                PulseCommunityChatView(
                    store: store,
                    currentUserId: currentUserId,
                    currentUserName: currentUserName,
                    partner: person
                )
            }
        }
    }

    private var activeCommunitiesStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ativas agora")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(activeCommunities) { community in
                        HStack(spacing: 6) {
                            Label(community.title, systemImage: community.systemImage)
                            Text(L10n.Pulse.active.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.gradientPrimary)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var activeCommunityPostsSection: some View {
        let posts = store.posts
            .filter(\.isActive)
            .filter { !$0.isHidden }
            .filter { store.joinedCommunities.contains($0.community) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(6)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Posts nas comunidades ATIVO")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)

            if posts.isEmpty {
                Text("Ainda não há posts nas suas comunidades ativas.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(Array(posts)) { post in
                    HStack(spacing: 10) {
                        Image(systemName: post.community.systemImage)
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(post.authorName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(post.community.title)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppTheme.accent)
                                Text(L10n.Pulse.active.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accent.opacity(0.2))
                                    .foregroundStyle(AppTheme.accent)
                                    .clipShape(Capsule())
                            }
                            Text(post.caption.isEmpty ? "Publicação no Pulse" : post.caption)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var cardioModalitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Modalidades de Cardio (= comunidades)")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)

            Text("Cada modalidade é uma comunidade. Ative para aparecer no Feed ao lado de Todos e nos posts como ATIVO.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 16)

            ForEach(CardioExercise.catalog) { exercise in
                let community = PulseCommunity.cardioModality(exercise.name)
                let isActive = store.joinedCommunities.contains(community)
                Button {
                    store.toggleCardioModality(exercise.name)
                    if store.joinedCommunities.contains(community) {
                        store.selectedCommunity = community
                    } else if store.selectedCommunity == community {
                        store.selectedCommunity = nil
                    }
                } label: {
                    WorkoutProgramHeroCard(
                        title: exercise.name,
                        subtitle: isActive
                            ? "Comunidade ATIVO · toque para sair"
                            : "\(exercise.description) · toque para ativar",
                        accent: AppTheme.accent,
                        imageName: exercise.coverImageName,
                        systemImage: exercise.icon,
                        coverColors: exercise.coverColors,
                        eyebrow: isActive ? "COMUNIDADE · \(L10n.Pulse.active.uppercased())" : "COMUNIDADE",
                        footerLabels: [
                            (icon: exercise.icon, text: L10n.Pulse.communityCardio),
                            (icon: "person.3.fill", text: "Pulse"),
                            (icon: "flame.fill", text: "\(Int(exercise.caloriesPerMinute))/min")
                        ]
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .opacity(isActive ? 1 : 0.72)
            }
        }
        .padding(.top, 4)
    }

    private var communityChatSection: some View {
        let followers = store.followers(of: currentUserId)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Chat da comunidade")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)

            Text("Converse só com quem te segue (pedido aprovado).")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 16)

            if followers.isEmpty {
                Text("Ninguém te segue ainda. Quando aprovarem o pedido, o chat aparece aqui.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                ForEach(followers) { person in
                    Button {
                        chatPartner = person
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accent.opacity(0.22))
                                    .frame(width: 44, height: 44)
                                Text(String(person.displayName.prefix(1)).uppercased())
                                    .font(.headline.bold())
                                    .foregroundStyle(AppTheme.accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("\(person.flagEmoji) \(person.countryName) · \(person.communityFocus.title)")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                        .padding(12)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

struct PulseCommunityChatView: View {
    @ObservedObject var store: PulseLocalStore
    let currentUserId: String
    let currentUserName: String
    let partner: PulsePerson

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    private var messages: [PulseChatMessage] {
        store.messages(with: partner.id, currentUserId: currentUserId)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { message in
                                chatBubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                HStack(spacing: 10) {
                    TextField("Mensagem na comunidade…", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        store.sendChatMessage(
                            from: currentUserId,
                            senderName: currentUserName,
                            to: partner.id,
                            text: draft,
                            community: partner.communityFocus
                        )
                        draft = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
                .background(AppTheme.background)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(partner.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Pulse.close) { dismiss() }
                }
            }
        }
    }

    private func chatBubble(_ message: PulseChatMessage) -> some View {
        let isMine = message.senderId == currentUserId
        return HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(isMine ? Color.white : AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMine ? AppTheme.accent : AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }
}
