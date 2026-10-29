import Foundation
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Coordinates the update-moment flow: What's New, then (at most once per minor version) a review sheet.
///
/// Install it with `.afterglow(configuration)` on the root view. Everything else is optional.
@MainActor
@Observable
public final class Afterglow {
    /// The shared coordinator that the `.afterglow` modifier and your Settings rows talk to.
    public static let shared = Afterglow()

    // MARK: Presentation state (read by the view modifier)

    /// The one sheet. What's New is its root; the review screen is pushed onto `path`.
    var isSheetPresented = false
    /// Navigation stack contents inside the sheet: empty shows What's New, `[.review]` shows the review screen.
    var path: [AfterglowStep] = []
    private(set) var activeNote: ReleaseNote?
    private(set) var systemPromptRequested = false
    private(set) var configuration: AfterglowConfiguration?

    /// Set once by the `.afterglow` modifier from `@Environment(\.requestReview)`.
    @ObservationIgnored var requestReview: (@MainActor () -> Void)?

    @ObservationIgnored private var pendingReview = false
    @ObservationIgnored private var reviewShown = false
    @ObservationIgnored private var reviewResolved = false
    @ObservationIgnored private var pendingFeedback = false
    @ObservationIgnored private var promptTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    @ObservationIgnored private let store: any AfterglowStore
    @ObservationIgnored private let currentVersion: @Sendable () -> String
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let sleep: @Sendable (Duration) async -> Void

    /// True while the Afterglow sheet is up (What's New and, if pushed, the review screen), so the
    /// host can defer its own sheets.
    public var isPresenting: Bool { isSheetPresented }

    /// Creates a coordinator that keeps its state in `UserDefaults.standard` and reads the running app's `CFBundleShortVersionString`.
    public convenience init() {
        self.init(
            store: UserDefaultsAfterglowStore(),
            currentVersion: Afterglow.bundleVersion,
            now: { Date() }
        )
    }

    init(
        store: any AfterglowStore,
        currentVersion: @escaping @Sendable () -> String,
        now: @escaping @Sendable () -> Date,
        sleep: @escaping @Sendable (Duration) async -> Void = { duration in
            try? await Task.sleep(for: duration)
        }
    ) {
        self.store = store
        self.currentVersion = currentVersion
        self.now = now
        self.sleep = sleep
    }

    static let bundleVersion: @Sendable () -> String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    // MARK: Public API

    /// Stores the configuration used by every later evaluation. The `.afterglow` modifier calls this for you.
    public func configure(_ configuration: AfterglowConfiguration) {
        self.configuration = configuration
    }

    /// Call when the app becomes active. The `.afterglow` modifier does this for you.
    public func evaluateOnActive() {
        guard let configuration, !isPresenting else { return }

        let timestamp = now()
        if store.firstLaunchDate == nil { store.firstLaunchDate = timestamp }

        // Another cover is up: try again next time, record nothing about the version.
        guard configuration.canPresent() else { return }

        let version = currentVersion()
        let decision = AfterglowDecision.decide(
            currentVersion: version,
            snapshot: store.snapshot,
            isEligibleUser: configuration.policy.isEligibleUser(),
            minimumInstallAge: configuration.policy.minimumInstallAge,
            reviewCooldown: configuration.policy.reviewCooldown,
            maxReviewScreensPerVersion: configuration.policy.maxReviewScreensPerVersion,
            now: timestamp,
            hasReleaseNote: Self.note(for: version, in: configuration.releaseNotes) != nil
        )

        recordSeen(version)

        switch decision {
        case .none:
            break
        case .whatsNewOnly:
            presentWhatsNew(version: version, thenReview: false)
        case .whatsNewThenReview:
            presentWhatsNew(version: version, thenReview: true)
        }
    }

    /// Shows the What's New sheet on demand (Settings → "What's new"). Uses the note for the
    /// running version, or the newest note if there is none. Does not follow up with the review sheet.
    public func presentWhatsNew() {
        guard let configuration, !isPresenting else { return }
        let version = currentVersion()
        let note = Self.note(for: version, in: configuration.releaseNotes)
            ?? configuration.releaseNotes.max { AfterglowVersion($0.version) < AfterglowVersion($1.version) }
        guard let note else { return }
        show(note: note, thenReview: false)
    }

    /// Shows the sheet with the review screen already pushed (Settings -> "Rate <app>"). The back button
    /// reveals What's New for the running version (or the newest note). It records the review screen
    /// as shown for this version, emits `reviewScreenShown`, and follows the same dismissal rules as the
    /// automatic flow: "Not now" or a swipe requests the system prompt after `promptDelay`, "Rate" and
    /// "Send feedback" do not. Ignores the per-version and cooldown rules, because the user asked for it.
    public func presentReview() {
        guard let configuration, !isPresenting else { return }
        let version = currentVersion()
        let note = Self.note(for: version, in: configuration.releaseNotes)
            ?? configuration.releaseNotes.max { AfterglowVersion($0.version) < AfterglowVersion($1.version) }
        guard let note else { return }
        activeNote = note
        pendingReview = true
        reviewShown = false
        reviewResolved = true
        pendingFeedback = false
        systemPromptRequested = false
        markReviewScreenShown()
        path = [.review]
        isSheetPresented = true
    }

