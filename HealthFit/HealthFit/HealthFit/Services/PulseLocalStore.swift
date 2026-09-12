import Foundation
import UIKit
import AVFoundation
import Combine
import UserNotifications
import FirebaseAuth

@MainActor
final class PulseLocalStore: ObservableObject {
    static let shared = PulseLocalStore()

    @Published private(set) var posts: [PulsePost] = []
    @Published private(set) var stories: [PulseStory] = []
    @Published private(set) var people: [PulsePerson] = []
    @Published private(set) var follows: [PulseFollowRelation] = []
    @Published private(set) var notifications: [PulseSocialNotification] = []
    @Published private(set) var chatMessages: [PulseChatMessage] = []
    @Published private(set) var blockedUserIds: Set<String> = []
    @Published private(set) var joinedCommunities: Set<PulseCommunity> = [.musculacao, .cardio]
    @Published private(set) var joinedCardioModalities: Set<String> = []
    @Published var selectedCommunity: PulseCommunity? = nil

    private let postsKey = "pulse.experimental.posts.v2"
    private let storiesKey = "pulse.experimental.stories.v1"
    private let peopleKey = "pulse.experimental.people.v1"
    private let followsKey = "pulse.experimental.follows.v1"
    private let notificationsKey = "pulse.experimental.notifications.v1"
    private let chatKey = "pulse.experimental.chat.v1"
    private let blockedKey = "pulse.experimental.blocked.v1"
    private let communitiesKey = "pulse.experimental.joinedCommunities.v1"
    private let cardioModalitiesKey = "pulse.experimental.joinedCardioModalities.v1"
    private let mediaFolderName = "PulseExperimentalMedia"
    private let diskStoreFolderName = "PulseLocalStore"
    /// Página inicial do feed (LazyVStack + load more).
    static let feedPageSize = 12
    @Published private(set) var feedDisplayLimit = PulseLocalStore.feedPageSize
    @Published private(set) var isRefreshingCloud = false

    private init() {
        load()
        pruneExpiredContent()
        stripDemoContentUnlessEnabled()
        // Sem seed automático: demos só via Labs → "Carregar dados demo".
    }

