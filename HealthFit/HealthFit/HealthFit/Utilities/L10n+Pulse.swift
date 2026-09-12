import Foundation

extension L10n {
    /// Textos do HealthFit Pulse (pt-BR, en, es, fr).
    enum Pulse {
        private static func tr(_ key: String) -> String { L10n.tr(key) }

        private static var locale: Locale {
            let code = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
            return AppLanguage.resolved(fromStoredCode: code).locale
        }

        private static func trf(_ key: String, arguments: [CVarArg]) -> String {
            String(format: tr(key), locale: locale, arguments: arguments)
        }

        static var accept: String { tr("pulse.accept") }
        static var active: String { tr("pulse.active") }
        static func ageGateBodyKnown(_ args: CVarArg...) -> String {
            trf("pulse.age_gate_body_known", arguments: args)
        }
        static func ageGateBodyUnknown(_ args: CVarArg...) -> String {
            trf("pulse.age_gate_body_unknown", arguments: args)
        }
        static func ageGateTitle(_ args: CVarArg...) -> String {
            trf("pulse.age_gate_title", arguments: args)
        }
        static var allCountries: String { tr("pulse.all_countries") }
        static var athlete: String { tr("pulse.athlete") }
        static var cancel: String { tr("pulse.cancel") }
        static func captionWorkoutDefault(_ args: CVarArg...) -> String {
            trf("pulse.caption.workout_default", arguments: args)
        }
        static var city: String { tr("pulse.city") }
        static var close: String { tr("pulse.close") }
        static var communityCardio: String { tr("pulse.community.cardio") }
        static var communityKite: String { tr("pulse.community.kite") }
        static var communityMusculacao: String { tr("pulse.community.musculacao") }
        static var communityNutricao: String { tr("pulse.community.nutricao") }
        static var composerCaption: String { tr("pulse.composer.caption") }
        static var composerCommunity: String { tr("pulse.composer.community") }
        static var composerEditPost: String { tr("pulse.composer.edit_post") }
        static var composerMedia: String { tr("pulse.composer.media") }
        static var composerMusicOptional: String { tr("pulse.composer.music_optional") }
        static var composerNewPost: String { tr("pulse.composer.new_post") }
        static var country: String { tr("pulse.country") }
        static var coverPublished: String { tr("pulse.cover_published") }
        static var dailyChallenge: String { tr("pulse.daily_challenge") }
        static var dashboardCommunities: String { tr("pulse.dashboard.communities") }
        static var dashboardEyebrow: String { tr("pulse.dashboard.eyebrow") }
        static var dashboardRanking: String { tr("pulse.dashboard.ranking") }
        static var dashboardStories: String { tr("pulse.dashboard.stories") }
        static var decline: String { tr("pulse.decline") }
        static var deleteAccountWarning: String { tr("pulse.delete_account_warning") }
        static var emptyFeedBodyNoWorkout: String { tr("pulse.empty_feed_body_no_workout") }
        static func emptyFeedShareWorkout(_ args: CVarArg...) -> String {
            trf("pulse.empty_feed_share_workout", arguments: args)
        }
        static var emptyFeedTitle: String { tr("pulse.empty_feed_title") }
        static var errorMediaSave: String { tr("pulse.error.media_save") }
        static var errorVideoDisabled: String { tr("pulse.error.video_disabled") }
        static func errorVideoTooLong(_ args: CVarArg...) -> String {
            trf("pulse.error.video_too_long", arguments: args)
        }
        static var featureName: String { tr("pulse.feature_name") }
        static var follow: String { tr("pulse.follow") }
        static var following: String { tr("pulse.following") }
        static var lightRanking: String { tr("pulse.light_ranking") }
        static var menuBlock: String { tr("pulse.menu.block") }
        static var menuDelete: String { tr("pulse.menu.delete") }
        static var menuEdit: String { tr("pulse.menu.edit") }
        static var menuHide: String { tr("pulse.menu.hide") }
        static var menuReport: String { tr("pulse.menu.report") }
        static var menuShareInstagram: String { tr("pulse.menu.share_instagram") }
        static func metaIntensity(_ args: CVarArg...) -> String {
            trf("pulse.meta.intensity", arguments: args)
        }
        static func metaMinutes(_ args: CVarArg...) -> String {
            trf("pulse.meta.minutes", arguments: args)
        }
        static func metaSeconds(_ args: CVarArg...) -> String {
            trf("pulse.meta.seconds", arguments: args)
        }
        static var moderationDelete: String { tr("pulse.moderation.delete") }
        static var moderationEmpty: String { tr("pulse.moderation.empty") }
        static var moderationHide: String { tr("pulse.moderation.hide") }
        static var moderationTitle: String { tr("pulse.moderation.title") }
        static var musicClipTitle: String { tr("pulse.music.clip_title") }
        static var musicDeezerPreview: String { tr("pulse.music.deezer_preview") }
        static var musicSearchPlaceholder: String { tr("pulse.music.search_placeholder") }
        static var noBio: String { tr("pulse.no_bio") }
        static func notifyFollowRequestBody(_ args: CVarArg...) -> String {
            trf("pulse.notify.follow_request_body", arguments: args)
        }
        static var notifyFollowRequestTitle: String { tr("pulse.notify.follow_request_title") }
        static var notifyFollowingBody: String { tr("pulse.notify.following_body") }
        static var notifyFollowingTitle: String { tr("pulse.notify.following_title") }
        static func notifyNewPostBody(_ args: CVarArg...) -> String {
            trf("pulse.notify.new_post_body", arguments: args)
        }
        static var notifyNewPostTitle: String { tr("pulse.notify.new_post_title") }
        static var notifyReportBody: String { tr("pulse.notify.report_body") }
        static var notifyReportTitle: String { tr("pulse.notify.report_title") }
        static var ok: String { tr("pulse.ok") }
        static var photoPublished: String { tr("pulse.photo_published") }
        static var playMusic: String { tr("pulse.play_music") }
        static var prepareImageFailed: String { tr("pulse.prepare_image_failed") }
        static var publish: String { tr("pulse.publish") }
        static var publishWorkout: String { tr("pulse.publish_workout") }
        static var publishedAlertTitle: String { tr("pulse.published_alert_title") }
        static var requested: String { tr("pulse.requested") }
        static var save: String { tr("pulse.save") }
        static var saveBio: String { tr("pulse.save_bio") }
        static var searchName: String { tr("pulse.search_name") }
        static var shareHintDefault: String { tr("pulse.share.hint_default") }
        static var shareHintMusic: String { tr("pulse.share.hint_music") }
        static var shareInstagram: String { tr("pulse.share_instagram") }
        static var shareOnPulse: String { tr("pulse.share_on_pulse") }
        static var someone: String { tr("pulse.someone") }
        static var state: String { tr("pulse.state") }
        static var stopMusic: String { tr("pulse.stop_music") }
        static var storyAddMusic: String { tr("pulse.story.add_music") }
        static var storyDelete: String { tr("pulse.story.delete") }
        static var storyNew: String { tr("pulse.story.new") }
        static var storyPublish: String { tr("pulse.story.publish") }
        static var storyYours: String { tr("pulse.story.yours") }
        static var tabCommunity: String { tr("pulse.tab.community") }
        static var tabFeed: String { tr("pulse.tab.feed") }
        static var tabPeople: String { tr("pulse.tab.people") }
        static var tabPost: String { tr("pulse.tab.post") }
        static var tagline: String { tr("pulse.tagline") }
        static var termsAccept: String { tr("pulse.terms.accept") }
        static var termsDeclareAge: String { tr("pulse.terms.declare_age") }
        static var termsIntro: String { tr("pulse.terms.intro") }
        static var termsNotNow: String { tr("pulse.terms.not_now") }
        static var termsScrollEnd: String { tr("pulse.terms.scroll_end") }
        static var termsScrollHint: String { tr("pulse.terms.scroll_hint") }
        static var termsTitle: String { tr("pulse.terms.title") }
        static func termsVersion(_ args: CVarArg...) -> String {
            trf("pulse.terms.version", arguments: args)
        }
        static var useLocation: String { tr("pulse.use_location") }
        static var videoPublished: String { tr("pulse.video_published") }
        static var weeklyHighlight: String { tr("pulse.weekly_highlight") }
        static var workoutPublished: String { tr("pulse.workout_published") }
        static var yourBio: String { tr("pulse.your_bio") }
    }
}
