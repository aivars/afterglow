import SwiftUI

struct ReviewSheet: View {
    let appName: String
    let communityLine: String?
    let testimonials: [Testimonial]
    let accent: Color
    let showsFeedback: Bool
    let writeReviewURL: URL?
    var ratingSummary: RatingSummary? = nil
    var minimumRatingCount: Int = 50
    var minimumRatingAverage: Double = 4.0

    let onWriteReview: () -> Void
    let onFeedback: () -> Void
    let onNotNow: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    @ScaledMetric(relativeTo: .largeTitle) private var laurelSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var ratingNumberSize: CGFloat = 46
    @ScaledMetric(relativeTo: .footnote) private var pillAvatarSize: CGFloat = 28
    @ScaledMetric(relativeTo: .subheadline) private var cardAvatarSize: CGFloat = 36

    private var visibleTestimonials: [Testimonial] { Array(testimonials.prefix(3)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ratingBadge

                VStack(spacing: 6) {
                    Text(L10n.helpGrow(appName))
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.madeForYou(appName))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    if let communityLine, !communityLine.isEmpty {
                        communityPill(communityLine)
                    }
                    Text(L10n.whyRate)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !visibleTestimonials.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(visibleTestimonials) { testimonial in
                            card(testimonial)
                        }
                    }
                }
            }
            .afterglowColumn()
            .padding(.horizontal, 24)
            .padding(.top, 24)
            // Without cards the content is short; a little extra air keeps it from touching the buttons.
            .padding(.bottom, visibleTestimonials.isEmpty ? 24 : 16)
            .frame(maxWidth: .infinity)
        }
        .afterglowBackground(accent: accent)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    if let writeReviewURL { openURL(writeReviewURL) }
                    onWriteReview()
                } label: {
                    Text(L10n.rate(appName))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .afterglowPrimaryButton(accent: accent)

                if showsFeedback {
                    Button(action: onFeedback) {
                        Text(L10n.sendFeedback)
                            .font(.subheadline)
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.borderless)
                }

                Button(action: onNotNow) {
                    Text(L10n.notNow)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .frame(maxWidth: AfterglowStyle.columnWidth)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 520)
        #endif
        .afterglowNavigationChrome()
    }

    // MARK: - Rating badge

    private var ratingBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "laurel.leading")
                .font(.system(size: laurelSize))
                .foregroundStyle(AfterglowStyle.gold)
                .accessibilityHidden(true)

            if case .summary(let averageText, let countText) = badgeContent {
                VStack(spacing: 2) {
                    Text(averageText)
                        .font(.system(size: ratingNumberSize, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    stars(font: .title3)
                    Text(countText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                stars(font: .title)
            }

            Image(systemName: "laurel.trailing")
                .font(.system(size: laurelSize))
                .foregroundStyle(AfterglowStyle.gold)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badgeAccessibilityLabel)
    }

    private var badgeContent: RatingBadgeContent {
        RatingBadgeContent.make(
            summary: ratingSummary,
            minimumCount: minimumRatingCount,
            minimumAverage: minimumRatingAverage,
            locale: .current
        )
    }

    private var badgeAccessibilityLabel: String {
        guard case .summary(let averageText, let countText) = badgeContent else { return L10n.fiveStars }
        return "\(L10n.ratedOutOfFive(averageText)), \(countText)"
    }

    private func stars(font: Font) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(font)
                    .foregroundStyle(AfterglowStyle.gold)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Community pill

    private func communityPill(_ line: String) -> some View {
        HStack(spacing: 10) {
            if !visibleTestimonials.isEmpty {
                HStack(spacing: -10) {
                    ForEach(Array(visibleTestimonials.enumerated()), id: \.element.id) { index, testimonial in
                        Text(afterglowInitials(testimonial.author))
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .frame(width: pillAvatarSize, height: pillAvatarSize)
                            .background(accent.opacity([0.9, 0.7, 0.5][index]), in: Circle())
                            .overlay(Circle().stroke(AfterglowStyle.card, lineWidth: 2))
                            .zIndex(Double(visibleTestimonials.count - index))
                    }
                }
                .accessibilityHidden(true)
            }
            Text(line)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .background(AfterglowStyle.card, in: Capsule())
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Testimonial card

    private func card(_ testimonial: Testimonial) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(afterglowInitials(testimonial.author))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: cardAvatarSize, height: cardAvatarSize)
                    .background(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    Text(testimonial.author)
                        .font(.subheadline.weight(.semibold))
                    Text(testimonial.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                HStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(AfterglowStyle.gold)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(L10n.fiveStars)
            }

            Text("\u{201C}\(testimonial.quote)\u{201D}")
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .afterglowCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview("Review") {
    ReviewSheet(
        appName: "Demo",
        communityLine: "Join 6,000 people using Demo",
        testimonials: [
            Testimonial(quote: "Finally an app that makes my routine make sense.", author: "Scott E.", source: "App Store"),
            Testimonial(quote: "Simple, clear and it keeps me honest every day.", author: "Maria L.", source: "App Store"),
        ],
        accent: .teal,
        showsFeedback: true,
        writeReviewURL: nil,
        ratingSummary: RatingSummary(average: 4.8, count: 6059),
        onWriteReview: {},
        onFeedback: {},
        onNotNow: {}
    )
}

#Preview("Review, no testimonials") {
    ReviewSheet(
        appName: "Demo",
        communityLine: "Join 6,000+ people using Demo",
        testimonials: [],
        accent: .teal,
        showsFeedback: true,
        writeReviewURL: nil,
        ratingSummary: RatingSummary(average: 4.8, count: 6059),
        onWriteReview: {},
        onFeedback: {},
        onNotNow: {}
    )
}

#Preview("Review, bare") {
    ReviewSheet(
        appName: "Demo",
        communityLine: nil,
        testimonials: [],
        accent: .teal,
        showsFeedback: false,
        writeReviewURL: nil,
        ratingSummary: RatingSummary(average: 4.8, count: 12),
        onWriteReview: {},
        onFeedback: {},
        onNotNow: {}
    )
}
