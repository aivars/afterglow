import SwiftUI

/// What's new in one minor version of the app. Content is owned (and localized) by the host app.
public struct ReleaseNote: Identifiable, Sendable {
    /// One row in the What's New list: an icon, a headline and a line of detail.
    public struct Item: Identifiable, Sendable {
        /// Identity for `ForEach`; the headline, so keep headlines unique within a note.
        public var id: String { headline }
        /// An SF Symbol or an image in `Bundle.main`. A symbol that does not exist on the running OS,
        /// or a missing asset, renders as `sparkles` instead of a blank circle.
        public let image: AfterglowImage
        /// The short, bold line of the row.
        public let headline: String
        /// One supporting sentence under the headline.
        public let detail: String

        /// Creates a row from any ``AfterglowImage``.
        public init(image: AfterglowImage, headline: String, detail: String) {
            self.image = image
            self.headline = headline
            self.detail = detail
        }

        /// Shorthand for `init(image: .system(systemImage), ...)`.
        public init(systemImage: String, headline: String, detail: String) {
            self.init(image: .system(systemImage), headline: headline, detail: detail)
        }
    }

    /// Identity for `ForEach`; the version string.
    public var id: String { version }
    /// `major.minor` (a patch component is accepted and ignored), e.g. "4.21".
    public let version: String
    /// The sheet's title, e.g. "Custom tables".
    public let title: String
    /// The rows shown under the title. 3 to 5 reads best.
    public let items: [Item]

    /// Creates a note for `version` (`major.minor`) with a title and its rows.
    public init(version: String, title: String, items: [Item]) {
        self.version = version
        self.title = title
        self.items = items
    }
}

/// A real App Store review, curated by the host app at build time.
///
/// Keep quotes under about 220 characters (trim with an ellipsis if needed): the view never truncates,
/// so a long quote makes its card tall and pushes the others off screen. In DEBUG builds a quote over
/// 400 characters trips an `assertionFailure`; release builds never crash and show the quote in full.
public struct Testimonial: Identifiable, Sendable {
    /// DEBUG builds assert above this length.
    static let hardQuoteLimit = 400

    /// Identity for `ForEach`; the author and quote combined.
    public var id: String { author + "|" + quote }
    /// The review text, shown in full. Keep it under about 220 characters.
    public let quote: String
    /// First name plus initial, e.g. "Scott E."
    public let author: String
    /// Usually "App Store".
    public let source: String

    /// Creates a testimonial. In DEBUG builds a quote over 400 characters trips an `assertionFailure`.
    public init(quote: String, author: String, source: String) {
        #if DEBUG
        if quote.count > Self.hardQuoteLimit {
            assertionFailure("Afterglow: testimonial quote is \(quote.count) characters; keep it under ~220 (hard limit \(Self.hardQuoteLimit)).")
        }
        #endif
        self.quote = quote
        self.author = author
        self.source = source
    }
}

/// Analytics events delivered through ``AfterglowConfiguration/onEvent``.
public enum AfterglowEvent: String, Sendable {
    /// The What's New sheet appeared (automatically or via `presentWhatsNew()`).
    case whatsNewShown
    /// The review sheet appeared.
    case reviewScreenShown
    /// The system rating prompt was requested (by the timer, never by a tap).
    case systemPromptRequested
    /// The user tapped the primary button (or `openWriteReview()` was called).
    case writeReviewTapped
    /// The user tapped "Not happy? Send feedback".
    case feedbackTapped
    /// The review sheet was closed with "Not now" or a swipe, without any other action.
    case dismissed
}

/// Tunable rules. Pure data plus one app-defined closure; the decision logic lives in `AfterglowDecision`.
public struct AfterglowPolicy: Sendable {
    /// App-defined, e.g. "finished onboarding and has at least one real session".
    public var isEligibleUser: @Sendable () -> Bool
    /// The install must be at least this old before any sheet shows.
    public var minimumInstallAge: Duration
    /// After the user taps "Write a review", the review sheet stays away for this long.
    public var reviewCooldown: Duration
    /// `0` disables the review sheet. Any value of `1` or more means once per minor version
    /// (only the version is stored, not a count).
    public var maxReviewScreensPerVersion: Int
    /// How long after the review screen is dismissed without a tap on "Rate" or "Send feedback"
    /// ("Not now", a swipe down) before Apple's system rating prompt is requested. It is never
    /// requested while the review screen is visible.
    public var promptDelay: Duration

    /// Creates a policy. Defaults: two days of install age, a 365-day review cooldown, one review screen per minor version, and a 0.6 s delay before Apple's prompt.
    public init(
        isEligibleUser: @escaping @Sendable () -> Bool,
        minimumInstallAge: Duration = .seconds(2 * 86_400),
        reviewCooldown: Duration = .seconds(365 * 86_400),
        maxReviewScreensPerVersion: Int = 1,
        promptDelay: Duration = .milliseconds(600)
    ) {
        self.isEligibleUser = isEligibleUser
        self.minimumInstallAge = minimumInstallAge
        self.reviewCooldown = reviewCooldown
        self.maxReviewScreensPerVersion = maxReviewScreensPerVersion
        self.promptDelay = promptDelay
    }

