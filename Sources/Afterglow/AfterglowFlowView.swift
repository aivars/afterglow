import SwiftUI

/// Root of the single Afterglow sheet: What's New, with the review screen pushed on top of it.
struct AfterglowFlowView: View {
    @Bindable var afterglow: Afterglow
    let configuration: AfterglowConfiguration
    let note: ReleaseNote

    var body: some View {
        NavigationStack(path: $afterglow.path) {
            WhatsNewSheet(
                note: note,
                accent: configuration.accent,
                heroImage: configuration.heroImage,
                onContinue: afterglow.whatsNewContinueTapped
            )
            .navigationDestination(for: AfterglowStep.self) { step in
                switch step {
                case .review:
                    ReviewSheet(
                        appName: configuration.appName,
                        communityLine: configuration.communityLine,
                        testimonials: configuration.testimonials,
                        accent: configuration.accent,
                        showsFeedback: configuration.feedbackAction != nil,
                        writeReviewURL: configuration.writeReviewURL,
                        ratingSummary: configuration.ratingSummary,
                        minimumRatingCount: configuration.minimumRatingCount,
                        minimumRatingAverage: configuration.minimumRatingAverage,
                        onWriteReview: afterglow.writeReviewTapped,
                        onFeedback: afterglow.feedbackTapped,
                        onNotNow: afterglow.notNowTapped
                    )
                }
            }
        }
        .afterglowPresentation()
    }
}

#Preview("Flow") {
    AfterglowFlowView(
        afterglow: Afterglow(),
        configuration: AfterglowConfiguration(
            appStoreID: "id000000000",
            appName: "Demo",
            releaseNotes: [.preview],
            testimonials: [
                Testimonial(quote: "Finally an app that makes my routine make sense.", author: "Scott E.", source: "App Store"),
            ],
            communityLine: "Join 6,000 people using Demo",
            accent: .teal,
            ratingSummary: RatingSummary(average: 4.8, count: 6059)
        ),
        note: .preview
    )
}
