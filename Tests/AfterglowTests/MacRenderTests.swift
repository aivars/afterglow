#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import Afterglow

/// Smoke tests that prove the sheets build and lay out on macOS. They render the views offscreen with
/// `ImageRenderer` and check that a non-empty image comes back.
///
/// `ImageRenderer` does not rasterize `ScrollView` content, so the images show the background and the
/// pinned bottom bar only; that is enough to prove the views compile and lay out, not to check pixels.
@MainActor
@Suite("macOS rendering")
struct MacRenderTests {
    private func render<V: View>(_ view: V) throws -> (cgImage: CGImage, nsImage: NSImage) {
        let renderer = ImageRenderer(content: view.frame(width: 600, height: 800))
        renderer.scale = 1
        let cgImage = try #require(renderer.cgImage)
        let nsImage = try #require(renderer.nsImage)
        return (cgImage, nsImage)
    }

    @Test func whatsNewSheetRenders() throws {
        let (cgImage, nsImage) = try render(
            WhatsNewSheet(note: .preview, accent: .teal, onContinue: {})
        )
        #expect(cgImage.width > 0 && cgImage.height > 0)
        #expect(nsImage.size.width > 0 && nsImage.size.height > 0)
    }

    @Test func reviewSheetRenders() throws {
        let (cgImage, nsImage) = try render(
            ReviewSheet(
                appName: "Demo",
                communityLine: "Join 6,000 people using Demo",
                testimonials: [
                    Testimonial(quote: "Finally an app that makes my routine make sense.", author: "Scott E.", source: "App Store"),
                ],
                accent: .teal,
                showsFeedback: true,
                writeReviewURL: nil,
                ratingSummary: RatingSummary(average: 4.8, count: 6059),
                onWriteReview: {},
                onFeedback: {},
                onNotNow: {}
            )
        )
        #expect(cgImage.width > 0 && cgImage.height > 0)
        #expect(nsImage.size.width > 0 && nsImage.size.height > 0)
    }
}
#endif