    /// Every user is eligible; two days of install age, a 365-day cooldown, once per minor version, 0.6 s prompt delay.
    public static let `default` = AfterglowPolicy(isEligibleUser: { true })
}

/// The App Store rating shown in the review sheet's badge, e.g. 4.8 from 6,059 ratings.
/// The sheet formats and rounds the count itself ("6,000+"), and falls back to plain stars when the
/// count or average is below ``AfterglowConfiguration/minimumRatingCount`` / ``AfterglowConfiguration/minimumRatingAverage``.
public struct RatingSummary: Sendable {
    /// The average star rating, e.g. 4.8.
    public let average: Double
    /// The raw number of ratings, e.g. 6059.
    public let count: Int
    /// Which ratings `count` covers. The App Store shows each storefront its own count, so a total
    /// summed over every storefront is larger than what any one person sees there; say so.
    public let scope: Scope

    public enum Scope: Sendable {
        /// The count of one storefront, as the App Store shows it there. The badge reads "6,000+ ratings".
        case storefront
        /// The count summed over every storefront. The badge reads "6,000+ ratings worldwide".
        case worldwide
    }

    /// Creates a summary from the raw App Store average and rating count.
    public init(average: Double, count: Int, scope: Scope = .storefront) {
        self.average = average
        self.count = count
        self.scope = scope
    }
}

/// An image the host app can hand to Afterglow without exposing UIKit or AppKit types.
public enum AfterglowImage: Sendable {
    /// An image in `Bundle.main` (an asset or the app icon, e.g. "AppIcon60x60").
    case named(String)
    /// An SF Symbol name.
    case system(String)
}

/// Everything Afterglow needs from the host app: identity, content, rules and hooks. Pass it to `.afterglow(_:)`.
public struct AfterglowConfiguration: Sendable {
    /// The numeric App Store ID, with or without the `id` prefix ("123456789" or "id123456789"). Used for the write-review link.
    public var appStoreID: String
    /// The app's display name, used in the review screen's headings and button.
    public var appName: String
    /// One note per minor version. A version with no note shows nothing.
    public var releaseNotes: [ReleaseNote]
    /// Reviews shown as cards on the review screen (up to 3). Empty hides the cards.
    public var testimonials: [Testimonial]
    /// Optional line in the community pill, e.g. "Join 12,000 people using MyApp". Localized by the host. The pill is omitted when nil.
    public var communityLine: String?
    /// "Not happy? Send feedback" is shown only when this is non-nil.
    public var feedbackAction: (@MainActor () -> Void)?
    /// Called for each ``AfterglowEvent``; forward it to your analytics. Nil by default.
    public var onEvent: (@Sendable (AfterglowEvent) -> Void)?
    /// The eligibility, cooldown and timing rules.
    public var policy: AfterglowPolicy
    /// The tint for icons, the primary button and highlights. Defaults to the app's accent color.
    public var accent: Color
    /// Return `false` while another cover (paywall, onboarding, celebration) is up.
    /// Afterglow then skips this check and records nothing.
    public var canPresent: @MainActor () -> Bool
    /// Shows a laurel badge with the average and count at the top of the review sheet. Stars only when nil.
    public var ratingSummary: RatingSummary?
    /// Below this many ratings the badge shows plain stars (a small count reads as weak social proof).
    public var minimumRatingCount: Int
    /// Below this average the badge shows plain stars.
    public var minimumRatingAverage: Double
    /// The What's New hero. Falls back to a sparkles tile when nil or when a named image is missing.
    public var heroImage: AfterglowImage?

    /// Creates a configuration. Only `appStoreID`, `appName` and `releaseNotes` are required; everything else is optional and defaults to off or to a sensible value (`policy: .default`, `minimumRatingCount: 50`, `minimumRatingAverage: 4.0`).
    public init(
        appStoreID: String,
        appName: String,
        releaseNotes: [ReleaseNote],
        testimonials: [Testimonial] = [],
        communityLine: String? = nil,
        feedbackAction: (@MainActor () -> Void)? = nil,
        onEvent: (@Sendable (AfterglowEvent) -> Void)? = nil,
        policy: AfterglowPolicy = .default,
        accent: Color = .accentColor,
        canPresent: @escaping @MainActor () -> Bool = { true },
        ratingSummary: RatingSummary? = nil,
        heroImage: AfterglowImage? = nil,
        minimumRatingCount: Int = 50,
        minimumRatingAverage: Double = 4.0
    ) {
        self.appStoreID = appStoreID
        self.appName = appName
        self.releaseNotes = releaseNotes
        self.testimonials = testimonials
        self.communityLine = communityLine
        self.feedbackAction = feedbackAction
        self.onEvent = onEvent
        self.policy = policy
        self.accent = accent
        self.canPresent = canPresent
        self.ratingSummary = ratingSummary
        self.heroImage = heroImage
        self.minimumRatingCount = minimumRatingCount
        self.minimumRatingAverage = minimumRatingAverage
    }

    /// `https://apps.apple.com/app/id<appStoreID>?action=write-review`
    var writeReviewURL: URL? {
        let digits = appStoreID.hasPrefix("id") ? String(appStoreID.dropFirst(2)) : appStoreID
        return URL(string: "https://apps.apple.com/app/id\(digits)?action=write-review")
    }
}
