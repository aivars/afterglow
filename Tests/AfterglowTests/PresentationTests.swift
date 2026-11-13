import Foundation
import Testing
@testable import Afterglow

@Suite("Rating badge content")
struct RatingBadgeTests {
    let en = Locale(identifier: "en_US")
    let de = Locale(identifier: "de_DE")

    private func make(_ average: Double, _ count: Int, locale: Locale? = nil, minCount: Int = 50, minAverage: Double = 4.0) -> RatingBadgeContent {
        RatingBadgeContent.make(
            summary: RatingSummary(average: average, count: count),
            minimumCount: minCount,
            minimumAverage: minAverage,
            locale: locale ?? en
        )
    }

    private func texts(_ content: RatingBadgeContent) -> (String, String)? {
        if case .summary(let a, let c) = content { return (a, c) }
        return nil
    }

    /// A count summed over every storefront is larger than what the App Store shows any one
    /// person, so the badge says so; a storefront count keeps the plain wording.
    @Test func worldwideScopeIsLabelled() {
        let worldwide = RatingBadgeContent.make(
            summary: RatingSummary(average: 4.8, count: 6073, scope: .worldwide),
            minimumCount: 50, minimumAverage: 4.0, locale: en
        )
        #expect(texts(worldwide)?.1.contains("worldwide") == true)
        #expect(texts(worldwide)?.1.contains("6,000+") == true)
        #expect(texts(make(4.8, 6073))?.1.contains("worldwide") == false)
    }

    @Test func nilSummaryIsStarsOnly() {
        #expect(RatingBadgeContent.make(summary: nil, minimumCount: 50, minimumAverage: 4.0, locale: en) == .starsOnly)
    }

    @Test func belowMinimumCountIsStarsOnly() {
        #expect(make(4.8, 49) == .starsOnly)
        #expect(texts(make(4.8, 50)) != nil)
    }

    @Test func belowMinimumAverageIsStarsOnly() {
        #expect(make(3.9, 6000) == .starsOnly)
        #expect(texts(make(4.0, 6000)) != nil)
    }

    @Test func customThresholds() {
        #expect(texts(make(3.5, 10, minCount: 5, minAverage: 3.0)) != nil)
        #expect(make(3.5, 10, minCount: 11, minAverage: 3.0) == .starsOnly)
    }

    @Test func roundsDownToThousands() {
        #expect(texts(make(4.8, 6059))?.1.contains("6,000+") == true)
        #expect(texts(make(4.8, 1000))?.1.contains("1,000+") == true)
        #expect(texts(make(4.8, 999_999))?.1.contains("999,000+") == true)
    }

    @Test func roundsDownToHundreds() {
        #expect(texts(make(4.8, 348))?.1.contains("300+") == true)
        #expect(texts(make(4.8, 100))?.1.contains("100+") == true)
        #expect(texts(make(4.8, 999))?.1.contains("900+") == true)
    }

    @Test func smallCountsAreExact() {
        #expect(texts(make(4.8, 72))?.1.contains("72") == true)
        #expect(texts(make(4.8, 72))?.1.contains("+") == false)
        #expect(texts(make(4.8, 99))?.1.contains("99") == true)
    }

    @Test func formatsAverageAndCountPerLocale() {
        #expect(texts(make(4.8, 6059, locale: en))?.0 == "4.8")
        #expect(texts(make(4.8, 6059, locale: de))?.0 == "4,8")
        #expect(texts(make(4.8, 6059, locale: de))?.1.contains("6.000+") == true)
        #expect(texts(make(4.8, 6059, locale: en))?.1.contains("6.000") == false)
    }

    @Test func averageUsesOneFractionDigit() {
        #expect(texts(make(4, 6059))?.0 == "4.0")
        #expect(texts(make(4.84, 6059))?.0 == "4.8")
    }
}

@Suite("Initials")
struct InitialsTests {
    @Test(arguments: [
        ("Donnie", "D"),
        ("Scott E.", "SE"),
        ("ingelbertina", "I"),
        ("Grand Master WillemJan", "GM"),
        ("@jason", "J"),
        ("김민준", "김"),
        ("王小明", "王"),
        ("", "\u{2605}"),
        ("   ", "\u{2605}"),
        ("@", "\u{2605}"),
        ("élodie b", "ÉB"),
    ])
    func initials(name: String, expected: String) {
        #expect(afterglowInitials(name) == expected)
    }
}

@Suite("Row icons")
struct RowIconTests {
    @Test func existingSymbolIsKept() {
        #expect(AfterglowImage.resolvedSystemName(for: "tablecells", exists: { _ in true }) == "tablecells")
    }

    @Test func missingSymbolFallsBackToSparkles() {
        #expect(AfterglowImage.resolvedSystemName(for: "tablecels", exists: { $0 == "tablecells" }) == "sparkles")
        #expect(AfterglowImage.resolvedSystemName(for: "", exists: { _ in false }) == "sparkles")
    }

    @Test func itemInitializersWrapTheImage() {
        let a = ReleaseNote.Item(systemImage: "bell.fill", headline: "H", detail: "D")
        let b = ReleaseNote.Item(image: .named("Logo"), headline: "H2", detail: "D")
        if case .system(let name) = a.image { #expect(name == "bell.fill") } else { Issue.record("expected .system") }
        if case .named(let name) = b.image { #expect(name == "Logo") } else { Issue.record("expected .named") }
    }

    @Test func realSymbolsResolveOnThisOS() {
        #expect(AfterglowImage.systemSymbolExists("star.fill"))
        #expect(!AfterglowImage.systemSymbolExists("definitely.not.a.symbol"))
    }
}
