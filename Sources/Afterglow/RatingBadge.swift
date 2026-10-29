import Foundation

/// What the review sheet's laurel badge shows, decided from the host's rating summary.
enum RatingBadgeContent: Equatable, Sendable {
    /// Five stars only: no summary, too few ratings, or a low average.
    case starsOnly
    /// The average and a rounded, localized count line, e.g. "4.8" and "6,000+ ratings".
    case summary(averageText: String, countText: String)

    static func make(
        summary: RatingSummary?,
        minimumCount: Int,
        minimumAverage: Double,
        locale: Locale = .current
    ) -> RatingBadgeContent {
        guard let summary, summary.count >= minimumCount, summary.average >= minimumAverage else {
            return .starsOnly
        }
        let averageText = summary.average.formatted(.number.precision(.fractionLength(1)).locale(locale))
        let count = summary.count
        let rounded: Int
        let suffix: String
        switch count {
        case 1000...: rounded = count / 1000 * 1000; suffix = "+"
        case 100...: rounded = count / 100 * 100; suffix = "+"
        default: rounded = count; suffix = ""
        }
        let number = rounded.formatted(.number.grouping(.automatic).locale(locale))
        return .summary(averageText: averageText, countText: L10n.ratingsCount(number + suffix))
    }
}
