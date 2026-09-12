import SwiftUI

private enum PulseBottomTab: Hashable {
    case feed
    case post
    case communities
    case people
}

/// Visibilidade do card no ecrã para autoplay de música no scroll.
private struct PulseMusicVisibility: Equatable {
    var postId: UUID
    var hasPreview: Bool
    /// 0 = centro do card no meio do ecrã; 1 = longe.
    var centerDistance: CGFloat
    /// Quanto do card está no ecrã (0…1).
    var overlap: CGFloat
    /// Posição Y — muda no scroll e força o PreferenceKey a atualizar.
    var midY: CGFloat
}

private struct PulsePostVisibilityKey: PreferenceKey {
    static var defaultValue: [UUID: PulseMusicVisibility] = [:]

    static func reduce(
        value: inout [UUID: PulseMusicVisibility],
        nextValue: () -> [UUID: PulseMusicVisibility]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct PulseFeedView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var shareCardStore: WorkoutShareCardStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = PulseLocalStore.shared

    @State private var selectedTab: PulseBottomTab = .feed
    @State private var showCompose = false
    @State private var editingPost: PulsePost?
    @State private var showStoryCompose = false
    @State private var viewingSession: PulseStoryBrowseSession?
    @State private var reactionsToShow: [PulseReactionEvent]?
    @State private var commentDrafts: [UUID: String] = [:]
    @State private var errorMessage: String?
    @State private var autoPlayMusicPostId: UUID?
    @State private var musicVisibilityTask: Task<Void, Never>?
    @State private var showModerationQueue = false
    @State private var showDeleteAccountSheet = false
    @State private var showShareAfterPost = false
    @State private var pendingShareItems: [Any] = []
    @State private var showPulseShareSheet = false
    @State private var shareHintMessage: String?

    private var authorId: String { authService.currentUser?.id ?? "local" }
    private var authorName: String {
        let name = authService.currentUser?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? L10n.Pulse.athlete : name
    }
    private var authorCountryCode: String {
        authService.currentUser?.countryCode ?? "BR"
    }

    private var canAccessPulseUGC: Bool {
        (authService.currentUser?.age ?? 0) >= PulseExperimental.ugcMinimumAge
    }

    var body: some View {
        NavigationStack {
            Group {
                if canAccessPulseUGC {
                    VStack(spacing: 0) {
                        Group {
                            switch selectedTab {
                            case .feed:
                                feedContent
                            case .post:
                                postComposerHub
                            case .communities:
                                PulseCommunitiesView(
                                    store: store,
                                    currentUserId: authorId,
                                    currentUserName: authorName
                                )
                            case .people:
                                PulsePeopleSearchView(
                                    store: store,
                                    currentUserId: authorId,
                                    currentUserName: authorName,
                                    currentUserEmail: authService.currentUser?.email ?? "",
                                    currentCountryCode: authorCountryCode
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        pulseBottomBar
                    }
                } else {
                    PulseUGCAgeGateView(age: authService.currentUser?.age ?? 0)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Pulse.close) { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                            Text("Pulse")
                                .font(.headline.weight(.bold))
                        }
                        if canAccessPulseUGC {
                            Text(PulseExperimental.tagline)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                if canAccessPulseUGC {
                    ToolbarItemGroup(placement: .primaryAction) {
                        if PulseModerationAccess.canModerate(email: authService.currentUser?.email) {
                            Button {
                                showModerationQueue = true
                            } label: {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundStyle(AppTheme.accentSecondary)
                            }
                            .accessibilityLabel(L10n.Pulse.moderationTitle)
                        }
                        Button {
                            showCompose = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                        .accessibilityLabel(L10n.Pulse.composerNewPost)
                        Menu {
                            Button(role: .destructive) {
                                showDeleteAccountSheet = true
                            } label: {
                                Label("Excluir conta HealthFit…", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .accessibilityLabel("Conta e opções")
                    }
                }
            }
            .sheet(isPresented: $showModerationQueue) {
                PulseModerationQueueView()
            }
            .sheet(isPresented: $showDeleteAccountSheet) {
                DeleteAccountSheet(
                    requiresPassword: authService.usesPasswordProvider,
                    requiresAppleReauthentication: authService.usesAppleProvider
                )
                .environmentObject(authService)
            }
            .onChange(of: authService.currentUser?.id) { _, newId in
                if newId == nil {
                    showDeleteAccountSheet = false
                    dismiss()
                }
            }
            .sheet(item: $editingPost, onDismiss: { editingPost = nil }) { post in
                PulseComposeView(
                    existingPost: post,
                    existingImage: store.loadImage(for: post)
                ) { payload in
                    Task {
                        do {
                            try await store.updatePost(
                                postId: post.id,
                                by: authorId,
                                caption: payload.caption,
                                community: payload.community,
                                workoutMeta: payload.workoutMeta,
                                music: payload.music,
                                newImage: payload.photo,
                                newVideoURL: payload.videoURL
                            )
                            editingPost = nil
                            selectedTab = .feed
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .sheet(isPresented: $showCompose) {
                PulseComposeView { payload in
                    do {
                        if let photo = payload.photo {
                            let created = try store.addPhotoPost(
                                authorId: authorId,
                                authorName: authorName,
                                authorCountryCode: authorCountryCode,
                                caption: payload.caption,
                                image: photo,
                                community: payload.community,
                                workoutMeta: payload.workoutMeta,
                                music: payload.music,
                                authorAvatar: authService.profileImage
                            )
                            if created.music != nil {
                                autoPlayMusicPostId = created.id
                            }
                            prepareExternalShare(post: created, image: photo, videoURL: nil)
                        } else if let videoURL = payload.videoURL {
                            Task {
                                do {
                                    let created = try await store.addVideoPost(
                                        authorId: authorId,
                                        authorName: authorName,
                                        authorCountryCode: authorCountryCode,
                                        caption: payload.caption,
                                        sourceURL: videoURL,
                                        community: payload.community,
                                        workoutMeta: payload.workoutMeta,
                                        music: payload.music,
                                        authorAvatar: authService.profileImage
                                    )
                                    if created.music != nil {
                                        autoPlayMusicPostId = created.id
                                    }
                                    prepareExternalShare(post: created, image: nil, videoURL: videoURL)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                        showCompose = false
                        selectedTab = .feed
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .sheet(isPresented: $showStoryCompose) {
                PulseStoryComposeView { image, music, texts in
                    do {
                        try store.addStory(
                            authorId: authorId,
                            authorName: authorName,
                            image: image,
                            music: music,
                            textOverlays: texts
                        )
                        showStoryCompose = false
                        selectedTab = .feed
                        // Abre o story publicado e toca o trecho automaticamente.
                        if let latest = store.activeStories.first(where: { $0.authorId == authorId }) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                viewingSession = PulseStoryBrowseSession.make(
                                    from: store.activeStories,
                                    focusing: latest
                                )
                            }
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .fullScreenCover(item: $viewingSession) { session in
                PulseStoryViewer(
                    session: session,
                    imageLoader: { store.loadStoryImage($0) },
                    profileImageLoader: { story in
                        story.authorId == authorId
                            ? authService.profileImage
                            : store.loadReactionAvatar(
                                PulseReactionEvent(userId: story.authorId, userName: story.authorName, kind: "heart")
                            )
                    },
                    currentUserId: authorId,
                    avatarLoader: { store.loadReactionAvatar($0) },
                    onHeart: { storyId in
                        store.toggleStoryHeart(
                            storyId: storyId,
                            userId: authorId,
                            userName: authorName,
                            avatar: authService.profileImage
                        )
                    },
                    onShowReactions: { reactionsToShow = $0.filter(\.isHeart) },
                    onDelete: { storyId in
                        store.deleteStory(storyId, by: authorId)
                    },
                    onClose: {
                        viewingSession = nil
                    },
                    onViewed: { store.markStoryViewed($0) }
                )
            }
            .sheet(item: Binding(
                get: {
                    reactionsToShow.map { PulseReactionsSheetItem(reactions: $0) }
                },
                set: { reactionsToShow = $0?.reactions }
            )) { item in
                PulseReactionsListView(
                    reactions: item.reactions,
                    avatarLoader: { store.loadReactionAvatar($0) }
                )
                .presentationDetents([.medium, .large])
            }
            .alert(L10n.Pulse.featureName, isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L10n.Common.ok, role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert(L10n.Pulse.publishedAlertTitle, isPresented: $showShareAfterPost) {
                Button(L10n.Pulse.shareInstagram) {
                    showPulseShareSheet = true
                }
                Button(L10n.Pulse.termsNotNow, role: .cancel) {}
            } message: {
                Text(shareHintMessage ?? L10n.Pulse.shareHintDefault)
            }
            .sheet(isPresented: $showPulseShareSheet) {
                ActivityShareSheet(items: pendingShareItems) {
                    showPulseShareSheet = false
                    pendingShareItems = []
                }
            }
            .onAppear {
                guard canAccessPulseUGC else { return }
                store.pruneExpiredContent()
                store.ensureUserAvatar(userId: authorId, image: authService.profileImage)
                if PulseExperimental.includeDemoContent {
                    store.ensureFollowingDemoPeople(for: authorId)
                    if PulseExperimental.isChatEnabledInBuild {
                        store.ensureCommunityChatDemoFollowers(for: authorId)
                    }
                }
                store.requestPulseNotificationPermission()
                Task { await store.refreshFromCloud(currentUserId: authorId) }
            }
        }
    }

    // MARK: - Feed

    private var feedContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                PulseStoriesRail(
                    stories: store.activeStories,
                    currentUserId: authorId,
                    currentUserImage: authService.profileImage,
                    storyImage: { store.loadStoryImage($0) },
                    onAddStory: { showStoryCompose = true },
                    onOpenStory: { story in
                        viewingSession = PulseStoryBrowseSession.make(
                            from: store.activeStories,
                            focusing: story
                        )
                    }
                )
                .padding(.top, 8)

                PulseDailyChallengeCard(
                    text: PulseExperimental.dailyChallenge(for: authorId)
                )
                    .padding(.horizontal, 16)

                PulseCommunityChips(
                    selectedCommunity: store.selectedCommunity,
                    joinedCommunities: store.joinedCommunities,
                    onSelectAll: { store.selectedCommunity = nil },
                    onSelectCommunity: { store.selectedCommunity = $0 }
                )

                PulseWeeklyHighlightSection(
                    highlight: store.weeklyHighlight,
                    ranking: store.lightRanking,
                    imageLoader: { store.loadImage(for: $0) }
                )
                .padding(.horizontal, 16)

                if store.visiblePosts.isEmpty {
                    PulseEmptyFeedState(
                        card: shareCardStore.card(for: .individual),
                        previewImage: shareCardStore.previewImage(for: .individual),
                        onPublishWorkout: publishLastWorkoutToPulse
                    )
                    .padding(.horizontal, 16)
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(Array(store.pagedVisiblePosts.enumerated()), id: \.element.id) { index, post in
                            PulsePostCard(
                                post: post,
                                image: nil,
                                imagePath: store.mediaPath(for: post),
                                videoURL: (PulseExperimental.isVideoPostsEnabledInBuild && post.mediaKind == .video)
                                    ? post.mediaFileName.map { store.mediaURL(for: $0) }
                                    : nil,
                                currentUserId: authorId,
                                currentUserAvatar: authService.profileImage,
                                mentionCandidates: store.followingPeople(of: authorId),
                                isCommunityActive: store.joinedCommunities.contains(post.community),
                                commentText: Binding(
                                    get: { commentDrafts[post.id] ?? "" },
                                    set: { commentDrafts[post.id] = $0 }
                                ),
                                shouldAutoPlayMusic: autoPlayMusicPostId == post.id,
                                avatarLoader: { store.loadReactionAvatar($0) },
                                commentAvatarLoader: { store.loadUserAvatar(userId: $0) },
                                onHeart: {
                                    store.toggleHeart(
                                        postId: post.id,
                                        userId: authorId,
                                        userName: authorName,
                                        avatar: authService.profileImage
                                    )
                                },
                                onComment: {
                                    store.addComment(
                                        to: post.id,
                                        authorId: authorId,
                                        authorName: authorName,
                                        text: commentDrafts[post.id] ?? "",
                                        avatar: authService.profileImage
                                    )
                                    commentDrafts[post.id] = ""
                                },
                                onShowReactions: { reactionsToShow = post.reactions.filter(\.isHeart) },
                                onReport: { store.reportPost(post.id, reporterId: authorId) },
                                onHide: { store.hidePost(post.id) },
                                onBlockAuthor: { store.blockUser(post.authorId) },
                                onEdit: { editingPost = post },
                                onDelete: { store.deletePost(post.id, by: authorId) },
                                onShareExternal: {
                                    prepareExternalShare(
                                        post: post,
                                        image: store.loadImage(for: post),
                                        videoURL: post.mediaKind == .video
                                            ? post.mediaFileName.map { store.mediaURL(for: $0) }
                                            : nil
                                    )
                                },
                                onAppearIndex: { store.loadMoreFeedIfNeeded(currentIndex: index) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 12)
        }
        .coordinateSpace(name: "pulseFeed")
        .onPreferenceChange(PulsePostVisibilityKey.self) { reports in
            scheduleMusicAutoplay(from: reports)
        }
        .onDisappear {
            musicVisibilityTask?.cancel()
            musicVisibilityTask = nil
            autoPlayMusicPostId = nil
            PulseMusicPreviewPlayer.shared.pause()
        }
    }

    /// Toca a música do post cujo card está mais perto do centro do ecrã.
    private func scheduleMusicAutoplay(from reports: [UUID: PulseMusicVisibility]) {
        musicVisibilityTask?.cancel()
        musicVisibilityTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }

            let eligible = reports.values.filter { report in
                report.hasPreview && report.overlap >= 0.15
            }
            guard let best = eligible.min(by: { $0.centerDistance < $1.centerDistance }) else {
                if autoPlayMusicPostId != nil {
                    autoPlayMusicPostId = nil
                    PulseMusicPreviewPlayer.shared.pause()
                }
                return
            }
            if autoPlayMusicPostId != best.postId {
                autoPlayMusicPostId = best.postId
            }
        }
    }

    private var postComposerHub: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.Pulse.tabPost)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Text(PulseExperimental.isVideoPostsEnabledInBuild
                     ? "Crie um card com foto ou vídeo para aparecer no feed do Pulse (24h)."
                     : "Crie um card com foto para aparecer no feed do Pulse (24h).")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)

                Button {
                    showCompose = true
                } label: {
                    Label("Criar post para o feed", systemImage: "plus.rectangle.fill.on.rectangle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Stories continuam no topo do Feed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Toque no círculo “Seu story” no Feed para publicar stories com música e texto.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    Button {
                        selectedTab = .feed
                        showStoryCompose = true
                    } label: {
                        Label("Criar story", systemImage: "circle.dashed")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                }
                .padding(14)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            // Abre o composer ao entrar na aba POST.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if selectedTab == .post {
                    showCompose = true
                }
            }
        }
    }

    private func prepareExternalShare(post: PulsePost, image: UIImage?, videoURL: URL?) {
        Task { @MainActor in
            let package: PulseShareService.Package
            if let videoURL {
                package = await PulseShareService.makeSharePackage(videoURL: videoURL, post: post)
            } else {
                package = await PulseShareService.makeSharePackage(image: image, post: post)
            }
            pendingShareItems = package.items
            if post.music != nil {
                shareHintMessage = L10n.Pulse.shareHintMusic
            } else {
                shareHintMessage = L10n.Pulse.shareHintDefault
            }
            showShareAfterPost = true
        }
    }

    private func publishLastWorkoutToPulse() {
        guard let card = shareCardStore.card(for: .individual) else {
            errorMessage = "Nenhum treino recente para publicar."
            return
        }
        let intensity = workoutStore.sessionHistory
            .first(where: { $0.id == card.sessionId })?
            .perceivedEffort
        do {
            try store.publishWorkoutCard(
                authorId: authorId,
                authorName: authorName,
                authorCountryCode: authorCountryCode,
                card: card,
                preview: shareCardStore.previewImage(for: .individual),
                community: .musculacao,
                intensity: intensity,
                caption: nil
            )
            if let latest = store.visiblePosts.first(where: { $0.authorId == authorId }) {
                prepareExternalShare(
                    post: latest,
                    image: shareCardStore.previewImage(for: .individual),
                    videoURL: nil
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Bottom bar

    private var pulseBottomBar: some View {
        HStack(spacing: 0) {
            bottomItem(.feed, title: L10n.Pulse.tabFeed, icon: "rectangle.stack.fill")
            bottomItem(.post, title: L10n.Pulse.tabPost, icon: "plus.rectangle.fill.on.rectangle.fill")
            bottomItem(.communities, title: L10n.Pulse.tabCommunity, icon: "person.3.fill")
            bottomItem(.people, title: L10n.Pulse.tabPeople, icon: "magnifyingglass")
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            AppTheme.cardBackground
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func bottomItem(_ tab: PulseBottomTab, title: String, icon: String) -> some View {
        Button {
            selectedTab = tab
            if tab == .post {
                showCompose = true
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(selectedTab == tab ? AppTheme.accent : AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct PulseUGCAgeGateView: View {
    let age: Int

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accent)
            Text(L10n.Pulse.ageGateTitle(PulseExperimental.ugcMinimumAge))
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text(
                age > 0
                    ? L10n.Pulse.ageGateBodyKnown(age, PulseExperimental.ugcMinimumAge)
                    : L10n.Pulse.ageGateBodyUnknown(PulseExperimental.ugcMinimumAge)
            )
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

// MARK: - Feed sections

private struct PulseDailyChallengeCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "target")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Pulse.dailyChallenge)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }
}

private struct PulseCommunityChips: View {
    let selectedCommunity: PulseCommunity?
    let joinedCommunities: Set<PulseCommunity>
    var onSelectAll: () -> Void
    var onSelectCommunity: (PulseCommunity) -> Void

    /// Só comunidades ATIVO (temáticas + modalidades de cardio), ao lado de Todos.
    private var activeCommunities: [PulseCommunity] {
        let thematic = PulseCommunity.thematicCases.filter { joinedCommunities.contains($0) }
        let modalities = PulseCommunity.cardioModalityCases.filter { joinedCommunities.contains($0) }
        return thematic + modalities
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Todos", systemImage: "sparkles", isSelected: selectedCommunity == nil, action: onSelectAll)
                ForEach(activeCommunities) { community in
                    chip(
                        title: community.title,
                        systemImage: community.systemImage,
                        isSelected: selectedCommunity == community,
                        showsActiveBadge: true,
                        action: { onSelectCommunity(community) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            if let selectedCommunity, !joinedCommunities.contains(selectedCommunity) {
                onSelectAll()
            }
        }
        .onChange(of: joinedCommunities) { _, newValue in
            if let selectedCommunity, !newValue.contains(selectedCommunity) {
                onSelectAll()
            }
        }
    }

    private func chip(
        title: String,
        systemImage: String,
        isSelected: Bool,
        showsActiveBadge: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Label(title, systemImage: systemImage)
                if showsActiveBadge {
                    Text(L10n.Pulse.active.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(isSelected ? 0.25 : 0.12))
                        .clipShape(Capsule())
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AnyShapeStyle(AppTheme.gradientPrimary) : AnyShapeStyle(Color.white.opacity(0.10)))
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? .clear : AppTheme.accent.opacity(0.45), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct PulseWeeklyHighlightSection: View {
    let highlight: PulsePost?
    let ranking: [(name: String, score: Int)]
    var imageLoader: (PulsePost) -> UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Pulse.weeklyHighlight)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            if let highlight {
                HStack(spacing: 12) {
                    highlightThumbnail(for: highlight)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(highlight.authorName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(CountryOption.flagEmoji(for: highlight.authorCountryCode))
                                .font(.caption)
                        }
                        Text(highlight.caption)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                        Text("\(highlight.engagementScore) pts de engajamento")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Text("Publique algo esta semana para aparecer aqui.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if !ranking.isEmpty {
                Divider().overlay(Color.white.opacity(0.08))
                Text(L10n.Pulse.lightRanking)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(Array(ranking.enumerated()), id: \.offset) { index, entry in
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 20, alignment: .leading)
                        Text(entry.name)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("\(entry.score)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }

    @ViewBuilder
    private func highlightThumbnail(for post: PulsePost) -> some View {
        Group {
            if let image = imageLoader(post) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.gradientPrimary.opacity(0.35)
                    Image(systemName: post.systemImagePlaceholder ?? "photo")
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct PulseEmptyFeedState: View {
    let card: LastWorkoutShareCard?
    let previewImage: UIImage?
    var onPublishWorkout: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accent.opacity(0.8))

            Text(L10n.Pulse.emptyFeedTitle)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if let card {
                Text(L10n.Pulse.emptyFeedShareWorkout(card.workoutTitle))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(L10n.Pulse.publishWorkout, action: onPublishWorkout)
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Text(L10n.Pulse.emptyFeedBodyNoWorkout)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Stories rail

private struct PulseStoriesRail: View {
    let stories: [PulseStory]
    let currentUserId: String
    let currentUserImage: UIImage?
    var storyImage: (PulseStory) -> UIImage?
    var onAddStory: () -> Void
    var onOpenStory: (PulseStory) -> Void

    private var ownStories: [PulseStory] {
        stories.filter { $0.authorId == currentUserId }
    }

    private var otherStories: [PulseStory] {
        stories.filter { $0.authorId != currentUserId }
    }

    private var latestOwnStory: PulseStory? {
        ownStories.first
    }

    private var ownRingStyle: PulseStoryRingStyle {
        guard let latestOwnStory else { return .idle }
        return latestOwnStory.isViewed ? .idle : .pulsingGreen
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                PulseStoryBubble(
                    title: L10n.Pulse.storyYours,
                    image: currentUserImage,
                    placeholder: "person.fill",
                    ringStyle: ownRingStyle,
                    showsPlusBadge: true,
                    hasMusic: latestOwnStory?.music != nil,
                    onTap: {
                        if let latestOwnStory {
                            onOpenStory(latestOwnStory)
                        } else {
                            onAddStory()
                        }
                    },
                    onPlus: onAddStory
                )

                ForEach(otherStories) { story in
                    PulseStoryBubble(
                        title: story.authorName,
                        image: storyImage(story) ?? currentUserImageIfMatching(story),
                        placeholder: story.systemImagePlaceholder ?? "person.fill",
                        ringStyle: story.isViewed ? .idle : .pulsingGreen,
                        showsPlusBadge: false,
                        hasMusic: story.music != nil,
                        onTap: { onOpenStory(story) },
                        onPlus: nil
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func currentUserImageIfMatching(_ story: PulseStory) -> UIImage? {
        story.authorId == currentUserId ? currentUserImage : nil
    }
}

private enum PulseStoryRingStyle {
    case idle
    case pulsingGreen
}

private struct PulseStoryBubble: View {
    let title: String
    let image: UIImage?
    let placeholder: String
    let ringStyle: PulseStoryRingStyle
    let showsPlusBadge: Bool
    var hasMusic: Bool = false
    var onTap: () -> Void
    var onPlus: (() -> Void)?

    @State private var isPulsing = false

    private let ringSize: CGFloat = 68
    private let avatarSize: CGFloat = 58

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: onTap) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                ringStroke,
                                lineWidth: ringStyle == .pulsingGreen
                                    ? (isPulsing ? 3.5 : 2.25)
                                    : 2
                            )
                            .frame(width: ringSize, height: ringSize)
                            .opacity(ringStyle == .pulsingGreen ? (isPulsing ? 1 : 0.45) : 1)

                        avatarView
                            .frame(width: avatarSize, height: avatarSize)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(AppTheme.background, lineWidth: 2)
                            )
                    }
                    .frame(width: ringSize, height: ringSize)
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)

                if showsPlusBadge {
                    Button {
                        onPlus?()
                    } label: {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 22, height: 22)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .overlay(Circle().strokeBorder(AppTheme.background, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 2, y: 2)
                } else if hasMusic {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay(Circle().strokeBorder(AppTheme.background, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: ringSize + 4, height: ringSize + 4)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .frame(width: 76)
        }
        .onAppear {
            startPulsingIfNeeded(for: ringStyle)
        }
        .onChange(of: ringStyle) { _, newStyle in
            startPulsingIfNeeded(for: newStyle)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: avatarSize, height: avatarSize)
                .clipped()
        } else {
            ZStack {
                AppTheme.cardBackground
                Image(systemName: placeholder)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: avatarSize, height: avatarSize)
        }
    }

    private var ringStroke: AnyShapeStyle {
        switch ringStyle {
        case .idle:
            return AnyShapeStyle(Color.white.opacity(0.28))
        case .pulsingGreen:
            return AnyShapeStyle(AppTheme.accent)
        }
    }

    private func startPulsingIfNeeded(for style: PulseStoryRingStyle) {
        guard style == .pulsingGreen else {
            withAnimation(.easeOut(duration: 0.2)) { isPulsing = false }
            return
        }
        isPulsing = false
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

private struct PulseStoryBrowseSession: Identifiable {
    let id: UUID
    let stories: [PulseStory]
    let startIndex: Int

    static func make(from allActive: [PulseStory], focusing: PulseStory) -> PulseStoryBrowseSession {
        let peers = allActive
            .filter { $0.authorId == focusing.authorId }
            .sorted { $0.createdAt < $1.createdAt }
        let queue = peers.isEmpty ? [focusing] : peers
        let idx = queue.firstIndex(where: { $0.id == focusing.id }) ?? 0
        return PulseStoryBrowseSession(id: focusing.id, stories: queue, startIndex: idx)
    }
}

private struct PulseStoryViewer: View {
    let session: PulseStoryBrowseSession
    var imageLoader: (PulseStory) -> UIImage?
    var profileImageLoader: (PulseStory) -> UIImage?
    let currentUserId: String
    var avatarLoader: (PulseReactionEvent) -> UIImage?
    var onHeart: (UUID) -> Void
    var onShowReactions: ([PulseReactionEvent]) -> Void
    var onDelete: (UUID) -> Void
    var onClose: () -> Void
    var onViewed: (UUID) -> Void

    @ObservedObject private var musicPlayer = PulseMusicPreviewPlayer.shared
    @State private var index: Int = 0
    @State private var progress: Double = 0
    @State private var isPaused = false
    @State private var tickTask: Task<Void, Never>?

    private var stories: [PulseStory] { session.stories }

    private var story: PulseStory {
        let safe = min(max(index, 0), max(stories.count - 1, 0))
        return stories[safe]
    }

    private var isOwner: Bool { story.authorId == currentUserId }

    private var heartReactions: [PulseReactionEvent] {
        story.reactions.filter(\.isHeart)
    }

    private var viewDuration: TimeInterval { PulseExperimental.storyViewDuration }

    var body: some View {
        GeometryReader { geo in
            let bottomHeight = bottomChromeHeight
            let topHeight: CGFloat = 72
            let photoHeight = max(120, geo.size.height - topHeight - bottomHeight)

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    progressBars
                    topChrome
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(height: topHeight)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.92))
                .zIndex(2)

                ZStack {
                    Color.black
                    if let image = imageLoader(story) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: photoHeight)
                            .clipped()
                            .id(story.id)
                    } else {
                        Image(systemName: story.systemImagePlaceholder ?? "photo")
                            .font(.system(size: 72))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    ForEach(story.textOverlays) { overlay in
                        PulseStoryTextLabel(overlay: overlay)
                            .position(
                                x: geo.size.width * overlay.x,
                                y: photoHeight * overlay.y
                            )
                            .allowsHitTesting(false)
                    }

                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { goPrevious() }
                            .onLongPressGesture(minimumDuration: 0.12, maximumDistance: 40, pressing: { pressing in
                                if pressing { pause() } else { resume() }
                            }, perform: {})
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { goNext() }
                            .onLongPressGesture(minimumDuration: 0.12, maximumDistance: 40, pressing: { pressing in
                                if pressing { pause() } else { resume() }
                            }, perform: {})
                    }
                }
                .frame(width: geo.size.width, height: photoHeight)
                .clipped()

                bottomChrome
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.95))
                    .zIndex(2)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            index = min(max(session.startIndex, 0), max(stories.count - 1, 0))
            startCurrentStory()
        }
        .onDisappear {
            tickTask?.cancel()
            musicPlayer.stop()
        }
        .onChange(of: index) { _, _ in
            startCurrentStory()
        }
    }

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(Array(stories.enumerated()), id: \.element.id) { i, _ in
                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: barGeo.size.width * segmentProgress(for: i))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    private func segmentProgress(for i: Int) -> CGFloat {
        if i < index { return 1 }
        if i > index { return 0 }
        return CGFloat(min(max(progress, 0), 1))
    }

    private var bottomChromeHeight: CGFloat {
        var height: CGFloat = 88
        if story.music != nil { height += 72 }
        if !heartReactions.isEmpty { height += 44 }
        return height
    }

    private var topChrome: some View {
        HStack(alignment: .center, spacing: 10) {
            profileAvatar

            VStack(alignment: .leading, spacing: 2) {
                Text(story.authorName.isEmpty ? L10n.Pulse.athlete : story.authorName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let music = story.music {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.caption2.weight(.bold))
                        Text("\(music.title) — \(music.artistName)")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
                } else {
                    Text("\(Int(viewDuration))s · \(index + 1)/\(max(stories.count, 1))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isOwner {
                Button {
                    let id = story.id
                    onDelete(id)
                    onClose()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Pulse.storyDelete)
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black.opacity(0.5), .white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Pulse.close)
        }
    }

    private var profileAvatar: some View {
        Group {
            if let profileImage = profileImageLoader(story) {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.accent.opacity(0.35)
                    Text(String((story.authorName.isEmpty ? "A" : story.authorName).prefix(1)).uppercased())
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
    }

    private var bottomChrome: some View {
        VStack(spacing: 10) {
            if let music = story.music {
                PulseMusicStickerView(music: music, previewPlayer: musicPlayer, compact: true)
            }

            if !heartReactions.isEmpty {
                Button {
                    onShowReactions(heartReactions)
                } label: {
                    HStack(spacing: -8) {
                        ForEach(heartReactions.prefix(3)) { reaction in
                            PulseReactionAvatarView(
                                name: reaction.userName,
                                image: avatarLoader(reaction),
                                size: 28
                            )
                            .overlay(Circle().strokeBorder(.black, lineWidth: 1.5))
                        }
                        Text("\(heartReactions.count) curtida\(heartReactions.count == 1 ? "" : "s")")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.leading, 14)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                onHeart(story.id)
            } label: {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accent)
                    .padding(8)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Curtir com coração")
        }
    }

    private func startCurrentStory() {
        tickTask?.cancel()
        progress = 0
        isPaused = false
        onViewed(story.id)
        musicPlayer.stop()
        if let music = story.music {
            musicPlayer.play(music: music, loop: true)
        }
        tickTask = Task { @MainActor in
            let steps = 60
            let stepNanoseconds = UInt64((viewDuration / Double(steps)) * 1_000_000_000)
            for step in 1...steps {
                if Task.isCancelled { return }
                while isPaused {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                try? await Task.sleep(nanoseconds: stepNanoseconds)
                if Task.isCancelled { return }
                progress = Double(step) / Double(steps)
            }
            goNext()
        }
    }

    private func pause() { isPaused = true }
    private func resume() { isPaused = false }

    private func goPrevious() {
        guard index > 0 else {
            progress = 0
            startCurrentStory()
            return
        }
        index -= 1
    }

    private func goNext() {
        if index + 1 < stories.count {
            index += 1
        } else {
            onClose()
        }
    }
}

private struct PulseReactionAvatarView: View {
    let name: String
    let image: UIImage?
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.accent.opacity(0.3)
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private struct PulseReactionsSheetItem: Identifiable {
    let reactions: [PulseReactionEvent]
    var id: String { reactions.map(\.id.uuidString).joined(separator: "|") }
}

private struct PulseReactionsListView: View {
    let reactions: [PulseReactionEvent]
    var avatarLoader: (PulseReactionEvent) -> UIImage?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(reactions.sorted { $0.createdAt > $1.createdAt }) { reaction in
                HStack(spacing: 12) {
                    PulseReactionAvatarView(
                        name: reaction.userName,
                        image: avatarLoader(reaction),
                        size: 42
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reaction.userName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(reaction.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if reaction.isHeart {
                        Image(systemName: "heart.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.accent)
                    } else {
                        Text(reaction.emojiLabel)
                            .font(.title3)
                    }
                }
                .listRowBackground(AppTheme.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Curtidas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Pulse.close) { dismiss() }
                }
            }
        }
    }
}

private struct PulseStoryComposeView: View {
    var onPublish: (UIImage, PulseMusicAttachment?, [PulseStoryTextOverlay]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: UIImage?
    @State private var selectedMusic: PulseMusicAttachment?
    @State private var textOverlays: [PulseStoryTextOverlay] = []
    @State private var selectedOverlayID: UUID?
    @State private var draftText = ""
    @State private var selectedFont: PulseStoryFontStyle = .modern
    @State private var isBold = true
    @State private var selectedColor = "#FFFFFF"
    @State private var showSourceDialog = false
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showMusicPicker = false
    @FocusState private var textFieldFocused: Bool

    private let colors = ["#FFFFFF", "#A8FF60", "#FFD60A", "#FF6B6B", "#5AC8FA", "#BF5AF2"]
    private let emojiQuick = ["🔥", "💪", "👏", "💚", "🏃", "🧘", "🏆", "✨", "❤️", "😎"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Button {
                        showSourceDialog = true
                    } label: {
                        Label(
                            selectedPhoto == nil ? "Câmera ou galeria" : "Trocar foto",
                            systemImage: "camera.fill"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    storyCanvas

                    textTools

                    Button {
                        showMusicPicker = true
                    } label: {
                        Label(
                            selectedMusic.map { "\($0.providerLabel): \($0.title)" }
                                ?? L10n.Pulse.storyAddMusic,
                            systemImage: "music.note.list"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)

                    if selectedMusic != nil {
                        PulseMusicClipEditor(music: Binding(
                            get: { selectedMusic! },
                            set: { selectedMusic = $0 }
                        ))
                    }

                    Button(L10n.Pulse.storyPublish) {
                        if let selectedPhoto {
                            onPublish(selectedPhoto, selectedMusic, textOverlays.filter {
                                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            })
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: selectedPhoto != nil))
                    .disabled(selectedPhoto == nil)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.Pulse.storyNew)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismissKeyboard()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Apagar texto") {
                        deleteSelectedOverlay()
                    }
                    .foregroundStyle(.red)
                    Spacer()
                    Button("Pronto") {
                        dismissKeyboard()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if textFieldFocused {
                    HStack(spacing: 12) {
                        Button("Apagar") {
                            deleteSelectedOverlay()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        Spacer()
                        Button("Pronto") {
                            dismissKeyboard()
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
            }
            .confirmationDialog("Adicionar foto", isPresented: $showSourceDialog, titleVisibility: .visible) {
                if PhotoCaptureAvailability.isCameraAvailable {
                    Button("Câmera") { showCamera = true }
                }
                Button("Galeria") { showLibrary = true }
                Button(L10n.Common.cancel, role: .cancel) {}
            }
            .sheet(isPresented: $showLibrary) {
                LibraryImagePicker { image in
                    showLibrary = false
                    if let image { selectedPhoto = image }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { image in
                    showCamera = false
                    if let image { selectedPhoto = image }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showMusicPicker) {
                PulseMusicPickerView(selectedTrack: $selectedMusic)
            }
        }
    }

    @ViewBuilder
    private var storyCanvas: some View {
        if let selectedPhoto {
            ZStack {
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        Image(uiImage: selectedPhoto)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .clipped()

                        ForEach($textOverlays) { $overlay in
                            PulseStoryDraggableText(
                                overlay: $overlay,
                                canvasSize: size,
                                isSelected: overlay.id == selectedOverlayID,
                                onSelect: { focusKeyboard in
                                    selectedOverlayID = overlay.id
                                    draftText = overlay.text.trimmingCharacters(in: .whitespacesAndNewlines)
                                    selectedFont = overlay.fontStyle
                                    isBold = overlay.isBold
                                    selectedColor = overlay.colorHex
                                    if focusKeyboard {
                                        textFieldFocused = true
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                if let selectedMusic {
                    VStack(alignment: .leading, spacing: 4) {
                        PulseMusicTrackRow(track: selectedMusic, isSelected: true)
                        Text("Trecho \(selectedMusic.clipRangeLabel) · \(Int(selectedMusic.clipDurationSeconds.rounded()))s")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 4)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(10)
                }
            }
            .overlay(alignment: .topTrailing) {
                Text("Arraste o texto na foto")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Capsule())
                    .padding(10)
                    .allowsHitTesting(false)
            }
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground)
                .frame(height: 240)
                .overlay {
                    Text("Escolha uma foto para escrever por cima")
                        .foregroundStyle(AppTheme.textSecondary)
                }
        }
    }

    private var textTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Texto / emoji")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)

            TextField("Digite — aparece na foto na hora", text: $draftText, axis: .vertical)
                .lineLimit(1...3)
                .padding(12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($textFieldFocused)
                .disabled(selectedPhoto == nil)
                .onChange(of: draftText) { _, newValue in
                    syncLiveText(newValue)
                }
                .onChange(of: textFieldFocused) { _, focused in
                    if focused { ensureLiveOverlayIfNeeded() }
                }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(emojiQuick, id: \.self) { emoji in
                        Button(emoji) {
                            ensureLiveOverlayIfNeeded()
                            draftText.append(emoji)
                        }
                        .font(.title3)
                        .disabled(selectedPhoto == nil)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PulseStoryFontStyle.allCases) { style in
                        Button(style.title) {
                            selectedFont = style
                            applyStyleToSelected()
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(selectedFont == style ? AppTheme.accent : AppTheme.cardBackground)
                        .foregroundStyle(selectedFont == style ? Color.white : AppTheme.textSecondary)
                        .clipShape(Capsule())
                    }
                    Button(isBold ? "Negrito" : "Normal") {
                        isBold.toggle()
                        applyStyleToSelected()
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.cardBackground)
                    .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                ForEach(colors, id: \.self) { hex in
                    Circle()
                        .fill(Color(pulseHex: hex))
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(selectedColor == hex ? AppTheme.accent : .clear, lineWidth: 2))
                        .onTapGesture {
                            selectedColor = hex
                            applyStyleToSelected()
                        }
                }
                Spacer()
                Button {
                    startNewTextOverlay()
                } label: {
                    Label("Novo texto", systemImage: "plus")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(selectedPhoto == nil)

                if selectedOverlayID != nil {
                    Button("Apagar", role: .destructive) {
                        deleteSelectedOverlay()
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            if selectedOverlayID != nil {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("A")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Slider(
                            value: Binding(
                                get: {
                                    textOverlays.first(where: { $0.id == selectedOverlayID })?.scale ?? 1
                                },
                                set: { newValue in
                                    guard let idx = textOverlays.firstIndex(where: { $0.id == selectedOverlayID }) else { return }
                                    textOverlays[idx].scale = min(max(newValue, 0.35), 2.2)
                                }
                            ),
                            in: 0.35...2.2
                        )
                        .tint(AppTheme.accent)
                        Text("A")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Text("Diminua ou aumente a fonte do texto selecionado.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Text("Toque em “Novo texto” para outro sticker. Arraste na foto para mover; pinça para redimensionar. Use Pronto para fechar o teclado.")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func deleteSelectedOverlay() {
        dismissKeyboard()
        textOverlays.removeAll { $0.id == selectedOverlayID }
        selectedOverlayID = nil
        draftText = ""
    }

    private func dismissKeyboard() {
        textFieldFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }

    private func ensureLiveOverlayIfNeeded() {
        guard selectedPhoto != nil else { return }
        if let selectedOverlayID,
           textOverlays.contains(where: { $0.id == selectedOverlayID }) {
            return
        }
        startNewTextOverlay(seedText: draftText)
    }

    private func startNewTextOverlay(seedText: String? = nil) {
        guard selectedPhoto != nil else { return }
        let text = String((seedText ?? "").prefix(80))
        let overlay = PulseStoryTextOverlay(
            text: text.isEmpty ? " " : text,
            fontStyle: selectedFont,
            isBold: isBold,
            colorHex: selectedColor,
            x: 0.5,
            y: min(0.38 + Double(textOverlays.count) * 0.1, 0.82),
            scale: 1
        )
        textOverlays.append(overlay)
        selectedOverlayID = overlay.id
        draftText = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : text
        textFieldFocused = true
    }

    private func syncLiveText(_ text: String) {
        guard selectedPhoto != nil else { return }
        let clipped = String(text.prefix(80))
        if let selectedOverlayID,
           let idx = textOverlays.firstIndex(where: { $0.id == selectedOverlayID }) {
            textOverlays[idx].text = clipped.isEmpty ? " " : clipped
            return
        }
        if !clipped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            startNewTextOverlay(seedText: clipped)
        }
    }

    private func applyStyleToSelected() {
        ensureLiveOverlayIfNeeded()
        guard let selectedOverlayID,
              let idx = textOverlays.firstIndex(where: { $0.id == selectedOverlayID }) else { return }
        textOverlays[idx].fontStyle = selectedFont
        textOverlays[idx].isBold = isBold
        textOverlays[idx].colorHex = selectedColor
    }
}

/// Texto arrastável / pinçável no canvas do story (estilo Instagram).
private struct PulseStoryDraggableText: View {
    @Binding var overlay: PulseStoryTextOverlay
    let canvasSize: CGSize
    var isSelected: Bool
    var onSelect: (_ focusKeyboard: Bool) -> Void

    @State private var dragOrigin: CGPoint?
    @State private var pinchBaseScale: Double?

    var body: some View {
        PulseStoryTextLabel(overlay: overlay, isSelected: isSelected)
            .position(
                x: canvasSize.width * overlay.x,
                y: canvasSize.height * overlay.y
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragOrigin == nil {
                            dragOrigin = CGPoint(
                                x: canvasSize.width * overlay.x,
                                y: canvasSize.height * overlay.y
                            )
                            onSelect(false)
                        }
                        guard let origin = dragOrigin else { return }
                        let nx = (origin.x + value.translation.width) / max(canvasSize.width, 1)
                        let ny = (origin.y + value.translation.height) / max(canvasSize.height, 1)
                        overlay.x = min(max(nx, 0.06), 0.94)
                        overlay.y = min(max(ny, 0.06), 0.94)
                    }
                    .onEnded { _ in
                        dragOrigin = nil
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { magnification in
                        if pinchBaseScale == nil {
                            pinchBaseScale = overlay.scale
                            onSelect(false)
                        }
                        guard let base = pinchBaseScale else { return }
                        overlay.scale = min(max(base * Double(magnification), 0.35), 2.2)
                    }
                    .onEnded { _ in
                        pinchBaseScale = nil
                    }
            )
            .onTapGesture { onSelect(true) }
    }
}

private struct PulseStoryTextLabel: View {
    let overlay: PulseStoryTextOverlay
    var isSelected: Bool = false

    var body: some View {
        Text(displayText)
            .font(font)
            .foregroundStyle(Color(pulseHex: overlay.colorHex))
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.75), radius: 3, y: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.black.opacity(0.28) : Color.black.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.white.opacity(0.85) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(overlay.scale)
            .contentShape(Rectangle())
    }

    private var displayText: String {
        let trimmed = overlay.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Texto" : overlay.text
    }

    private var font: Font {
        let size: CGFloat = 24
        let weight: Font.Weight = overlay.isBold ? .bold : .semibold
        switch overlay.fontStyle {
        case .modern:
            return .system(size: size, weight: weight, design: .default)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        case .poster:
            return .system(size: size + 8, weight: .black, design: .rounded)
        }
    }
}

private extension Color {
    init(pulseHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Post card

private struct PulsePostCard: View {
    let post: PulsePost
    let image: UIImage?
    var imagePath: String? = nil
    let videoURL: URL?
    let currentUserId: String
    let currentUserAvatar: UIImage?
    let mentionCandidates: [PulsePerson]
    let isCommunityActive: Bool
    @Binding var commentText: String
    var shouldAutoPlayMusic: Bool = false
    var avatarLoader: (PulseReactionEvent) -> UIImage?
    var commentAvatarLoader: (String) -> UIImage?
    var onAutoPlayHandled: () -> Void = {}
    var onHeart: () -> Void
    var onComment: () -> Void
    var onShowReactions: () -> Void
    var onReport: () -> Void
    var onHide: () -> Void
    var onBlockAuthor: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onShareExternal: () -> Void = {}
    var onAppearIndex: (() -> Void)? = nil

    @ObservedObject private var musicPlayer = PulseMusicPreviewPlayer.shared
    /// Atualiza durante o scroll para reenviar a preference de visibilidade.
    @State private var scrollVisibilityTick: CGFloat = 0

    private var canSendComment: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isOwner: Bool { post.authorId == currentUserId }

    private var heartReactions: [PulseReactionEvent] {
        post.reactions.filter(\.isHeart)
    }

    private var authorAvatar: UIImage? {
        if post.authorId == currentUserId {
            return currentUserAvatar ?? commentAvatarLoader(post.authorId)
        }
        return commentAvatarLoader(post.authorId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                PulseReactionAvatarView(
                    name: post.authorName,
                    image: authorAvatar,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(post.authorName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Text(CountryOption.flagEmoji(for: post.authorCountryCode))
                            .font(.caption)
                    }
                    Text("\(post.createdAt.formatted(date: .abbreviated, time: .shortened)) · 24h")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                    communityBadge
                }
                Spacer(minLength: 8)
                Menu {
                    if isOwner {
                        Button(L10n.Pulse.menuEdit, action: onEdit)
                        Button(L10n.Pulse.menuDelete, role: .destructive, action: onDelete)
                    }
                    Button(L10n.Pulse.menuShareInstagram, action: onShareExternal)
                    Button(L10n.Pulse.menuReport, action: onReport)
                    Button(L10n.Pulse.menuHide, action: onHide)
                    if !isOwner {
                        Button(L10n.Pulse.menuBlock, role: .destructive, action: onBlockAuthor)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(8)
                }
            }

            // Mostra a mídia na proporção real (card de treino é mais alto que 1:1).
            // Cantos arredondados escondem residual preto de exports JPEG antigos.
            ZStack(alignment: .bottomTrailing) {
                mediaView
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: post.workoutMeta != nil ? 22 : 14, style: .continuous))

                if post.workoutMeta == nil {
                    Text("HealthFit")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45))
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                        .padding(10)
                }
            }

            if let music = post.music {
                PulseMusicStickerView(music: music, previewPlayer: musicPlayer, compact: true)
            }

            if let meta = post.workoutMeta {
                PulseWorkoutMetaChips(meta: meta)
            }

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            HStack(spacing: 14) {
                Button(action: onHeart) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.circle.fill")
                            .font(.title3)
                        Text("\(post.heartCount)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Curtir com coração")

                Spacer()
                Label("\(post.comments.count)", systemImage: "bubble.right.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if !heartReactions.isEmpty {
                Button(action: onShowReactions) {
                    HStack(spacing: -8) {
                        ForEach(heartReactions.prefix(4)) { reaction in
                            PulseReactionAvatarView(
                                name: reaction.userName,
                                image: avatarLoader(reaction),
                                size: 26
                            )
                            .overlay(Circle().strokeBorder(AppTheme.background, lineWidth: 1.5))
                        }
                        Text("Ver quem curtiu · \(heartReactions.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.leading, 14)
                    }
                }
                .buttonStyle(.plain)
            }

            if !post.comments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(post.comments) { comment in
                        HStack(alignment: .top, spacing: 8) {
                            PulseReactionAvatarView(
                                name: comment.authorName,
                                image: comment.authorId == currentUserId
                                    ? (currentUserAvatar ?? commentAvatarLoader(comment.authorId))
                                    : commentAvatarLoader(comment.authorId),
                                size: 28
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(comment.authorName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(comment.text)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                PulseReactionAvatarView(
                    name: "Você",
                    image: currentUserAvatar ?? commentAvatarLoader(currentUserId),
                    size: 32
                )
                PulseMentionTextField(
                    text: $commentText,
                    candidates: mentionCandidates,
                    placeholder: "Comente ou @marque…"
                )
                Button(action: onComment) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            canSendComment
                                ? AnyShapeStyle(AppTheme.gradientPrimary)
                                : AnyShapeStyle(Color.gray.opacity(0.35))
                        )
                        .clipShape(Circle())
                }
                .disabled(!canSendComment)
                .accessibilityLabel("Enviar comentário")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
        .background {
            GeometryReader { geo in
                let frame = geo.frame(in: .global)
                let screen = UIScreen.main.bounds
                let report = Self.musicVisibility(
                    postId: post.id,
                    hasPreview: post.music?.previewURL != nil,
                    card: frame,
                    screen: screen
                )
                Color.clear
                    .preference(
                        key: PulsePostVisibilityKey.self,
                        value: report.hasPreview ? [post.id: report] : [:]
                    )
                    .onChange(of: frame.minY) { _, minY in
                        scrollVisibilityTick = minY
                    }
                    .onAppear {
                        scrollVisibilityTick = frame.minY
                    }
            }
        }
        .onAppear {
            onAppearIndex?()
            if shouldAutoPlayMusic, let music = post.music {
                musicPlayer.play(music: music, loop: true)
            }
        }
        .onChange(of: shouldAutoPlayMusic) { _, shouldPlay in
            guard let music = post.music else { return }
            if shouldPlay {
                musicPlayer.play(music: music, loop: true)
            } else if musicPlayer.isPlayingMusic(music) {
                musicPlayer.pause()
            }
        }
    }

    private static func musicVisibility(
        postId: UUID,
        hasPreview: Bool,
        card frame: CGRect,
        screen: CGRect
    ) -> PulseMusicVisibility {
        let visible = frame.intersection(screen)
        let overlap: CGFloat = (frame.height > 1 && visible.height > 1)
            ? min(1, visible.height / frame.height)
            : 0
        let centerDistance = abs(frame.midY - screen.midY) / max(screen.height, 1)
        return PulseMusicVisibility(
            postId: postId,
            hasPreview: hasPreview,
            centerDistance: centerDistance,
            overlap: overlap,
            midY: frame.midY
        )
    }

    private var communityBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: post.community.systemImage)
                .font(.caption2.weight(.bold))
            Text(post.community.title)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            if isCommunityActive {
                Text(L10n.Pulse.active.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.accent.opacity(0.22))
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(AppTheme.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.accent.opacity(0.12))
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var mediaView: some View {
        if let imagePath {
            PulseCachedAsyncImage(filePath: imagePath, contentMode: .fit)
                .frame(maxWidth: .infinity)
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        } else if videoURL != nil {
            ZStack {
                Color.black.opacity(0.4)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .aspectRatio(9 / 16, contentMode: .fit)
            .frame(maxWidth: .infinity)
        } else {
            ZStack {
                AppTheme.gradientPrimary.opacity(0.35)
                Image(systemName: post.systemImagePlaceholder ?? "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Campo de texto com sugestões de @menção (pessoas que o usuário segue).
private struct PulseMentionTextField: View {
    @Binding var text: String
    let candidates: [PulsePerson]
    var placeholder: String = "Escreva…"
    var lineLimit: ClosedRange<Int> = 1...4

    private var filtered: [PulsePerson] {
        guard let query = PulseMentionParser.activeQuery(in: text) else { return [] }
        if query.isEmpty { return Array(candidates.prefix(6)) }
        return candidates
            .filter {
                $0.mentionHandle.localizedCaseInsensitiveContains(query)
                    || $0.displayName.localizedCaseInsensitiveContains(query)
            }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !filtered.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filtered) { person in
                            Button {
                                text = PulseMentionParser.applyingMention(person: person, to: text)
                            } label: {
                                Text("@\(person.mentionHandle)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppTheme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.accent.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(lineLimit)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct PulseWorkoutMetaChips: View {
    let meta: PulseWorkoutMeta

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let modality = meta.modality, !modality.isEmpty {
                    metaChip(icon: "figure.strengthtraining.traditional", text: modality)
                }
                if let duration = meta.durationLabel {
                    metaChip(icon: "clock.fill", text: duration)
                }
                if let intensity = meta.intensityLabel {
                    metaChip(icon: "bolt.heart.fill", text: intensity)
                }
                if let duo = meta.duoTeamName, !duo.isEmpty {
                    metaChip(icon: "person.2.fill", text: duo)
                }
            }
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }
}

// MARK: - Compose

struct PulseComposePayload {
    let caption: String
    let photo: UIImage?
    let videoURL: URL?
    let community: PulseCommunity
    let workoutMeta: PulseWorkoutMeta?
    let music: PulseMusicAttachment?
}

struct PulseComposeView: View {
    var existingPost: PulsePost? = nil
    var existingImage: UIImage? = nil
    var onPublish: (PulseComposePayload) -> Void

    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var selectedCommunity: PulseCommunity = .musculacao
    @State private var includeIntensity = false
    @State private var intensity = 6
    @State private var modality = ""
    @State private var durationMinutes = ""
    @State private var duoTeamName = ""
    @State private var selectedPhoto: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var selectedMusic: PulseMusicAttachment?
    @State private var localError: String?
    @State private var showSourceDialog = false
    @State private var showLibraryPhoto = false
    @State private var showLibraryVideo = false
    @State private var showCameraPhoto = false
    @State private var showCameraVideo = false
    @State private var showMusicPicker = false
    @State private var didLoadExisting = false

    private var mentionUserId: String {
        authService.currentUser?.id ?? existingPost?.authorId ?? "local"
    }

    private var mentionCandidates: [PulsePerson] {
        PulseLocalStore.shared.followingPeople(of: mentionUserId)
    }

    private var isEditing: Bool { existingPost != nil }

    private var canPublish: Bool {
        if isEditing { return true }
        return selectedPhoto != nil || selectedVideoURL != nil
    }

    private var availableCommunities: [PulseCommunity] {
        let joined = PulseLocalStore.shared.joinedCommunities
        let thematic = PulseCommunity.thematicCases.filter { joined.contains($0) }
        let modalities = PulseCommunity.cardioModalityCases.filter { joined.contains($0) }
        let available = thematic + modalities
        if available.isEmpty { return PulseCommunity.thematicCases }
        return available
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Pulse.composerMedia) {
                    Button {
                        showSourceDialog = true
                    } label: {
                        Label(
                            selectedPhoto != nil
                                ? "Trocar foto"
                                : (selectedVideoURL != nil ? "Trocar vídeo" : (isEditing ? "Trocar mídia (opcional)" : "Câmera ou galeria")),
                            systemImage: "camera.fill"
                        )
                    }

                    if let selectedPhoto {
                        Image(uiImage: selectedPhoto)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if selectedVideoURL != nil {
                        Label(
                            "Vídeo selecionado (máx. \(Int(PulseExperimental.maxVideoSeconds))s)",
                            systemImage: "video.fill"
                        )
                        .foregroundStyle(AppTheme.accent)
                    } else if isEditing, let existingImage {
                        Image(uiImage: existingImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topLeading) {
                                Text("Atual")
                                    .font(.caption2.weight(.bold))
                                    .padding(6)
                                    .background(.black.opacity(0.5))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                    }
                }

                Section(L10n.Pulse.composerMusicOptional) {
                    Button {
                        showMusicPicker = true
                    } label: {
                        Label(
                            selectedMusic.map { "\($0.providerLabel): \($0.title)" } ?? L10n.Pulse.storyAddMusic,
                            systemImage: "music.note.list"
                        )
                    }
                    if selectedMusic != nil {
                        PulseMusicClipEditor(music: Binding(
                            get: { selectedMusic! },
                            set: { selectedMusic = $0 }
                        ))
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        Button("Remover música", role: .destructive) {
                            selectedMusic = nil
                        }
                    }
                }

                Section(L10n.Pulse.composerCommunity) {
                    Picker(L10n.Pulse.composerCommunity, selection: $selectedCommunity) {
                        ForEach(availableCommunities) { community in
                            Label(community.title, systemImage: community.systemImage)
                                .tag(community)
                        }
                    }
                    Text("Só comunidades ATIVO aparecem aqui. Entre em mais na aba Comunidade.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Section("Detalhes do treino (opcional)") {
                    TextField("Modalidade", text: $modality)
                    TextField("Duração (minutos)", text: $durationMinutes)
                        .keyboardType(.numberPad)
                    TextField("Dupla / equipe", text: $duoTeamName)
                    Toggle("Incluir intensidade", isOn: $includeIntensity)
                    if includeIntensity {
                        Stepper("Intensidade: \(intensity)/10", value: $intensity, in: 1...10)
                    }
                }

                Section("\(L10n.Pulse.composerCaption) (\(caption.count)/\(PulseExperimental.maxCaptionCharacters))") {
                    PulseMentionTextField(
                        text: $caption,
                        candidates: mentionCandidates,
                        placeholder: PulseExperimental.tagline,
                        lineLimit: 3...6
                    )
                    Text("Digite @ para marcar quem você segue.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Section {
                    Button(isEditing ? L10n.Common.save : L10n.Pulse.publish) {
                        onPublish(
                            PulseComposePayload(
                                caption: caption,
                                photo: selectedPhoto,
                                videoURL: selectedVideoURL,
                                community: selectedCommunity,
                                workoutMeta: buildWorkoutMeta(),
                                music: selectedMusic
                            )
                        )
                    }
                    .disabled(!canPublish || caption.count > PulseExperimental.maxCaptionCharacters)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(isEditing ? L10n.Pulse.composerEditPost : L10n.Pulse.composerNewPost)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
            }
            .onAppear {
                guard !didLoadExisting, let existingPost else { return }
                didLoadExisting = true
                caption = existingPost.caption
                selectedCommunity = existingPost.community
                selectedMusic = existingPost.music
                if let meta = existingPost.workoutMeta {
                    modality = meta.modality ?? ""
                    duoTeamName = meta.duoTeamName ?? ""
                    if let duration = meta.durationSeconds, duration > 0 {
                        durationMinutes = String(max(1, duration / 60))
                    }
                    if let value = meta.intensity {
                        includeIntensity = true
                        intensity = value
                    }
                }
                if !availableCommunities.contains(selectedCommunity),
                   let first = availableCommunities.first {
                    selectedCommunity = first
                }
            }
            .confirmationDialog("Adicionar mídia", isPresented: $showSourceDialog, titleVisibility: .visible) {
                if PhotoCaptureAvailability.isCameraAvailable {
                    Button("Câmera · foto") { showCameraPhoto = true }
                }
                if PhotoCaptureAvailability.isVideoCameraAvailable, PulseExperimental.isVideoPostsEnabledInBuild {
                    Button("Câmera · vídeo") { showCameraVideo = true }
                }
                Button("Galeria · foto") { showLibraryPhoto = true }
                if PulseExperimental.isVideoPostsEnabledInBuild {
                    Button("Galeria · vídeo") { showLibraryVideo = true }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            }
            .sheet(isPresented: $showLibraryPhoto) {
                LibraryImagePicker { image in
                    showLibraryPhoto = false
                    guard let image else { return }
                    selectedVideoURL = nil
                    selectedPhoto = image
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showLibraryVideo) {
                LibraryVideoPicker { url in
                    showLibraryVideo = false
                    guard let url else { return }
                    selectedPhoto = nil
                    selectedVideoURL = url
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCameraPhoto) {
                CameraImagePicker { image in
                    showCameraPhoto = false
                    guard let image else { return }
                    selectedVideoURL = nil
                    selectedPhoto = image
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCameraVideo) {
                CameraVideoPicker { url in
                    showCameraVideo = false
                    guard let url else { return }
                    selectedPhoto = nil
                    selectedVideoURL = url
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showMusicPicker) {
                PulseMusicPickerView(selectedTrack: $selectedMusic)
            }
            .alert(L10n.Pulse.featureName, isPresented: Binding(
                get: { localError != nil },
                set: { if !$0 { localError = nil } }
            )) {
                Button(L10n.Common.ok, role: .cancel) { localError = nil }
            } message: {
                Text(localError ?? "")
            }
        }
    }

    private func buildWorkoutMeta() -> PulseWorkoutMeta? {
        let modalityTrim = modality.trimmingCharacters(in: .whitespacesAndNewlines)
        let duoTrim = duoTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationSeconds = Int(durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines)).map { max(0, $0) * 60 }
        let hasMeta = !modalityTrim.isEmpty || durationSeconds != nil || includeIntensity || !duoTrim.isEmpty
        guard hasMeta else { return nil }
        return PulseWorkoutMeta(
            modality: modalityTrim.isEmpty ? nil : modalityTrim,
            durationSeconds: durationSeconds,
            intensity: includeIntensity ? intensity : nil,
            duoTeamName: duoTrim.isEmpty ? nil : duoTrim
        )
    }
}

