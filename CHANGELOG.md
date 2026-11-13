# Changelog

## Unreleased

- `RatingSummary` gains `scope` (`.storefront` by default, `.worldwide`). A worldwide total is labelled "6,000+ ratings worldwide" in all six languages, because no storefront shows that number.

## 1.0.0 — 2026-10-29

- One What's New sheet per minor version, shown right after an app update. Never on a fresh install, never for patch bumps, and skipped minors show only the newest note.
- A review screen pushed onto the same sheet (one navigation stack, no dismiss and re-present), at most once per minor version, with a 365-day cooldown after a tap on the write-review button.
- Apple's system rating prompt is requested only after the review screen is dismissed with "Not now" or a swipe, after a configurable delay, and never from a button tap or while the screen is visible.
- The call to action is a plain deep link to the App Store write-review page. No gating question; "Send feedback" is an optional secondary link that hands off to your own `feedbackAction`.
- Social proof that stays honest: up to three testimonials, a community pill, and a laurel rating badge that falls back to plain stars when the count or average is low.
- Fully configurable rules through `AfterglowPolicy` (eligibility, install age, cooldown, prompt delay) plus `canPresent` to yield to your own covers, `seedExistingUser` for apps that shipped before Afterglow, and on-demand `presentWhatsNew()` / `presentReview()` for Settings rows.
- An `AfterglowEvent` stream for analytics (`whatsNewShown`, `reviewScreenShown`, `writeReviewTapped`, `feedbackTapped`, `dismissed`, `systemPromptRequested`).
- SwiftUI, Swift 6, no dependencies, no backend. iPhone and iPad (form sheet), light and dark; chrome localized in en, de, es, fr, ko, zh-Hant; ships a privacy manifest (UserDefaults, reason CA92.1; no tracking, no data collected).
