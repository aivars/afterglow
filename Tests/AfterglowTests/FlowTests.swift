import Foundation
import Testing
@testable import Afterglow

final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AfterglowEvent] = []
    func add(_ e: AfterglowEvent) { lock.lock(); storage.append(e); lock.unlock() }
    var events: [AfterglowEvent] { lock.lock(); defer { lock.unlock() }; return storage }
}

final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_800_000_000)
    var date: Date { lock.lock(); defer { lock.unlock() }; return value }
    func advance(days: Double) { lock.lock(); value.addTimeInterval(days * 86_400); lock.unlock() }
}

@MainActor final class Gate { var open = false }

/// Counts calls to the injected `requestReview` closure and records the event log at call time.
@MainActor final class PromptSpy {
    private(set) var count = 0
    func call() { count += 1 }
}

/// Records every duration the coordinator asked to sleep, without sleeping.
final class SleepLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Duration] = []
    func add(_ d: Duration) { lock.lock(); storage.append(d); lock.unlock() }
    var durations: [Duration] { lock.lock(); defer { lock.unlock() }; return storage }
}

func note(_ version: String) -> ReleaseNote {
    ReleaseNote(version: version, title: "Title \(version)", items: [
        .init(systemImage: "star", headline: "Headline", detail: "Detail")
    ])
}

@MainActor
@Suite("Afterglow flow")
struct FlowTests {
    let store = InMemoryAfterglowStore()
    let clock = Clock()
    let log = EventLog()
    let spy = PromptSpy()
    let sleeps = SleepLog()

    private func makeModel(version: String, canPresent: @escaping @MainActor () -> Bool = { true }) -> Afterglow {
        let model = Afterglow(
            store: store,
            currentVersion: { version },
            now: { clock.date },
            sleep: { [sleeps] in sleeps.add($0) }
        )
        model.requestReview = { [spy, log] in
            // The prompt must come after .dismissed.
            #expect(log.events.last == .dismissed)
            spy.call()
        }
        model.configure(AfterglowConfiguration(
            appStoreID: "id123456",
            appName: "Test",
            releaseNotes: [note("4.21"), note("4.22")],
            feedbackAction: {},
            onEvent: { log.add($0) },
            policy: AfterglowPolicy(isEligibleUser: { true }),
            canPresent: canPresent
        ))
        return model
    }

    /// Installs 4.20, ages the install, then returns a model running 4.21.
    private func upgradedModel(canPresent: @escaping @MainActor () -> Bool = { true }) -> Afterglow {
        let old = makeModel(version: "4.20")
        old.evaluateOnActive()
        clock.advance(days: 5)
        return makeModel(version: "4.21", canPresent: canPresent)
    }

    @Test func freshInstallRecordsAndShowsNothing() {
        let model = makeModel(version: "4.21")
        model.evaluateOnActive()
        #expect(!model.isPresenting)
        #expect(store.lastSeenVersion == "4.21")
        #expect(store.firstLaunchDate == clock.date)
        #expect(log.events.isEmpty)
    }

    /// Upgrades to 4.21, shows What's New and pushes the review screen.
    private func modelOnReviewScreen() -> Afterglow {
        let model = upgradedModel()
        model.evaluateOnActive()
        model.whatsNewContinueTapped()
        return model
    }

    @Test func upgradeShowsWhatsNewThenPushesReview() {
        let model = upgradedModel()
        model.evaluateOnActive()
        #expect(model.isSheetPresented)
        #expect(model.path.isEmpty)
        #expect(model.isPresenting)
        #expect(model.activeNote?.version == "4.21")
        #expect(store.lastSeenVersion == "4.21")

        model.whatsNewContinueTapped()
        #expect(model.isSheetPresented)
        #expect(model.isPresenting)
        #expect(model.path == [.review])
        #expect(store.reviewScreenShownForVersion == "4.21")
        #expect(log.events == [.whatsNewShown, .reviewScreenShown])
        #expect(spy.count == 0)
    }

