import Foundation
import Testing
@testable import Afterglow

private let day: TimeInterval = 86_400
private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func decide(
    _ current: String,
    lastSeen: String? = "4.20",
    reviewShownFor: String? = nil,
    lastTap: Date? = nil,
    installedDaysAgo: Double? = 30,
    eligible: Bool = true,
    hasNote: Bool = true,
    minimumAgeDays: Int = 2,
    cooldownDays: Int = 365,
    maxReviews: Int = 1
) -> AfterglowDecision {
    AfterglowDecision.decide(
        currentVersion: current,
        snapshot: AfterglowSnapshot(
            lastSeenVersion: lastSeen,
            reviewScreenShownForVersion: reviewShownFor,
            lastWriteReviewTap: lastTap,
            firstLaunchDate: installedDaysAgo.map { now.addingTimeInterval(-$0 * day) }
        ),
        isEligibleUser: eligible,
        minimumInstallAge: .seconds(minimumAgeDays * 86_400),
        reviewCooldown: .seconds(cooldownDays * 86_400),
        maxReviewScreensPerVersion: maxReviews,
        now: now,
        hasReleaseNote: hasNote
    )
}

@Suite("Decision table")
struct DecisionTests {
    @Test func freshInstallShowsNothing() {
        #expect(decide("4.21", lastSeen: nil) == .none)
    }

    @Test func patchBumpShowsNothing() {
        #expect(decide("4.20.2", lastSeen: "4.20.1") == .none)
        #expect(decide("4.20.1", lastSeen: "4.20") == .none)
    }

    @Test func sameVersionShowsNothing() {
        #expect(decide("4.20", lastSeen: "4.20") == .none)
    }

    @Test func minorBumpEligibleShowsWhatsNewThenReview() {
        #expect(decide("4.21") == .whatsNewThenReview)
        #expect(decide("4.21.3", lastSeen: "4.20.1") == .whatsNewThenReview)
    }

    @Test func majorBumpCounts() {
        #expect(decide("5.0", lastSeen: "4.20") == .whatsNewThenReview)
    }

    @Test func downgradeShowsNothing() {
        #expect(decide("4.19", lastSeen: "4.20") == .none)
    }

    @Test func ineligibleUserShowsNothing() {
        #expect(decide("4.21", eligible: false) == .none)
    }

    @Test func missingReleaseNoteShowsNothing() {
        #expect(decide("4.21", hasNote: false) == .none)
    }

    @Test func reviewAlreadyShownThisVersionIsWhatsNewOnly() {
        #expect(decide("4.21", reviewShownFor: "4.21") == .whatsNewOnly)
        #expect(decide("4.21.1", reviewShownFor: "4.21") == .whatsNewOnly)
    }

    @Test func reviewShownForOlderVersionDoesNotBlock() {
        #expect(decide("4.21", reviewShownFor: "4.20") == .whatsNewThenReview)
    }

    @Test func cooldownActiveIsWhatsNewOnly() {
        #expect(decide("4.21", lastTap: now.addingTimeInterval(-364 * day)) == .whatsNewOnly)
        #expect(decide("4.21", lastTap: now.addingTimeInterval(-1 * day)) == .whatsNewOnly)
    }

    @Test func cooldownExpiredAllowsReview() {
        #expect(decide("4.21", lastTap: now.addingTimeInterval(-365 * day)) == .whatsNewThenReview)
        #expect(decide("4.21", lastTap: now.addingTimeInterval(-400 * day)) == .whatsNewThenReview)
    }

    @Test func futureDatedTapCountsAsCooldown() {
        #expect(decide("4.21", lastTap: now.addingTimeInterval(day)) == .whatsNewOnly)
    }

    @Test func installAgeGate() {
        #expect(decide("4.21", installedDaysAgo: 1.5) == .none)
        #expect(decide("4.21", installedDaysAgo: 2) == .whatsNewThenReview)
        #expect(decide("4.21", installedDaysAgo: 2.1) == .whatsNewThenReview)
        #expect(decide("4.21", installedDaysAgo: nil) == .none)
        #expect(decide("4.21", installedDaysAgo: 0.1, minimumAgeDays: 0) == .whatsNewThenReview)
    }

    @Test func reviewScreenCanBeDisabled() {
        #expect(decide("4.21", maxReviews: 0) == .whatsNewOnly)
    }