    var diskStoreDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(diskStoreFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func diskFileURL(_ name: String) -> URL {
        diskStoreDirectory.appendingPathComponent(name)
    }

    func resetFeedPagination() {
        feedDisplayLimit = Self.feedPageSize
    }

    func loadMoreFeedIfNeeded(currentIndex: Int) {
        let visibleCount = visiblePosts.count
        guard currentIndex >= feedDisplayLimit - 3 else { return }
        guard feedDisplayLimit < visibleCount else { return }
        feedDisplayLimit = min(feedDisplayLimit + Self.feedPageSize, visibleCount)
    }

    var pagedVisiblePosts: [PulsePost] {
        Array(visiblePosts.prefix(feedDisplayLimit))
    }

    var activeStories: [PulseStory] {
        stories.filter(\.isActive).sorted { $0.createdAt > $1.createdAt }
    }

    var visiblePosts: [PulsePost] {
        posts
            .filter(\.isActive)
            .filter { !$0.isHidden }
            .filter { !blockedUserIds.contains($0.authorId) }
            .filter { post in
                guard let selectedCommunity else { return joinedCommunities.contains(post.community) }
                if selectedCommunity == .cardio {
                    return post.community == .cardio || post.community.isCardioModality
                }
                return post.community == selectedCommunity
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var weeklyHighlight: PulsePost? {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date().addingTimeInterval(-604_800)
        return visiblePosts
            .filter { $0.createdAt >= weekAgo }
            .max(by: { $0.engagementScore < $1.engagementScore })
    }

    var lightRanking: [(name: String, score: Int)] {
        var scores: [String: Int] = [:]
        for post in visiblePosts.prefix(40) {
            scores[post.authorName, default: 0] += post.engagementScore
        }
        return scores
            .map { (name: $0.key, score: $0.value) }
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { $0 }
    }

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var mediaDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(mediaFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func mediaURL(for fileName: String) -> URL {
        mediaDirectory.appendingPathComponent(fileName)
    }

    func mediaPath(for post: PulsePost) -> String? {
        if let name = post.mediaFileName {
            let path = mediaURL(for: name).path
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        if post.remoteMediaURL != nil,
           let cachedName = cachedRemoteFileName(for: post.id) {
            return mediaURL(for: cachedName).path
        }
        return nil
    }

    /// Prefer `mediaPath` + PulseCachedAsyncImage no feed. Sync só para sheets/legacy.
    func loadImage(for post: PulsePost) -> UIImage? {
        guard let path = mediaPath(for: post) else { return nil }
        return UIImage(contentsOfFile: path)
    }

    func storyMediaPath(_ story: PulseStory) -> String? {
        if let name = story.mediaFileName {
            let path = mediaURL(for: name).path
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    private func cachedRemoteFileName(for postId: UUID) -> String? {
        let name = "remote-\(postId.uuidString).jpg"
        return FileManager.default.fileExists(atPath: mediaURL(for: name).path) ? name : nil
    }

    func cacheRemoteImageIfNeeded(for post: PulsePost) async {
        guard let urlString = post.remoteMediaURL,
              let url = URL(string: urlString),
              cachedRemoteFileName(for: post.id) == nil else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let name = "remote-\(post.id.uuidString).jpg"
            try data.write(to: mediaURL(for: name), options: .atomic)
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].mediaFileName = name
                persistPosts()
            }
        } catch {
            // Offline / URL expirada — feed ainda mostra placeholder.
        }
    }

    func loadStoryImage(_ story: PulseStory) -> UIImage? {
        guard let name = story.mediaFileName else { return nil }
        return UIImage(contentsOfFile: mediaURL(for: name).path)
    }

    func loadReactionAvatar(_ reaction: PulseReactionEvent) -> UIImage? {
        if let name = reaction.avatarFileName {
            return UIImage(contentsOfFile: mediaURL(for: name).path)
        }
        return loadUserAvatar(userId: reaction.userId)
    }

    func loadUserAvatar(userId: String) -> UIImage? {
        let name = avatarFileName(for: userId)
        if let disk = UIImage(contentsOfFile: mediaURL(for: name).path) {
            return disk
        }
        if let person = people.first(where: { $0.id == userId }) {
            return Self.placeholderAvatar(name: person.displayName, seed: userId)
        }
        return nil
    }

    /// Gera avatar visual estável para demos sem foto real.
    private static func placeholderAvatar(name: String, seed: String, size: CGFloat = 96) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let hash = seed.utf8.reduce(UInt64(5381)) { ($0 << 5) &+ $0 &+ UInt64($1) }
            let hue = CGFloat(hash % 360) / 360.0
            UIColor(hue: hue, saturation: 0.45, brightness: 0.55, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            let initial = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.42, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = (initial as NSString).size(withAttributes: attrs)
            let point = CGPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2)
            (initial as NSString).draw(at: point, withAttributes: attrs)
        }
    }

    func ensureUserAvatar(userId: String, image: UIImage?) {
        guard let image, let data = image.jpegData(compressionQuality: 0.75) else { return }
        let name = avatarFileName(for: userId)
        try? data.write(to: mediaURL(for: name), options: .atomic)
    }

    private func avatarFileName(for userId: String) -> String {
        "avatar-\(userId.replacingOccurrences(of: "/", with: "_")).jpg"
    }

    private func existingAvatarFileName(for userId: String) -> String? {
        let name = avatarFileName(for: userId)
        return FileManager.default.fileExists(atPath: mediaURL(for: name).path) ? name : nil
    }

    // MARK: - Posts

    @discardableResult
    func addPhotoPost(
        authorId: String,
        authorName: String,
        authorCountryCode: String,
        caption: String,
        image: UIImage,
        community: PulseCommunity,
        workoutMeta: PulseWorkoutMeta?,
        music: PulseMusicAttachment? = nil,
        authorAvatar: UIImage? = nil
    ) throws -> PulsePost {
        ensureUserAvatar(userId: authorId, image: authorAvatar)
        let fileName = "\(UUID().uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: 0.85) else { throw PulseStoreError.encodeFailed }
        try data.write(to: mediaURL(for: fileName), options: .atomic)
        return insertPost(
            PulsePost(
                authorId: authorId,
                authorName: authorName,
                authorCountryCode: authorCountryCode,
                caption: String(caption.prefix(PulseExperimental.maxCaptionCharacters)),
                mediaKind: .photo,
                mediaFileName: fileName,
                community: community,
                workoutMeta: workoutMeta,
                music: music
            )
        )
    }

    @discardableResult
    func addVideoPost(
        authorId: String,
        authorName: String,
        authorCountryCode: String,
        caption: String,
        sourceURL: URL,
        community: PulseCommunity,
        workoutMeta: PulseWorkoutMeta?,
        music: PulseMusicAttachment? = nil,
        authorAvatar: UIImage? = nil
    ) async throws -> PulsePost {
        guard PulseExperimental.isVideoPostsEnabledInBuild else {
            throw PulseStoreError.videoDisabled
        }
        ensureUserAvatar(userId: authorId, image: authorAvatar)
        let duration = try await videoDuration(url: sourceURL)
        guard duration <= PulseExperimental.maxVideoSeconds + 0.5 else { throw PulseStoreError.videoTooLong }
        let fileName = "\(UUID().uuidString).mov"
        let dest = mediaURL(for: fileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return insertPost(
            PulsePost(
                authorId: authorId,
                authorName: authorName,
                authorCountryCode: authorCountryCode,
                caption: String(caption.prefix(PulseExperimental.maxCaptionCharacters)),
                mediaKind: .video,
                mediaFileName: fileName,
                community: community,
                workoutMeta: workoutMeta,
                music: music
            )
        )
    }

    func publishWorkoutCard(
        authorId: String,
        authorName: String,
        authorCountryCode: String,
        card: LastWorkoutShareCard,
        preview: UIImage?,
        community: PulseCommunity,
        intensity: Int?,
        caption: String?
    ) throws {
        var fileName: String?
        if let preview, let data = preview.jpegData(compressionQuality: 0.85) {
            let name = "workout-\(UUID().uuidString).jpg"
            try data.write(to: mediaURL(for: name), options: .atomic)
            fileName = name
        }
        let duration = Int(card.endedAt.timeIntervalSince(card.startedAt))
        let meta = PulseWorkoutMeta(
            modality: card.workoutTitle,
            durationSeconds: max(0, duration),
            intensity: intensity.map { min(max($0, 1), 10) },
            duoTeamName: card.duoTeamName
        )
        let defaultCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? L10n.Pulse.captionWorkoutDefault(card.workoutTitle, PulseExperimental.tagline)
        insertPost(
            PulsePost(
                authorId: authorId,
                authorName: authorName,
                authorCountryCode: authorCountryCode,
                caption: String(defaultCaption.prefix(PulseExperimental.maxCaptionCharacters)),
                mediaKind: .workoutCard,
                mediaFileName: fileName,
                systemImagePlaceholder: "figure.strengthtraining.traditional",
                community: community,
                workoutMeta: meta
            )
        )
    }

    func addComment(
        to postId: UUID,
        authorId: String,
        authorName: String,
        text: String,
        avatar: UIImage? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        ensureUserAvatar(userId: authorId, image: avatar)
        posts[idx].comments.append(
            PulseComment(authorId: authorId, authorName: authorName, text: String(trimmed.prefix(280)))
        )
        persistPosts()
        notifyMentions(
            in: trimmed,
            fromUserId: authorId,
            fromName: authorName,
            context: "comentário"
        )
        if let comment = posts[idx].comments.last {
            Task { _ = await PulseFirestoreService.addComment(postId: postId, comment: comment) }
        }
    }

    func toggleHeart(
        postId: UUID,
        userId: String,
        userName: String,
        avatar: UIImage? = nil
    ) {
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        ensureUserAvatar(userId: userId, image: avatar)
        let hearted: Bool
        if let existing = posts[idx].reactions.firstIndex(where: { $0.userId == userId && $0.isHeart }) {
            posts[idx].reactions.remove(at: existing)
            hearted = false
        } else {
            posts[idx].reactions.append(
                PulseReactionEvent(
                    userId: userId,
                    userName: userName,
                    kind: "heart",
                    avatarFileName: existingAvatarFileName(for: userId)
                )
            )
            hearted = true
        }
        persistPosts()
        Task {
            if hearted {
                await PulseFirestoreService.setReaction(postId: postId, userId: userId, emoji: "❤️")
            } else {
                await PulseFirestoreService.clearReaction(postId: postId, userId: userId)
            }
        }
    }

    func addQuickReaction(
        postId: UUID,
        reaction: PulseQuickReaction,
        userId: String,
        userName: String,
        avatar: UIImage? = nil
    ) {
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        ensureUserAvatar(userId: userId, image: avatar)
        posts[idx].reactions.removeAll { $0.userId == userId && $0.kind == reaction.rawValue }
        posts[idx].reactions.append(
            PulseReactionEvent(
                userId: userId,
                userName: userName,
                kind: reaction.rawValue,
                avatarFileName: existingAvatarFileName(for: userId)
            )
        )
        persistPosts()
    }

    func updatePost(
        postId: UUID,
        by userId: String,
        caption: String,
        community: PulseCommunity,
        workoutMeta: PulseWorkoutMeta?,
        music: PulseMusicAttachment?,
        newImage: UIImage? = nil,
        newVideoURL: URL? = nil
    ) async throws {
        guard let idx = posts.firstIndex(where: { $0.id == postId && $0.authorId == userId }) else {
            throw PulseStoreError.encodeFailed
        }
        posts[idx].caption = String(caption.prefix(PulseExperimental.maxCaptionCharacters))
        posts[idx].community = community
        posts[idx].workoutMeta = workoutMeta
        posts[idx].music = music
        ensureCommunityJoined(community)

        if let newImage {
            let fileName = "\(UUID().uuidString).jpg"
            guard let data = newImage.jpegData(compressionQuality: 0.85) else { throw PulseStoreError.encodeFailed }
            try data.write(to: mediaURL(for: fileName), options: .atomic)
            if let old = posts[idx].mediaFileName {
                try? FileManager.default.removeItem(at: mediaURL(for: old))
            }
            posts[idx].mediaKind = .photo
            posts[idx].mediaFileName = fileName
            posts[idx].systemImagePlaceholder = nil
        } else if let newVideoURL {
            let duration = try await videoDuration(url: newVideoURL)
            guard duration <= PulseExperimental.maxVideoSeconds + 0.5 else { throw PulseStoreError.videoTooLong }
            let fileName = "\(UUID().uuidString).mov"
            let dest = mediaURL(for: fileName)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: newVideoURL, to: dest)
            if let old = posts[idx].mediaFileName {
                try? FileManager.default.removeItem(at: mediaURL(for: old))
            }
            posts[idx].mediaKind = .video
            posts[idx].mediaFileName = fileName
            posts[idx].systemImagePlaceholder = nil
        }

        persistPosts()
        notifyMentions(
            in: posts[idx].caption,
            fromUserId: userId,
            fromName: posts[idx].authorName,
            context: "post"
        )
    }

    func deletePost(_ postId: UUID, by userId: String) {
        guard let idx = posts.firstIndex(where: { $0.id == postId && $0.authorId == userId }) else { return }
        if let file = posts[idx].mediaFileName {
            try? FileManager.default.removeItem(at: mediaURL(for: file))
        }
        posts.remove(at: idx)
        persistPosts()
        Task { await PulseFirestoreService.deletePost(id: postId) }
    }

    func hidePost(_ postId: UUID) {
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[idx].isHidden = true
        persistPosts()
    }

    func reportPost(_ postId: UUID, reporterId: String = "local") {
        guard let idx = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[idx].reportCount += 1
        if posts[idx].reportCount >= 3 {
            posts[idx].isHidden = true
        }
        pushNotification(
            title: L10n.Pulse.notifyReportTitle,
            body: L10n.Pulse.notifyReportBody
        )
        persistPosts()
        Task {
            await PulseFirestoreService.reportPost(postId: postId, reporterId: reporterId)
        }
    }

    func blockUser(_ userId: String) {
        blockedUserIds.insert(userId)
        persistBlocked()
        follows.removeAll { $0.fromUserId == userId || $0.toUserId == userId }
        persistFollows()
        Task { await PulseFirestoreService.blockCurrentUserTarget(userId) }
    }

    // MARK: - Stories

    func addStory(
        authorId: String,
        authorName: String,
        image: UIImage,
        music: PulseMusicAttachment? = nil,
        textOverlays: [PulseStoryTextOverlay] = []
    ) throws {
        let fileName = "story-\(UUID().uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: 0.82) else { throw PulseStoreError.encodeFailed }
        try data.write(to: mediaURL(for: fileName), options: .atomic)
        stories.insert(
            PulseStory(
                authorId: authorId,
                authorName: authorName,
                mediaFileName: fileName,
                music: music,
                textOverlays: textOverlays.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            ),
            at: 0
        )
        persistStories()
        let story = stories[0]
        let jpeg = try? Data(contentsOf: mediaURL(for: fileName))
        Task {
            let remote = await PulseFirestoreService.upsertStory(story, imageJPEG: jpeg)
            if let remote, let idx = stories.firstIndex(where: { $0.id == story.id }) {
                stories[idx].remoteMediaURL = remote
                persistStories()
            }
        }
    }

    func markStoryViewed(_ storyId: UUID) {
        guard let idx = stories.firstIndex(where: { $0.id == storyId }) else { return }
        stories[idx].isViewed = true
        persistStories()
    }

    func toggleStoryHeart(
        storyId: UUID,
        userId: String,
        userName: String,
        avatar: UIImage? = nil
    ) {
        guard let idx = stories.firstIndex(where: { $0.id == storyId }) else { return }
        ensureUserAvatar(userId: userId, image: avatar)
        if let existing = stories[idx].reactions.firstIndex(where: { $0.userId == userId && $0.isHeart }) {
            stories[idx].reactions.remove(at: existing)
        } else {
            stories[idx].reactions.removeAll { $0.userId == userId && !$0.isHeart }
            stories[idx].reactions.append(
                PulseReactionEvent(
                    userId: userId,
                    userName: userName,
                    kind: "heart",
                    avatarFileName: existingAvatarFileName(for: userId)
                )
            )
        }
        persistStories()
    }

    func deleteStory(_ storyId: UUID, by userId: String) {
        guard let idx = stories.firstIndex(where: { $0.id == storyId && $0.authorId == userId }) else { return }
        if let file = stories[idx].mediaFileName {
            try? FileManager.default.removeItem(at: mediaURL(for: file))
        }
        stories.remove(at: idx)
        persistStories()
    }

    @discardableResult
    func pruneExpiredContent() -> Bool {
        let activeStories = stories.filter(\.isActive)
        let activePosts = posts.filter(\.isActive)
        let changed = activeStories.count != stories.count || activePosts.count != posts.count
        guard changed else { return false }
        let removedPostMedia = posts.filter { !$0.isActive }.compactMap(\.mediaFileName)
        let removedStoryMedia = stories.filter { !$0.isActive }.compactMap(\.mediaFileName)
        for name in removedPostMedia + removedStoryMedia {
            try? FileManager.default.removeItem(at: mediaURL(for: name))
        }
        stories = activeStories
        posts = activePosts
        persistStories()
        persistPosts()
        return true
    }

    @discardableResult
    func pruneExpiredStories() -> Bool {
        pruneExpiredContent()
    }

    // MARK: - Communities / people / follow

    func toggleCommunity(_ community: PulseCommunity) {
        var updated = joinedCommunities
        if updated.contains(community) {
            updated.remove(community)
        } else {
            updated.insert(community)
        }
        if updated.isEmpty {
            updated.insert(.musculacao)
        }
        joinedCommunities = updated
        mirrorCardioModalities(from: updated)
        persistCommunities()
    }

    /// Garante que a comunidade do post fique ATIVO (aparece nos chips do Feed).
    func ensureCommunityJoined(_ community: PulseCommunity) {
        guard !joinedCommunities.contains(community) else { return }
        var updated = joinedCommunities
        updated.insert(community)
        joinedCommunities = updated
        mirrorCardioModalities(from: updated)
        persistCommunities()
    }

    func toggleCardioModality(_ name: String) {
        toggleCommunity(.cardioModality(name))
        if joinedCommunities.contains(.cardioModality(name)) {
            ensureCommunityJoined(.cardio)
        }
    }

    func isCommunityActive(_ community: PulseCommunity) -> Bool {
        joinedCommunities.contains(community)
    }

    /// Modalidades de cardio ATIVO (como comunidades).
    var activeCardioModalityCommunities: [PulseCommunity] {
        PulseCommunity.cardioModalityCases.filter { joinedCommunities.contains($0) }
    }

    private func mirrorCardioModalities(from communities: Set<PulseCommunity>) {
        let names = Set(communities.compactMap { community -> String? in
            if case .cardioModality(let name) = community { return name }
            return nil
        })
        if names != joinedCardioModalities {
            joinedCardioModalities = names
            persistCardioModalities()
        }
    }

    func person(id: String) -> PulsePerson? {
        people.first { $0.id == id }
    }

    /// Cria/atualiza o perfil Pulse do usuário local (bio ≤ 100 chars).
    func upsertMyProfile(
        userId: String,
        displayName: String,
        emailHint: String,
        countryCode: String,
        state: String = "",
        city: String = "",
        bio: String? = nil,
        communityFocus: PulseCommunity? = nil
    ) {
        let trimmedBio = String((bio ?? person(id: userId)?.bio ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(PulseExperimental.maxBioCharacters))
        let focus = communityFocus
            ?? person(id: userId)?.communityFocus
            ?? joinedCommunities.first
            ?? .musculacao
        let existing = person(id: userId)
        let updated = PulsePerson(
            id: userId,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? L10n.Pulse.athlete
                : displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            emailHint: emailHint,
            countryCode: countryCode.isEmpty ? (existing?.countryCode ?? "BR") : countryCode,
            state: state.isEmpty ? (existing?.state ?? "") : state,
            city: city.isEmpty ? (existing?.city ?? "") : city,
            bio: trimmedBio,
            communityFocus: focus,
            notifyOnPosts: existing?.notifyOnPosts ?? true
        )
        if let idx = people.firstIndex(where: { $0.id == userId }) {
            people[idx] = updated
        } else {
            people.append(updated)
        }
        persistPeople()
    }

    func updateMyBio(userId: String, bio: String) {
        guard let existing = person(id: userId) else { return }
        upsertMyProfile(
            userId: userId,
            displayName: existing.displayName,
            emailHint: existing.emailHint,
            countryCode: existing.countryCode,
            state: existing.state,
            city: existing.city,
            bio: bio,
            communityFocus: existing.communityFocus
        )
    }

    /// Pessoas que o usuário segue (aprovado).
    func followingPeople(of userId: String) -> [PulsePerson] {
        let followingIds = Set(
            follows
                .filter { $0.fromUserId == userId && $0.status == .following }
                .map(\.toUserId)
        )
        return people
            .filter { followingIds.contains($0.id) && !blockedUserIds.contains($0.id) }
            .sorted { $0.displayName < $1.displayName }
    }

    /// Pessoas que seguem o usuário atual (pedido já aprovado).
    func followers(of userId: String) -> [PulsePerson] {
        let followerIds = Set(
            follows
                .filter { $0.toUserId == userId && $0.status == .following }
                .map(\.fromUserId)
        )
        return people.filter { followerIds.contains($0.id) && !blockedUserIds.contains($0.id) }
    }

    func messages(with otherUserId: String, currentUserId: String) -> [PulseChatMessage] {
        let thread = PulseChatThread.id(between: currentUserId, and: otherUserId)
        return chatMessages
            .filter { $0.threadId == thread }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func sendChatMessage(
        from senderId: String,
        senderName: String,
        to recipientId: String,
        text: String,
        community: PulseCommunity = .cardio
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let canChat = followStatus(from: recipientId, to: senderId) == .following
        guard canChat else {
            pushNotification(
                title: "Chat indisponível",
                body: "Só é possível conversar com quem te segue na comunidade."
            )
            return
        }
        let thread = PulseChatThread.id(between: senderId, and: recipientId)
        chatMessages.append(
            PulseChatMessage(
                threadId: thread,
                senderId: senderId,
                senderName: senderName,
                text: String(trimmed.prefix(500)),
                community: community
            )
        )
        persistChat()
        pushNotification(
            title: "Pulse · Nova mensagem",
            body: "\(senderName): \(String(trimmed.prefix(80)))",
            scheduleSystemBanner: true
        )
    }

    func searchPeople(
        query: String,
        countryCode: String?,
        state: String?,
        city: String?,
        preferCountryCode: String? = nil,
        preferState: String? = nil,
        preferCity: String? = nil
    ) -> [PulsePerson] {
        let filterCountry = countryCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let filterState = state?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let filterCity = city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let boostCountry = (preferCountryCode ?? filterCountry).trimmingCharacters(in: .whitespacesAndNewlines)
        let boostState = (preferState ?? filterState).trimmingCharacters(in: .whitespacesAndNewlines)
        let boostCity = (preferCity ?? filterCity).trimmingCharacters(in: .whitespacesAndNewlines)

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return people
            .filter { person in
                if blockedUserIds.contains(person.id) { return false }
                guard !q.isEmpty else { return true }
                return person.displayName.localizedCaseInsensitiveContains(q)
                    || person.city.localizedCaseInsensitiveContains(q)
                    || person.state.localizedCaseInsensitiveContains(q)
                    || person.countryName.localizedCaseInsensitiveContains(q)
                    || person.regionLabel.localizedCaseInsensitiveContains(q)
            }
            .sorted { lhs, rhs in
                let left = peopleLocalityScore(
                    person: lhs,
                    preferCountry: boostCountry,
                    preferState: boostState,
                    preferCity: boostCity
                )
                let right = peopleLocalityScore(
                    person: rhs,
                    preferCountry: boostCountry,
                    preferState: boostState,
                    preferCity: boostCity
                )
                if left != right { return left > right }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    /// 4 = país+estado+cidade, 3 = país+estado/cidade, 2 = mesmo país, 1 = sem país, 0 = outro país.
    private func peopleLocalityScore(
        person: PulsePerson,
        preferCountry: String,
        preferState: String,
        preferCity: String
    ) -> Int {
        let sameCountry = !preferCountry.isEmpty
            && person.countryCode.caseInsensitiveCompare(preferCountry) == .orderedSame
        let sameState = !preferState.isEmpty
            && person.state.localizedCaseInsensitiveContains(preferState)
        let sameCity = !preferCity.isEmpty
            && person.city.localizedCaseInsensitiveContains(preferCity)

        if sameCountry && sameState && sameCity { return 4 }
        if sameCountry && (sameState || sameCity) { return 3 }
        if sameCountry { return 2 }
        if preferCountry.isEmpty { return 0 }
        if person.countryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return 1 }
        return 0
    }

    func followStatus(from userId: String, to targetId: String) -> PulseFollowStatus {
        if let rel = follows.first(where: { $0.fromUserId == userId && $0.toUserId == targetId }) {
            return rel.status
        }
        if follows.contains(where: { $0.fromUserId == targetId && $0.toUserId == userId && $0.status == .requested }) {
            return .incoming
        }
        return .none
    }

    func requestFollow(from userId: String, to targetId: String, notifyPosts: Bool) {
        guard userId != targetId else { return }
        if let idx = follows.firstIndex(where: { $0.fromUserId == userId && $0.toUserId == targetId }) {
            follows[idx].status = .requested
            follows[idx].notifyPosts = notifyPosts
        } else {
            follows.append(
                PulseFollowRelation(fromUserId: userId, toUserId: targetId, status: .requested, notifyPosts: notifyPosts)
            )
        }
        let name = people.first(where: { $0.id == userId })?.displayName ?? L10n.Pulse.someone
        pushNotification(
            title: L10n.Pulse.notifyFollowRequestTitle,
            body: L10n.Pulse.notifyFollowRequestBody(name)
        )
        persistFollows()
        Task {
            await PulseFirestoreService.upsertFollow(from: userId, to: targetId, status: .requested)
        }
    }

    func acceptFollow(from requesterId: String, to userId: String) {
        guard let idx = follows.firstIndex(where: {
            $0.fromUserId == requesterId && $0.toUserId == userId && $0.status == .requested
        }) else { return }
        follows[idx].status = .following
        persistFollows()
        if follows[idx].notifyPosts {
            pushNotification(
                title: L10n.Pulse.notifyFollowingTitle,
                body: L10n.Pulse.notifyFollowingBody
            )
        }
        Task {
            await PulseFirestoreService.upsertFollow(from: requesterId, to: userId, status: .following)
        }
    }

    func declineFollow(from requesterId: String, to userId: String) {
        follows.removeAll { $0.fromUserId == requesterId && $0.toUserId == userId && $0.status == .requested }
        persistFollows()
    }

    func cancelFollowRequest(from userId: String, to targetId: String) {
        follows.removeAll { $0.fromUserId == userId && $0.toUserId == targetId }
        persistFollows()
    }

    func incomingFollowRequests(for userId: String) -> [PulseFollowRelation] {
        follows.filter { $0.toUserId == userId && $0.status == .requested }
    }

    func markNotificationsRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        persistNotifications()
    }

    func resetLocalData() {
        clearAllLocalPulseData(reloadDemoIfEnabled: true)
    }

    /// Limpa todo o estado local do Pulse (exclusão de conta / logout completo).
    func clearAllLocalPulseData(reloadDemoIfEnabled: Bool = false) {
        posts = []
        stories = []
        follows = []
        notifications = []
        chatMessages = []
        blockedUserIds = []
        people = []
        joinedCommunities = [.musculacao, .cardio]
        joinedCardioModalities = []
        selectedCommunity = nil
        feedDisplayLimit = Self.feedPageSize

        if let files = try? FileManager.default.contentsOfDirectory(at: mediaDirectory, includingPropertiesForKeys: nil) {
            for file in files { try? FileManager.default.removeItem(at: file) }
        }
        if let diskFiles = try? FileManager.default.contentsOfDirectory(at: diskStoreDirectory, includingPropertiesForKeys: nil) {
            for file in diskFiles { try? FileManager.default.removeItem(at: file) }
        }

        [postsKey, storiesKey, followsKey, notificationsKey, chatKey, blockedKey, communitiesKey, cardioModalitiesKey, peopleKey].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        persistCommunities()
        persistCardioModalities()

        if reloadDemoIfEnabled, PulseExperimental.includeDemoContent {
            loadDemoContent()
        }
    }

    /// Carrega posts/stories/pessoas demo (somente Labs).
    func loadDemoContent() {
        PulseExperimental.includeDemoContent = true
        seedDemoPosts()
        seedDemoStories()
        seedPeople()
        persistPosts()
        persistStories()
        persistPeople()
    }

    func clearDemoContent() {
        PulseExperimental.includeDemoContent = false
        stripDemoContentUnlessEnabled(force: true)
    }

    /// Sync mínimo com Firestore (alias de `refreshFromCloud`).
    func syncFromCloud() async {
        let uid = Auth.auth().currentUser?.uid ?? "local"
        await refreshFromCloud(currentUserId: uid)
    }

    /// Garante seguidores demo para testar o chat da comunidade.
    func ensureCommunityChatDemoFollowers(for userId: String, force: Bool = false) {
        guard PulseExperimental.isChatEnabledInBuild else { return }
        guard PulseExperimental.includeDemoContent else { return }
        guard !userId.isEmpty else { return }
        let key = "pulse.experimental.demoFollowersSeeded.\(userId)"
        if !force, UserDefaults.standard.bool(forKey: key) { return }
        let demoFollowerIds = ["demo-runner", "demo-coach", "demo-es"]
        for followerId in demoFollowerIds {
            if let idx = follows.firstIndex(where: { $0.fromUserId == followerId && $0.toUserId == userId }) {
                follows[idx].status = .following
            } else {
                follows.append(
                    PulseFollowRelation(
                        fromUserId: followerId,
                        toUserId: userId,
                        status: .following,
                        notifyPosts: true
                    )
                )
            }
        }
        UserDefaults.standard.set(true, forKey: key)
        persistFollows()
    }

    /// Garante que o usuário atual segue demos para poder @marcar no Pulse.
    func ensureFollowingDemoPeople(for userId: String, force: Bool = false) {
        guard PulseExperimental.includeDemoContent else { return }
        guard !userId.isEmpty else { return }
        let key = "pulse.experimental.demoFollowingSeeded.\(userId)"
        if !force, UserDefaults.standard.bool(forKey: key) { return }
        let targets = ["demo-coach", "demo-runner", "demo-kite", "demo-nutri", "demo-es"]
        for targetId in targets where targetId != userId {
            if let idx = follows.firstIndex(where: { $0.fromUserId == userId && $0.toUserId == targetId }) {
                follows[idx].status = .following
            } else {
                follows.append(
                    PulseFollowRelation(
                        fromUserId: userId,
                        toUserId: targetId,
                        status: .following,
                        notifyPosts: true
                    )
                )
            }
        }
        UserDefaults.standard.set(true, forKey: key)
        persistFollows()
    }

    func requestPulseNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Pull-based sync (sem listeners). Mescla nuvem no store local respeitando expiresAt.
    func refreshFromCloud(currentUserId: String) async {
        guard PulseExperimental.isCloudSyncEffective else { return }
        guard !isRefreshingCloud else { return }
        isRefreshingCloud = true
        defer { isRefreshingCloud = false }

        async let remotePosts = PulseFirestoreService.fetchActivePosts(limit: 40)
        async let remoteStories = PulseFirestoreService.fetchActiveStories(limit: 40)
        async let remotePeople = PulseFirestoreService.fetchProfiles(limit: 80)
        async let remoteFollows = PulseFirestoreService.fetchFollows(for: currentUserId)
        async let remoteBlocks = PulseFirestoreService.fetchBlocks()

        let cloudPosts = await remotePosts
        let cloudStories = await remoteStories
        let cloudPeople = await remotePeople
        let cloudFollows = await remoteFollows
        let cloudBlocks = await remoteBlocks

        if !cloudPosts.isEmpty {
            var byId = Dictionary(uniqueKeysWithValues: posts.map { ($0.id, $0) })
            for remote in cloudPosts {
                if var local = byId[remote.id] {
                    local.remoteMediaURL = remote.remoteMediaURL ?? local.remoteMediaURL
                    local.isHidden = remote.isHidden
                    local.caption = remote.caption
                    local.expiresAt = remote.expiresAt
                    byId[remote.id] = local
                } else {
                    byId[remote.id] = remote
                }
            }
            posts = Array(byId.values).sorted { $0.createdAt > $1.createdAt }
            persistPosts()
            for post in cloudPosts.prefix(20) {
                await cacheRemoteImageIfNeeded(for: post)
            }
        }

        if !cloudStories.isEmpty {
            var byId = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })
            for remote in cloudStories {
                byId[remote.id] = remote
            }
            stories = Array(byId.values).sorted { $0.createdAt > $1.createdAt }
            persistStories()
        }

        if !cloudPeople.isEmpty {
            var byId = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
            for person in cloudPeople { byId[person.id] = person }
            people = Array(byId.values).sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            persistPeople()
        }

        if !cloudFollows.isEmpty {
            var keys = Set(follows.map { "\($0.fromUserId)_\($0.toUserId)" })
            for rel in cloudFollows {
                let key = "\(rel.fromUserId)_\(rel.toUserId)"
                if keys.contains(key) {
                    if let idx = follows.firstIndex(where: { $0.fromUserId == rel.fromUserId && $0.toUserId == rel.toUserId }) {
                        follows[idx].status = rel.status
                    }
                } else {
                    follows.append(rel)
                    keys.insert(key)
                }
            }
            persistFollows()
        }

        if !cloudBlocks.isEmpty {
            for pair in cloudBlocks where pair.blockerId == currentUserId {
                blockedUserIds.insert(pair.blockedId)
            }
            persistBlocked()
        }

        resetFeedPagination()
        pruneExpiredContent()
    }

    // MARK: - Private

    @discardableResult
    private func insertPost(_ post: PulsePost) -> PulsePost {
        ensureCommunityJoined(post.community)
        posts.insert(post, at: 0)
        persistPosts()
        notifyFollowers(of: post)
        notifyMentions(
            in: post.caption,
            fromUserId: post.authorId,
            fromName: post.authorName,
            context: "post"
        )
        scheduleCloudUpsert(post)
        return post
    }

    private func scheduleCloudUpsert(_ post: PulsePost) {
        guard PulseExperimental.isCloudSyncEffective else { return }
        let imageData: Data? = {
            guard let name = post.mediaFileName else { return nil }
            return try? Data(contentsOf: mediaURL(for: name))
        }()
        Task {
            let remoteURL = await PulseFirestoreService.upsertPost(post, imageJPEG: imageData)
            if let remoteURL, let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].remoteMediaURL = remoteURL
                persistPosts()
            }
        }
    }