    @Test func writeReviewTapRequestsNoSystemPrompt() async {
        let model = modelOnReviewScreen()
        model.writeReviewTapped()
        #expect(!model.isSheetPresented)
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        #expect(!model.isPresenting)
        #expect(model.path.isEmpty)
        #expect(store.lastWriteReviewTap == clock.date)
        #expect(spy.count == 0)
        #expect(log.events == [.whatsNewShown, .reviewScreenShown, .writeReviewTapped])
    }

    @Test func swipingAwayWhatsNewSkipsReviewAndEmitsNothing() async {
        let model = upgradedModel()
        model.evaluateOnActive()
        model.isSheetPresented = false // swipe down
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        #expect(!model.isPresenting)
        #expect(store.reviewScreenShownForVersion == nil)
        #expect(spy.count == 0)
        #expect(log.events == [.whatsNewShown])
    }

    @Test func notNowEmitsDismissedThenRequestsSystemPromptAfterDelay() async {
        let model = modelOnReviewScreen()
        model.notNowTapped()
        #expect(!model.isSheetPresented)
        #expect(spy.count == 0, "nothing is requested before the sheet is gone")
        model.sheetDidDismiss()
        #expect(spy.count == 0, "the request waits for the delay")
        await model.waitForPendingWork()
        #expect(spy.count == 1)
        #expect(sleeps.durations == [.milliseconds(600)])
        #expect(log.events == [.whatsNewShown, .reviewScreenShown, .dismissed, .systemPromptRequested])
    }

    @Test func swipingAwayReviewCountsAsDismissal() async {
        let model = modelOnReviewScreen()
        model.isSheetPresented = false // swipe down on the review screen
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        #expect(spy.count == 1)
        #expect(log.events == [.whatsNewShown, .reviewScreenShown, .dismissed, .systemPromptRequested])
    }

    @Test func goingBackThenSwipingAwayCountsAsDismissal() async {
        let model = modelOnReviewScreen()
        model.path = [] // back button
        model.isSheetPresented = false
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        #expect(spy.count == 1)
        #expect(log.events == [.whatsNewShown, .reviewScreenShown, .dismissed, .systemPromptRequested])
    }

    @Test func reopeningReviewAfterBackDoesNotRepeatTheShownEvent() {
        let model = modelOnReviewScreen()
        model.path = []
        model.whatsNewContinueTapped()
        #expect(model.path == [.review])
        #expect(log.events.filter { $0 == .reviewScreenShown }.count == 1)
    }

    @Test func promptDelayFollowsPolicy() async {
        let old = makeModel(version: "4.20")
        old.evaluateOnActive()
        clock.advance(days: 5)
        let model = Afterglow(
            store: store, currentVersion: { "4.21" }, now: { clock.date },
            sleep: { [sleeps] in sleeps.add($0) }
        )
        model.requestReview = { [spy] in spy.call() }
        model.configure(AfterglowConfiguration(
            appStoreID: "1", appName: "Test", releaseNotes: [note("4.21")],
            policy: AfterglowPolicy(isEligibleUser: { true }, promptDelay: .seconds(2))
        ))
        model.evaluateOnActive()
        model.whatsNewContinueTapped()
        model.notNowTapped()
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        #expect(sleeps.durations == [.seconds(2)])
        #expect(spy.count == 1)
    }

    @Test func noSystemPromptWithoutRequestReviewClosure() async {
        let model = modelOnReviewScreen()
        model.requestReview = nil
        model.notNowTapped()
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        #expect(log.events == [.whatsNewShown, .reviewScreenShown, .dismissed])
    }

    @Test func feedbackEmitsEventRunsActionAndNeverPrompts() async {
        let ran = Gate()
        let old = makeModel(version: "4.20")
        old.evaluateOnActive()
        clock.advance(days: 5)
        let model = Afterglow(
            store: store, currentVersion: { "4.21" }, now: { clock.date },
            sleep: { [sleeps] in sleeps.add($0) }
        )
        model.requestReview = { [spy] in spy.call() }
        model.configure(AfterglowConfiguration(
            appStoreID: "1", appName: "Test", releaseNotes: [note("4.21")],
            feedbackAction: { ran.open = true },
            onEvent: { [log] in log.add($0) },
            policy: AfterglowPolicy(isEligibleUser: { true })
        ))
        model.evaluateOnActive()
        model.whatsNewContinueTapped()
        model.feedbackTapped()
        #expect(!model.isSheetPresented)
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        #expect(ran.open)
        #expect(spy.count == 0)
        #expect(log.events == [.whatsNewShown, .reviewScreenShown, .feedbackTapped])
        #expect(store.lastWriteReviewTap == nil)
    }

