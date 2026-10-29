import Afterglow
import SwiftUI
import UIKit

/// Demo home screen for exercising Afterglow, including on iPad.
///
/// Launch arguments (pass after the bundle id with `xcrun simctl launch`):
/// - `--afterglow-demo`: reset, pretend the user updated from 1.0 (the app is 1.1), and let the full flow fire on activation.
/// - `--afterglow-review`: reset, then present the review screen directly with `presentReview()`.
/// - `--landscape`: ask the window scene for landscape on first appear.
struct ContentView: View {
    @State private var showFeedbackAlert = false
    @State private var events = EventLog()

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    ForEach(Self.rows, id: \.title) { row in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                Text(row.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: row.symbol)
                        }
                    }
                }

                Section("Afterglow events") {
                    if events.items.isEmpty {
                        Text("No events yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(events.items.enumerated()), id: \.offset) { index, name in
                            Text("\(index + 1). \(name)")
                                .font(.footnote.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Demo")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Simulate upgrade") {
                            Afterglow.shared.reset()
                            Afterglow.shared.seedExistingUser(lastSeenVersion: "1.0")
                            Afterglow.shared.evaluateOnActive()
                        }
                        Button("Show What's New") { Afterglow.shared.presentWhatsNew() }
                        Button("Show review screen") { Afterglow.shared.presentReview() }
                        Button("Reset", role: .destructive) {
                            Afterglow.shared.reset()
                            events.items.removeAll()
                        }
                    } label: {
                        Label("Afterglow", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .afterglow(configuration)
        .alert("Feedback", isPresented: $showFeedbackAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This is where the host app would show its feedback form.")
        }
        .onAppear { applyLaunchArguments() }
    }

    // MARK: - Configuration

    private var configuration: AfterglowConfiguration {
        let log = events
        return AfterglowConfiguration(
            appStoreID: "id000000000",
            appName: "Demo",
            releaseNotes: Self.releaseNotes,
            testimonials: Self.testimonials,
            communityLine: "Join 12,000 people using Demo",
            feedbackAction: { showFeedbackAlert.toggle() },
            onEvent: { event in
                Task { @MainActor in log.items.append(event.rawValue) }
            },
            ratingSummary: RatingSummary(average: 4.8, count: 12345),
            heroImage: .system("sparkles")
        )
    }

    private static let releaseNotes = [
        ReleaseNote(version: "1.0", title: "Welcome to Demo", items: [
            .init(systemImage: "house.fill", headline: "A home for everything", detail: "Your day at a glance."),
            .init(systemImage: "bell.fill", headline: "Gentle reminders", detail: "Nudges that fit your routine."),
            .init(systemImage: "lock.fill", headline: "Private by default", detail: "Your data stays on your device."),
        ]),
        ReleaseNote(version: "1.1", title: "Made for iPad too", items: [
            .init(systemImage: "ipad.landscape", headline: "Room to breathe", detail: "A layout that makes use of the bigger screen."),
            .init(systemImage: "rectangle.portrait.rotate", headline: "Any orientation", detail: "Portrait or landscape, it just fits."),
            .init(systemImage: "sparkles", headline: "Small polish", detail: "Smoother animations and a few fixes."),
        ]),
    ]

    private static let testimonials = [
        Testimonial(quote: "Demo quote: simple, calm and it does exactly what I need.", author: "Alex P.", source: "Demo review"),
        Testimonial(quote: "Demo quote: the update feels great on my iPad.", author: "Maria L.", source: "Demo review"),
        Testimonial(quote: "Demo quote: I open it every single morning.", author: "Sam K.", source: "Demo review"),
    ]

    private static let rows: [(title: String, subtitle: String, symbol: String)] = [
        ("Morning routine", "Fake demo content", "sun.max.fill"),
        ("Weekly summary", "Fake demo content", "chart.bar.fill"),
        ("Reminders", "Fake demo content", "bell.fill"),
        ("Settings", "Fake demo content", "gearshape.fill"),
    ]

    // MARK: - Launch arguments

    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--landscape") { requestLandscape() }
        // The `--afterglow-demo` reset and seed happen in `AfterglowExampleApp.init`, before the first evaluation.
        if args.contains("--afterglow-review") {
            Afterglow.shared.configure(configuration)
            Afterglow.shared.presentReview()
        }
    }

    private func requestLandscape() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeLeft)) { error in
            NSLog("AfterglowExample: landscape request failed: \(error.localizedDescription)")
        }
    }
}

/// Reference-type log so the configuration's `@Sendable` event closure can append to it.
@MainActor @Observable
final class EventLog {
    var items: [String] = []
}

#Preview {
    ContentView()
}