    private func stripDemoContentUnlessEnabled(force: Bool = false) {
        guard force || !PulseExperimental.includeDemoContent else { return }
        let beforePosts = posts.count
        let beforeStories = stories.count
        let beforePeople = people.count
        posts.removeAll { $0.authorId.hasPrefix("demo-") }
        stories.removeAll { $0.authorId.hasPrefix("demo-") }
        people.removeAll { $0.id.hasPrefix("demo-") }
        follows.removeAll {
            $0.fromUserId.hasPrefix("demo-") || $0.toUserId.hasPrefix("demo-")
        }
        if posts.count != beforePosts { persistPosts() }
        if stories.count != beforeStories { persistStories() }
        if people.count != beforePeople { persistPeople() }
        if beforePosts != posts.count || beforeStories != stories.count {
            persistFollows()
        }
    }

    private func notifyFollowers(of post: PulsePost) {
        let watchers = follows.filter {
            $0.toUserId == post.authorId && $0.status == .following && $0.notifyPosts
        }
        guard !watchers.isEmpty else { return }
        pushNotification(
            title: L10n.Pulse.notifyNewPostTitle,
            body: L10n.Pulse.notifyNewPostBody(post.authorName, post.community.title),
            scheduleSystemBanner: true
        )
    }

    private func notifyMentions(
        in text: String,
        fromUserId: String,
        fromName: String,
        context: String
    ) {
        let handles = PulseMentionParser.handles(in: text)
        guard !handles.isEmpty else { return }
        let following = followingPeople(of: fromUserId)
        for handle in handles {
            guard let person = following.first(where: {
                $0.mentionHandle.compare(handle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) else { continue }
            pushNotification(
                title: "Pulse · Menção",
                body: "\(fromName) marcou @\(person.mentionHandle) em um \(context).",
                scheduleSystemBanner: true
            )
        }
    }

    private func pushNotification(title: String, body: String, scheduleSystemBanner: Bool = false) {
        notifications.insert(PulseSocialNotification(title: title, body: body), at: 0)
        persistNotifications()
        guard scheduleSystemBanner else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.4, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pulse-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Persistência em arquivo (fora do UserDefaults) — write em background.
    private func persistCodable<T: Encodable>(_ value: T, file: String, legacyKey: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let url = diskFileURL(file)
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    private func persistPosts() {
        persistCodable(posts, file: "posts.json", legacyKey: postsKey)
    }

    private func persistStories() {
        persistCodable(stories, file: "stories.json", legacyKey: storiesKey)
    }

    private func persistPeople() {
        persistCodable(people, file: "people.json", legacyKey: peopleKey)
    }

    private func persistFollows() {
        persistCodable(follows, file: "follows.json", legacyKey: followsKey)
    }

    private func persistNotifications() {
        persistCodable(notifications, file: "notifications.json", legacyKey: notificationsKey)
    }

    private func persistBlocked() {
        let values = Array(blockedUserIds)
        let url = diskFileURL("blocked.json")
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(values) else { return }
            try? data.write(to: url, options: .atomic)
        }
        UserDefaults.standard.removeObject(forKey: blockedKey)
    }

    private func persistCommunities() {
        UserDefaults.standard.set(joinedCommunities.map(\.rawValue), forKey: communitiesKey)
    }

    private func persistCardioModalities() {
        UserDefaults.standard.set(Array(joinedCardioModalities), forKey: cardioModalitiesKey)
    }

    private func persistChat() {
        guard PulseExperimental.isChatEnabledInBuild else { return }
        persistCodable(chatMessages, file: "chat.json", legacyKey: chatKey)
    }

    private func loadDiskOrLegacy<T: Decodable>(_ type: T.Type, file: String, legacyKey: String) -> T? {
        let url = diskFileURL(file)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        if let data = UserDefaults.standard.data(forKey: legacyKey),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            try? data.write(to: url, options: .atomic)
            UserDefaults.standard.removeObject(forKey: legacyKey)
            return decoded
        }
        return nil
    }

    private func load() {
        if let decoded: [PulsePost] = loadDiskOrLegacy([PulsePost].self, file: "posts.json", legacyKey: postsKey) {
            posts = decoded
        }
        if let decoded: [PulseStory] = loadDiskOrLegacy([PulseStory].self, file: "stories.json", legacyKey: storiesKey) {
            stories = decoded
        }
        if let decoded: [PulsePerson] = loadDiskOrLegacy([PulsePerson].self, file: "people.json", legacyKey: peopleKey) {
            people = decoded
        }
        if let decoded: [PulseFollowRelation] = loadDiskOrLegacy([PulseFollowRelation].self, file: "follows.json", legacyKey: followsKey) {
            follows = decoded
        }
        if let decoded: [PulseSocialNotification] = loadDiskOrLegacy([PulseSocialNotification].self, file: "notifications.json", legacyKey: notificationsKey) {
            notifications = decoded
        }
        if PulseExperimental.isChatEnabledInBuild,
           let decoded: [PulseChatMessage] = loadDiskOrLegacy([PulseChatMessage].self, file: "chat.json", legacyKey: chatKey) {
            chatMessages = decoded
        } else {
            chatMessages = []
            UserDefaults.standard.removeObject(forKey: chatKey)
        }
        if let decoded: [String] = loadDiskOrLegacy([String].self, file: "blocked.json", legacyKey: blockedKey) {
            blockedUserIds = Set(decoded)
        } else if let blocked = UserDefaults.standard.array(forKey: blockedKey) as? [String] {
            blockedUserIds = Set(blocked)
        }
        if let raw = UserDefaults.standard.array(forKey: communitiesKey) as? [String] {
            let set = Set(raw.compactMap(PulseCommunity.init(storageKey:)))
            if !set.isEmpty { joinedCommunities = set }
        }
        if let modalities = UserDefaults.standard.array(forKey: cardioModalitiesKey) as? [String], !modalities.isEmpty {
            joinedCardioModalities = Set(modalities)
        }
        // Modalidades de cardio ativas também são comunidades.
        syncCardioModalitiesIntoCommunities()
    }

    private func syncCardioModalitiesIntoCommunities() {
        var updatedCommunities = joinedCommunities
        var updatedModalities = joinedCardioModalities
        for name in joinedCardioModalities {
            updatedCommunities.insert(.cardioModality(name))
        }
        for community in updatedCommunities where community.isCardioModality {
            if case .cardioModality(let name) = community {
                updatedModalities.insert(name)
            }
        }
        let communitiesChanged = updatedCommunities != joinedCommunities
        let modalitiesChanged = updatedModalities != joinedCardioModalities
        if communitiesChanged {
            joinedCommunities = updatedCommunities
            persistCommunities()
        }
        if modalitiesChanged {
            joinedCardioModalities = updatedModalities
            persistCardioModalities()
        }
    }

    private func seedDemoPosts() {
        let now = Date()
        let demos = [
            PulsePost(
                authorId: "demo-coach",
                authorName: "Coach HealthFit",
                caption: "Progresso não é barulho. É constância.\n\(PulseExperimental.tagline)",
                mediaKind: .photo,
                systemImagePlaceholder: "figure.strengthtraining.traditional",
                community: .musculacao,
                workoutMeta: PulseWorkoutMeta(modality: "Musculação", durationSeconds: 3600, intensity: 7, duoTeamName: nil),
                createdAt: now.addingTimeInterval(-3600),
                reactions: [
                    PulseReactionEvent(userId: "demo-runner", userName: "Atleta Pulse", kind: "heart"),
                    PulseReactionEvent(userId: "demo-es", userName: "Carla Run", kind: "heart"),
                    PulseReactionEvent(userId: "demo-kite", userName: "Maya Kite", kind: "heart"),
                    PulseReactionEvent(userId: "demo-us", userName: "Alex Fit", kind: "heart")
                ],
                comments: [PulseComment(authorId: "demo-1", authorName: "Ana", text: "Isso bateu forte")]
            ),
            PulsePost(
                authorId: "demo-runner",
                authorName: "Atleta Pulse",
                authorCountryCode: "PT",
                caption: "Cardio leve, mente leve.",
                mediaKind: .photo,
                systemImagePlaceholder: "figure.run",
                community: .cardio,
                workoutMeta: PulseWorkoutMeta(modality: "Corrida", durationSeconds: 1800, intensity: 6, duoTeamName: nil),
                createdAt: now.addingTimeInterval(-7200),
                reactions: [
                    PulseReactionEvent(userId: "demo-coach", userName: "Coach HealthFit", kind: "heart"),
                    PulseReactionEvent(userId: "demo-es", userName: "Carla Run", kind: "heart")
                ]
            ),
            PulsePost(
                authorId: "demo-kite",
                authorName: "Maya Kite",
                authorCountryCode: "BR",
                caption: "Vento bom em Jeri. Sessão curta e feliz.",
                mediaKind: .photo,
                systemImagePlaceholder: "wind",
                community: .kite,
                workoutMeta: PulseWorkoutMeta(modality: "Kitesurf", durationSeconds: 5400, intensity: 8, duoTeamName: "Spot Buddies"),
                createdAt: now.addingTimeInterval(-10_800),
                reactions: [
                    PulseReactionEvent(userId: "demo-runner", userName: "Atleta Pulse", kind: "heart"),
                    PulseReactionEvent(userId: "demo-coach", userName: "Coach HealthFit", kind: "heart")
                ]
            )
        ]
        let toInsert = demos.filter { demo in
            !posts.contains(where: { $0.authorId == demo.authorId && $0.caption == demo.caption })
        }
        posts.insert(contentsOf: toInsert, at: 0)
        persistPosts()
    }

    private func seedDemoStories() {
        let demos = [
            PulseStory(
                authorId: "demo-coach",
                authorName: "Coach",
                systemImagePlaceholder: "figure.strengthtraining.traditional",
                createdAt: Date().addingTimeInterval(-1800),
                reactions: [
                    PulseReactionEvent(userId: "demo-runner", userName: "Atleta Pulse", kind: "heart"),
                    PulseReactionEvent(userId: "demo-es", userName: "Carla Run", kind: "heart")
                ]
            ),
            PulseStory(
                authorId: "demo-runner",
                authorName: "Atleta",
                systemImagePlaceholder: "figure.run",
                createdAt: Date().addingTimeInterval(-3600),
                reactions: [
                    PulseReactionEvent(userId: "demo-coach", userName: "Coach HealthFit", kind: "heart")
                ]
            ),
            PulseStory(authorId: "demo-yoga", authorName: "Maya", systemImagePlaceholder: "figure.yoga", createdAt: Date().addingTimeInterval(-5400))
        ]
        let toInsert = demos.filter { demo in
            !stories.contains(where: { $0.authorId == demo.authorId })
        }
        stories.insert(contentsOf: toInsert, at: 0)
        persistStories()
    }

    private func seedPeople() {
        let demos = [
            PulsePerson(id: "demo-coach", displayName: "Coach HealthFit", emailHint: "coach@healthfit.app", countryCode: "BR", state: "SP", city: "São Paulo", bio: "Personal e mentor Pulse", communityFocus: .musculacao, notifyOnPosts: true),
            PulsePerson(id: "demo-runner", displayName: "Atleta Pulse", emailHint: "atleta@pulse.app", countryCode: "PT", state: "Lisboa", city: "Lisboa", bio: "Corrida e consistência", communityFocus: .cardio, notifyOnPosts: true),
            PulsePerson(id: "demo-kite", displayName: "Maya Kite", emailHint: "maya@kite.app", countryCode: "BR", state: "CE", city: "Jericoacoara", bio: "Kitesurf e vento", communityFocus: .kite, notifyOnPosts: true),
            PulsePerson(id: "demo-nutri", displayName: "Nina Nutri", emailHint: "nina@nutri.app", countryCode: "AR", state: "CABA", city: "Buenos Aires", bio: "Nutrição prática", communityFocus: .nutricao, notifyOnPosts: false),
            PulsePerson(id: "demo-us", displayName: "Alex Fit", emailHint: "alex@fit.us", countryCode: "US", state: "CA", city: "Los Angeles", bio: "Hyrox & strength", communityFocus: .musculacao, notifyOnPosts: true),
            PulsePerson(id: "demo-es", displayName: "Carla Run", emailHint: "carla@run.es", countryCode: "ES", state: "Catalunya", city: "Barcelona", bio: "10K e trails", communityFocus: .cardio, notifyOnPosts: true)
        ]
        let existing = Set(people.map(\.id))
        people.append(contentsOf: demos.filter { !existing.contains($0.id) })
        persistPeople()
    }

    private func videoDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
}

enum PulseStoreError: LocalizedError {
    case encodeFailed
    case videoTooLong
    case videoDisabled

    var errorDescription: String? {
        switch self {
        case .encodeFailed: return L10n.Pulse.errorMediaSave
        case .videoTooLong: return L10n.Pulse.errorVideoTooLong(Int(PulseExperimental.maxVideoSeconds))
        case .videoDisabled: return L10n.Pulse.errorVideoDisabled
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

enum PulseMentionParser {
    static func handles(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"@([A-Za-z0-9_]+)"#) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    static func activeQuery(in text: String) -> String? {
        guard let at = text.lastIndex(of: "@") else { return nil }
        let after = text[text.index(after: at)...]
        if after.contains(where: { $0.isWhitespace || $0.isNewline }) { return nil }
        return String(after)
    }

    static func applyingMention(person: PulsePerson, to text: String) -> String {
        if let at = text.lastIndex(of: "@") {
            let prefix = text[..<at]
            return prefix + "@\(person.mentionHandle) "
        }
        return text + "@\(person.mentionHandle) "
    }
}
