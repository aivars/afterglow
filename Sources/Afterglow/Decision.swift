import Foundation

/// Version comparison on `major.minor` only. Patch and anything after it is ignored;
/// non-numeric components count as 0.
struct AfterglowVersion: Comparable, Hashable, Sendable {
    let major: Int
    let minor: Int

    init(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        func component(_ index: Int) -> Int {
            guard index < parts.count, let value = Int(parts[index]), value >= 0 else { return 0 }
            return value
        }
        major = component(0)
        minor = component(1)
    }

    static func < (lhs: AfterglowVersion, rhs: AfterglowVersion) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }

    /// True when the two strings differ in major or minor ("4.20.1" vs "4.20.2" is false).
    static func minorChanged(_ a: String, _ b: String) -> Bool {
        AfterglowVersion(a) != AfterglowVersion(b)
    }
}

extension Duration {
    var afterglowSeconds: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

/// What to do at an "app became active" moment. See ``decide(currentVersion:snapshot:isEligibleUser:minimumInstallAge:reviewCooldown:maxReviewScreensPerVersion:now:hasReleaseNote:)``.
enum AfterglowDecision: Equatable, Sendable {
    case none
    case whatsNewOnly
    case whatsNewThenReview

    /// Pure rule table. The caller records `currentVersion` as last seen after every
    /// call (except when it is a downgrade), so stale notes never show later.
    static func decide(
        currentVersion: String,
        snapshot: AfterglowSnapshot,
        isEligibleUser: Bool,
        minimumInstallAge: Duration,
        reviewCooldown: Duration,
        maxReviewScreensPerVersion: Int,
        now: Date,
        hasReleaseNote: Bool
    ) -> AfterglowDecision {
        // Fresh install: the first What's New is for the first update after installing.
        guard let lastSeen = snapshot.lastSeenVersion else { return .none }

        // Only a minor (or major) upgrade counts; patch bumps and downgrades never show.
        guard AfterglowVersion(currentVersion) > AfterglowVersion(lastSeen) else { return .none }

        guard isEligibleUser else { return .none }

        let installAge = snapshot.firstLaunchDate.map { now.timeIntervalSince($0) } ?? 0
        guard installAge >= minimumInstallAge.afterglowSeconds else { return .none }

        guard hasReleaseNote else { return .none }

        guard maxReviewScreensPerVersion >= 1 else { return .whatsNewOnly }

        if let shown = snapshot.reviewScreenShownForVersion,
           !AfterglowVersion.minorChanged(shown, currentVersion) {
            return .whatsNewOnly
        }

        if let tap = snapshot.lastWriteReviewTap,
           now.timeIntervalSince(tap) < reviewCooldown.afterglowSeconds {
            return .whatsNewOnly
        }

        return .whatsNewThenReview
    }
}