    @Test func yearBasedVersionScheme() {
        #expect(decide("2026.11", lastSeen: "2026.10.5") == .whatsNewThenReview)
        #expect(decide("2026.10.9", lastSeen: "2026.10.5") == .none)
        #expect(decide("2027.1", lastSeen: "2026.12.3") == .whatsNewThenReview)
    }

    @Test func malformedVersionStrings() {
        // Garbage parses as 0.0, so it never counts as an upgrade over a real version.
        #expect(decide("beta", lastSeen: "4.20") == .none)
        #expect(decide("", lastSeen: "4.20") == .none)
        // A real version over a garbage last-seen value counts as an upgrade.
        #expect(decide("4.21", lastSeen: "abc") == .whatsNewThenReview)
        #expect(decide("4.x", lastSeen: "4.0") == .none)
    }
}

@Suite("Version helper")
struct VersionTests {
    @Test func parsesMajorMinorOnly() {
        #expect(AfterglowVersion("4.20.1") == AfterglowVersion("4.20.2"))
        #expect(AfterglowVersion("4.20.1") == AfterglowVersion("4.20"))
        #expect(AfterglowVersion("4.20") != AfterglowVersion("4.21"))
        #expect(AfterglowVersion("4") == AfterglowVersion("4.0"))
        #expect(AfterglowVersion("4.2") < AfterglowVersion("4.10"))
        #expect(AfterglowVersion("5.0") > AfterglowVersion("4.99"))
    }

    @Test func minorChanged() {
        #expect(!AfterglowVersion.minorChanged("4.20.1", "4.20.2"))
        #expect(AfterglowVersion.minorChanged("4.20", "4.21"))
        #expect(AfterglowVersion.minorChanged("2026.10.5", "2026.11"))
    }

    @Test func nonNumericComponentsAreZero() {
        #expect(AfterglowVersion("a.b") == AfterglowVersion("0.0"))
        #expect(AfterglowVersion("4.beta") == AfterglowVersion("4.0"))
        #expect(AfterglowVersion("") == AfterglowVersion("0.0"))
        #expect(AfterglowVersion("-1.2") == AfterglowVersion("0.2"))
        #expect(AfterglowVersion("..") == AfterglowVersion("0.0"))
    }

    @Test func durationSeconds() {
        #expect(Duration.seconds(2 * 86_400).afterglowSeconds == 172_800)
        #expect(Duration.milliseconds(500).afterglowSeconds == 0.5)
    }
}

@Suite("Store")
struct StoreTests {
    @Test func inMemoryRoundTrip() {
        let store = InMemoryAfterglowStore()
        #expect(store.snapshot == AfterglowSnapshot())
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        store.lastSeenVersion = "4.20.1"
        store.reviewScreenShownForVersion = "4.20"
        store.lastWriteReviewTap = date
        store.firstLaunchDate = date
        #expect(store.snapshot == AfterglowSnapshot(
            lastSeenVersion: "4.20.1", reviewScreenShownForVersion: "4.20",
            lastWriteReviewTap: date, firstLaunchDate: date))
        store.removeAll()
        #expect(store.snapshot == AfterglowSnapshot())
    }

    @Test func userDefaultsRoundTripUsesPrefixedKeys() throws {
        let suite = "afterglow.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsAfterglowStore(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        store.lastSeenVersion = "4.20.1"
        store.reviewScreenShownForVersion = "4.20"
        store.lastWriteReviewTap = date
        store.firstLaunchDate = date

        let reread = UserDefaultsAfterglowStore(defaults: defaults)
        #expect(reread.lastSeenVersion == "4.20.1")
        #expect(reread.reviewScreenShownForVersion == "4.20")
        #expect(reread.lastWriteReviewTap == date)
        #expect(reread.firstLaunchDate == date)
        #expect(defaults.string(forKey: "afterglow.lastSeenVersion") == "4.20.1")
        #expect(defaults.string(forKey: "afterglow.reviewScreenShownForVersion") == "4.20")
        #expect(defaults.object(forKey: "afterglow.lastWriteReviewTap") as? Date == date)
        #expect(defaults.object(forKey: "afterglow.firstLaunchDate") as? Date == date)

        store.removeAll()
        #expect(reread.snapshot == AfterglowSnapshot())
    }
}