    /// Opens the App Store write-review page. A tap must never call `requestReview`, so this is a plain deep link.
    public func openWriteReview() {
        guard let configuration, let url = configuration.writeReviewURL else { return }
        recordWriteReviewTap()
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    /// Forgets everything (debug menu). The next launch behaves like a fresh install.
    public func reset() {
        store.removeAll()
        promptTask?.cancel()
        feedbackTask?.cancel()
        promptTask = nil
        feedbackTask = nil
        isSheetPresented = false
        path = []
        pendingReview = false
        reviewShown = false
        reviewResolved = false
        pendingFeedback = false
        systemPromptRequested = false
        activeNote = nil
    }

    /// For apps that shipped before adding Afterglow: call once at launch, before the first
    /// evaluation, when you know the user is an existing one (for instance onboarding is
    /// already completed). Marks the user as having seen `version` and as an old install, so the
    /// first release that carries Afterglow can show its notes. Does nothing if state already exists.
    public func seedExistingUser(lastSeenVersion version: String) {
        if store.lastSeenVersion == nil { store.lastSeenVersion = version }
        if store.firstLaunchDate == nil { store.firstLaunchDate = .distantPast }
    }

    // MARK: Used by the sheet

    func emit(_ event: AfterglowEvent) {
        configuration?.onEvent?(event)
    }

    /// What's New's Continue: pushes the review screen when one follows, otherwise dismisses the sheet.
    func whatsNewContinueTapped() {
        guard pendingReview else {
            isSheetPresented = false
            return
        }
        if !reviewShown { markReviewScreenShown() }
        path = [.review]
    }

    private func markReviewScreenShown() {
        reviewShown = true
        reviewResolved = false
        pendingFeedback = false
        systemPromptRequested = false
        store.reviewScreenShownForVersion = currentVersion()
        emit(.reviewScreenShown)
    }

    func markSystemPromptRequested() {
        guard !systemPromptRequested else { return }
        systemPromptRequested = true
        emit(.systemPromptRequested)
    }

    func recordWriteReviewTap() {
        store.lastWriteReviewTap = now()
        reviewResolved = true
        emit(.writeReviewTapped)
    }

    func writeReviewTapped() {
        recordWriteReviewTap()
        isSheetPresented = false
    }

    func feedbackTapped() {
        reviewResolved = true
        pendingFeedback = true
        emit(.feedbackTapped)
        isSheetPresented = false
    }

    func notNowTapped() {
        isSheetPresented = false
    }

    /// Runs from the sheet's `onDismiss`, whatever caused the dismissal (button or swipe).
    func sheetDidDismiss() {
        let leftReviewUnresolved = reviewShown && !reviewResolved
        let runFeedback = pendingFeedback
        pendingReview = false
        reviewShown = false
        reviewResolved = true
        pendingFeedback = false
        path = []

        if leftReviewUnresolved {
            emit(.dismissed)
            schedulePrompt()
        }
        if runFeedback { scheduleFeedback() }
    }

    /// Waits for work scheduled after a dismissal (the system prompt, the feedback action). For tests.
    func waitForPendingWork() async {
        await promptTask?.value
        await feedbackTask?.value
    }

    /// Requests Apple's rating prompt a moment after the sheet is gone, never while it is on screen.
    private func schedulePrompt() {
        let delay = configuration?.policy.promptDelay ?? .milliseconds(600)
        promptTask?.cancel()
        promptTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.sleep(delay)
            // Skip if the user is already looking at another Afterglow sheet.
            guard !Task.isCancelled, !self.isSheetPresented, let request = self.requestReview else { return }
            request()
            self.markSystemPromptRequested()
        }
    }

    private func scheduleFeedback() {
        feedbackTask?.cancel()
        // Let the sheet finish leaving before the host presents its own.
        feedbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.sleep(.milliseconds(100))
            guard !Task.isCancelled else { return }
            self.configuration?.feedbackAction?()
        }
    }

    // MARK: Internals

    static func note(for version: String, in notes: [ReleaseNote]) -> ReleaseNote? {
        let target = AfterglowVersion(version)
        return notes.first { AfterglowVersion($0.version) == target }
    }

    private func recordSeen(_ version: String) {
        if let last = store.lastSeenVersion, AfterglowVersion(version) < AfterglowVersion(last) { return }
        store.lastSeenVersion = version
    }

    private func presentWhatsNew(version: String, thenReview: Bool) {
        guard let note = Self.note(for: version, in: configuration?.releaseNotes ?? []) else { return }
        show(note: note, thenReview: thenReview)
    }

    private func show(note: ReleaseNote, thenReview: Bool) {
        activeNote = note
        pendingReview = thenReview
        reviewShown = false
        reviewResolved = true
        pendingFeedback = false
        systemPromptRequested = false
        path = []
        isSheetPresented = true
        emit(.whatsNewShown)
    }
}

/// Screens pushed onto the Afterglow sheet's navigation stack.
enum AfterglowStep: Hashable {
    case review
}
