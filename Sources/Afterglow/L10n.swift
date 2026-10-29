import Foundation

/// Chrome strings, localized from the package's own `Localizable.xcstrings`.
enum L10n {
    static var continueButton: String { String(localized: "Continue", bundle: .module) }
    static var notNow: String { String(localized: "Not now", bundle: .module) }
    static var sendFeedback: String { String(localized: "Not happy? Send feedback", bundle: .module) }
    static var whatsNew: String { String(localized: "What's new", bundle: .module) }
    static var writeReview: String { String(localized: "Write a review", bundle: .module) }
    static var whyRate: String {
        String(localized: "A quick rating helps more people find the app and keeps us improving.", bundle: .module)
    }
    static var fiveStars: String { String(localized: "5 out of 5 stars", bundle: .module) }

    static func helpGrow(_ appName: String) -> String {
        String(localized: "Help \(appName) grow", bundle: .module)
    }

    static func rate(_ appName: String) -> String {
        String(localized: "Rate \(appName)", bundle: .module)
    }

    static func whatsNewIn(_ version: String) -> String {
        String(localized: "What's new in \(version)", bundle: .module)
    }

    static func versionLabel(_ version: String) -> String {
        String(localized: "Version \(version)", bundle: .module)
    }

    static func madeForYou(_ appName: String) -> String {
        String(localized: "\(appName) was made for people like you.", bundle: .module)
    }

    static func ratedOutOfFive(_ average: String) -> String {
        String(localized: "Rated \(average) out of 5 stars", bundle: .module)
    }

    /// "6,000+ ratings"; `count` is already formatted and rounded.
    static func ratingsCount(_ count: String) -> String {
        String(localized: "\(count) ratings", bundle: .module)
    }
}