    @Test func secondEvaluationDoesNotRepeat() async {
        let model = modelOnReviewScreen()
        model.notNowTapped()
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        let before = log.events.count
        model.evaluateOnActive()
        #expect(!model.isPresenting)
        #expect(log.events.count == before)
    }

    @Test func canPresentFalseRecordsNothing() {
        let gate = Gate()
        let model = upgradedModel(canPresent: { gate.open })
        model.evaluateOnActive()
        #expect(!model.isPresenting)
        #expect(store.lastSeenVersion == "4.20")

        gate.open = true
        model.evaluateOnActive()
        #expect(model.isSheetPresented)
    }

    @Test func ineligibleUserStillRecordsVersion() {
        let old = makeModel(version: "4.20")
        old.evaluateOnActive()
        clock.advance(days: 5)
        let model = Afterglow(store: store, currentVersion: { "4.21" }, now: { clock.date })
        model.configure(AfterglowConfiguration(
            appStoreID: "1", appName: "Test", releaseNotes: [note("4.21")],
            policy: AfterglowPolicy(isEligibleUser: { false })
        ))
        model.evaluateOnActive()
        #expect(!model.isPresenting)
        #expect(store.lastSeenVersion == "4.21")
    }

    @Test func presentWhatsNewOnDemandHasNoReview() async {
        let model = makeModel(version: "4.30") // no note for 4.30: falls back to newest
        model.presentWhatsNew()
        #expect(model.isSheetPresented)
        #expect(model.activeNote?.version == "4.22")
        model.whatsNewContinueTapped()
        #expect(!model.isSheetPresented, "Continue dismisses when no review follows")
        #expect(model.path.isEmpty)
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        #expect(spy.count == 0)
        #expect(log.events == [.whatsNewShown])
    }

    @Test func presentReviewOnDemandOpensOnReviewStepAndPromptsAfterNotNow() async {
        let model = makeModel(version: "4.21")
        model.presentReview()
        #expect(model.isSheetPresented)
        #expect(model.path == [.review], "the sheet opens directly on the review step")
        #expect(store.reviewScreenShownForVersion == "4.21")
        #expect(log.events == [.reviewScreenShown], "no What's New event when the review screen is asked for")

        model.notNowTapped()
        #expect(!model.isSheetPresented)
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        #expect(spy.count == 1)
        #expect(log.events == [.reviewScreenShown, .dismissed, .systemPromptRequested])
    }

    @Test func presentReviewOnDemandRateTapNeverPrompts() async {
        let model = makeModel(version: "4.21")
        model.presentReview()
        model.writeReviewTapped()
        #expect(!model.isSheetPresented)
        #expect(store.lastWriteReviewTap == clock.date)
        model.sheetDidDismiss()
        await model.waitForPendingWork()
        #expect(spy.count == 0)
        #expect(log.events == [.reviewScreenShown, .writeReviewTapped])
    }

    @Test func seedExistingUserLetsFirstReleaseShow() {
        let model = makeModel(version: "4.21")
        model.seedExistingUser(lastSeenVersion: "4.20")
        model.evaluateOnActive()
        #expect(model.isSheetPresented)
    }

    @Test func resetForgetsEverything() {
        let model = upgradedModel()
        model.evaluateOnActive()
        model.reset()
        #expect(!model.isPresenting)
        #expect(store.snapshot == AfterglowSnapshot())
    }

    @Test func writeReviewURL() {
        let a = AfterglowConfiguration(appStoreID: "123", appName: "A", releaseNotes: [])
        let b = AfterglowConfiguration(appStoreID: "id123", appName: "A", releaseNotes: [])
        let expected = URL(string: "https://apps.apple.com/app/id123?action=write-review")
        #expect(a.writeReviewURL == expected)
        #expect(b.writeReviewURL == expected)
    }
}
