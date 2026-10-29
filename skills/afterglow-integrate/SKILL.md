---
name: afterglow-integrate
description: Integrate the Afterglow package (What's New sheet + review ask after app updates) into an iOS app: add the dependency, draft the release notes for the next minor version from the changelog or git history, fetch and curate real App Store reviews as testimonials, write the <App>Afterglow.swift content file, wire the root view and Settings rows, and retire competing requestReview calls. Use when the user asks to add Afterglow, a What's New screen, or an update-moment rating ask to an app.
---

# Integrate Afterglow into an iOS app

Afterglow shows ONE sheet after a minor-version update: What's New, then (at most once per minor version) a review screen pushed onto the same sheet. Apple's system prompt is requested only after "Not now" or a swipe. No gate, no onboarding use.

Package: `https://github.com/aivars/afterglow` (public README and `Sources/Afterglow/Models.swift` are the API reference once published; until then the same files live in the Apnea checkout).

Integration reference (read it before writing anything): `~/Developer/Apnea`
- Content file: `snorkeling/Afterglow/ApneaAfterglow.swift`
- Root wiring: `snorkeling/Screens/HomeView.swift` (search "Afterglow")
- Settings rows and DEBUG buttons: `snorkeling/Screens/Settings/SettingsView.swift` (search "Afterglow")
- UI test and launch hook: `ApneaUITests/AfterglowUITests.swift`, `snorkeling/Utilities/AppTestConfiguration.swift` (`isAfterglowFlow`)
- Package docs and public API (local copy): `~/Developer/Apnea/Packages/Afterglow/README.md`, `Sources/Afterglow/Models.swift`

Work through the steps in order. Steps marked **PAUSE** end with a question to the user; do not continue until they answer. Never invent content: release notes come from the repo, quotes from real reviews, numbers from the user or the App Store.

## Hard rules (refuse, do not negotiate)

- Do NOT place any of this in onboarding, a first-run flow or right after install. Explain: App Store Review Guideline 5.6.1 requires Apple's API for review prompts at a natural break after a completed experience, and 5.6.3 prohibits manipulating ratings and reviews. See the Afterglow README section "Why not in onboarding". A fresh install must never see the sheet (this includes seeding mistakes, see step 7).
- Do NOT add an "enjoying the app?" gate or route unhappy users away from the review button. Everyone sees the same button; "Send feedback" is a secondary link only.
- Testimonials are verbatim. The only permitted edits: dropping whole leading or trailing sentences, and fixing obvious typographic noise (a stray space before punctuation, doubled spaces, straight vs curly quotes). Never change, add, remove or reorder words, spelling or grammar.

## 0. Preflight the checkout

- Run `git status --porcelain` and `git branch --show-current`. Note the default branch (`git symbolic-ref refs/remotes/origin/HEAD` or whichever of `main`/`master` exists); base your branch on it.
- Tolerable noise: `xcuserdata/`, `.DS_Store`, untracked scratch folders. **Not tolerable:** modified tracked source, project or `Package.resolved` files. If any exist, do not stash or commit them. Either ask the user to commit or discard them first, or work in a worktree: `git worktree add -b feature/afterglow <repo>/.worktrees/afterglow <default-branch>` and do everything there.
- Create the branch `feature/afterglow` and commit only the files you created or edited (`git add <paths>`, never `git add -A`). Adding the dependency rewrites `Package.resolved`; include that file only if it was clean before you started.
- Say in one line which checkout, branch and base you are working on before touching anything.

## 1. Detect the project

Find and record all of the following (use `ls`, `grep`, `xcodebuild -list`, `xcodebuild -showBuildSettings`):

- Xcode project or workspace, app target, bundle id, `MARKETING_VERSION` (current version).
- Minimum iOS (`IPHONEOS_DEPLOYMENT_TARGET`). **If below 17, stop and explain** that Afterglow requires iOS 17+; ask whether to proceed after raising it.
- Whether the app target is file-system-synchronized (`PBXFileSystemSynchronizedRootGroup` in `project.pbxproj`): then new files need no pbxproj edits. If not, copy the PBXBuildFile / PBXFileReference / group / Sources-phase pattern of an existing Swift file in the same group.
- The root view that owns onboarding, paywall and sheet state (Apnea: `HomeView`). Afterglow's modifier and `canPresent` go here. Note whether it exists only after onboarding (matters in step 7), and whether the main screen is a tab of a `TabView`.
- Every existing review-ask call site: `grep -rn "requestReview\|SKStoreReviewController\|action=write-review"`. List file and line for each, and what triggers it.
- The onboarding-completed flag (UserDefaults key or model property), and one engagement signal usable for eligibility (session counter, completed workouts, entries created).
- The analytics call (`track(event:properties:)`, `Analytics.log`, TelemetryDeck, etc.), or that there is none.
- Whether FeedbackThread is integrated: `grep -rn "import FeedbackThread"`. If yes, find how it is presented (Apnea: `FeedbackThreadPresentation.shared.presentBoard(...)`; some apps present a form instead of the board).
- The app's string catalog(s) (`Localizable.xcstrings`) and which languages the project ships.
- The brand colour used for tinting, and the app icon asset name.
- The App Store ID: search the repo (`grep -rn "apps.apple.com\|appStoreID\|id[0-9]\{9,10\}"`, fastlane metadata, Docs). If not found, look it up by bundle id: `curl -s "https://itunes.apple.com/lookup?bundleId=<bundle>"` (`trackId`, `version`, `averageUserRating`, `userRatingCount`). Ask the user only if both fail.
- The project's UI-test launch-argument or environment infrastructure (used in step 8).

Summarise the findings in a short list before changing anything.

## 2. Add the dependency

- Remote (default): `https://github.com/aivars/afterglow`, requirement "Up to Next Major" from `1.0.0`.
- Local path only if the user says the package is local or not yet published (e.g. `~/Developer/Apnea/Packages/Afterglow`). In `project.pbxproj` a local reference is:

  ```
  /* Begin XCLocalSwiftPackageReference section */
      <ID> /* XCLocalSwiftPackageReference "../Apnea/Packages/Afterglow" */ = {
          isa = XCLocalSwiftPackageReference;
          relativePath = "../Apnea/Packages/Afterglow";   /* an absolute path is also accepted */
      };
  /* End XCLocalSwiftPackageReference section */
  ```

  Add `<ID>` to the project's `packageReferences`, and an `XCSwiftPackageProductDependency` (`productName = Afterglow`, no `package` key) to the app target's `packageProductDependencies` plus a PBXBuildFile in its Frameworks phase. Swapping to the remote URL later is a one-line edit: replace the local reference with an `XCRemoteSwiftPackageReference` carrying the URL and requirement. Tell the user this.
- Otherwise add it via Xcode project edit (`XCRemoteSwiftPackageReference` / `XCSwiftPackageProductDependency` for the app target) or, for an SPM-based app, `Package.swift`. Prefer the pattern the project already uses for other packages.
- Run `xcodebuild -resolvePackageDependencies`, then a build (step 8 destination), and confirm it succeeds before continuing.

## 3. Draft the What's New content

**Check what is live first.** Run `curl -s "https://itunes.apple.com/lookup?bundleId=<bundle>"` and read `version`, `trackId`, `averageUserRating`, `userRatingCount`. If `MARKETING_VERSION` equals the live `version`, and there is no changelog entry for a newer version, and no user-facing commit since that release, **STOP and ask the user for the next version's content.** Only if they insist, write provisional notes and mark them in the Swift file with `// PROVISIONAL — user to approve`. Never present features that already shipped as new.

Version = `MARKETING_VERSION` bumped to the next minor (e.g. 4.20.1 gives "4.21"), unless the user says otherwise. Use `major.minor` only. **The note's version must match the version the app will ship as.** If `MARKETING_VERSION` is still below it, the sheet can never fire and the UI test cannot run, so include a bump in the PAUSE below: with the user's approval, set `MARKETING_VERSION` to the new version in every configuration of the app target (Debug and Release, and any extension that must match), nothing else.

Sources, in order; use the first that exists and say which one you used:
1. A CHANGELOG entry for that version (`CHANGELOG.md`, `Docs/CHANGELOG.md`, `Docs/changelog-<ver>.md`).
2. Otherwise: `gh pr list --state merged --limit 50` titles, plus `git log --no-merges <last version-bump commit or tag>..HEAD --format=%s` (find the bump with `git log -S"MARKETING_VERSION = <current>" --format='%h %s' -- '*.pbxproj'` or `git tag --sort=-creatordate`), plus any drafted App Store release notes in the repo (`Docs/aso`, `fastlane/metadata/*/release_notes.txt`).

Produce 3 to 5 user-facing items. Skip internal fixes, refactors, CI, dependency bumps, and anything the user cannot see or feel. For each item:
- `headline`: 5 words or fewer, specific ("Replies to your feedback", not "Improvements").
- `detail`: one sentence, plain language, written to the user ("you").
- `systemImage`: one SF Symbol, **filled variant** (`bell.fill`, not `bell`), a concrete noun for the feature (`tablecells`, `applewatch`, `chart.line.uptrend.xyaxis`, `bell` for reminders). Confirm it exists at the app's minimum iOS; a missing symbol renders as `sparkles`, which is a bug.
- A short note `title` for the sheet (e.g. "Replies and reminders").

**PAUSE: show the title and items as a table, name the version they ship as, and ask the user to approve or edit the content and to approve the `MARKETING_VERSION` bump (current to new).**

## 4. Fetch and choose testimonials

Try the sources in order. Stop at the first one that returns reviews. Report to the user what EACH attempted source answered (count, or the reason it returned nothing).

a. **FeedbackThread MCP**: `list_feedback` with `kind: "Reviews"` for the app's project slug (use `list_projects` to find it). If the tool is absent or the token does not cover that project, say so and move on.
b. **`asc reviews list --app <id>`**. Works when the App Store Connect API key is in the keychain; if it fails (key missing), say so and move on.
c. **Public feed**: `python3 -I ~/.claude/skills/afterglow-integrate/scripts/fetch_reviews.py <appId> us gb au ca de fr es`. It prints JSON lines `{storefront, version, author, title, content, length}` already filtered to 5 stars and sorted newest app version first, and prints a per-storefront count on stderr. The feed is flaky; empty storefronts are normal, and it returns nothing for small apps.
d. **Ask the user to paste reviews.**

Also get the audience size per storefront for step 5: `curl -s "https://itunes.apple.com/lookup?id=<id>&country=<cc>"` gives `userRatingCount` and `averageUserRating` for that storefront (sum the counts; the weighted average is approximate).

Filter candidates:
- 5 stars only; prefer the most recent app versions.
- 60 to 220 characters (trim only by dropping whole leading or trailing sentences, per the Hard rules).
- Same language as the app's English catalog unless the user wants localized quotes.
- Must name a concrete benefit (results, ease of use, support or updates).
- Drop anything mentioning bugs, prices, subscriptions, ads, or competitors, and anything off-brand or unclear.

**Decision rule.** Fewer than 3 qualifying reviews: ship with 0 or 1 testimonials rather than padding (the package hides the cards section when the list is empty), and omit `communityLine` for a small audience. Say why in plain words: a weak or tiny social-proof block hurts more than none, and the package shows the star badge only from 50 ratings and a 4.0 average.

**PAUSE: show 6 to 9 candidates grouped by theme (results, ease of use, support/updates), with storefront and app version for each, and ask the user to pick 2 to 3.** If fewer than 3 qualify, show what exists, apply the decision rule above, and let the user decide.

Write the picks as `Testimonial(quote:author:source:)`. Author = first name plus initial ("Scott E."); strip digits, handles and underscores from the reviewer name; if the name is only a handle, use the first word capitalised. Source = "App Store". Quotes are verbatim, in the review's language.

## 5. Rating summary

Use the iTunes lookup figures from step 4 (all storefronts summed) or ask the user for the current average and total rating count (App Store Connect, Ratings and Reviews). Write `RatingSummary(average:count:)` with the raw numbers (the sheet rounds the count down, e.g. 6059 shows "6,000+"). Tell the user the package shows plain stars instead of the number below 50 ratings or below a 4.0 average, so a weak number is never displayed. If the numbers are unknown, omit `ratingSummary` and list it as left to do.

## 6. Write `<App>Afterglow.swift`

Put it next to the other app-level Swift files (Apnea: `snorkeling/Afterglow/`). Model it on `ApneaAfterglow.swift`:

```swift
import Afterglow
import SwiftUI

enum <App>Afterglow {
    @MainActor static var configuration: AfterglowConfiguration { ... }   // everything except canPresent
    static let releaseNotes: [ReleaseNote] = [...]
    static let testimonials: [Testimonial] = [...]
}
```

`configuration` fills in:
- `appStoreID`, `appName` (display name).
- `releaseNotes: releaseNotes`, `testimonials: testimonials`.
- `communityLine`: `String(localized: "Join N+ <audience> using <App>")`, N from the rating count rounded down; omit it if the audience is small (step 4 decision rule) or the user has no sensible audience line.
- `feedbackAction`: if FeedbackThread is integrated, present its board or its feedback form (it runs on the main actor). The presentation must be owned by the root view: a second `.sheet` on the same view can swallow the first, so hang it on the root next to Afterglow's modifier, not on a child. Without FeedbackThread use `nil` (the link hides).
- `onEvent`: the project's analytics call with event name `"afterglow_" + event.rawValue` and `["app_version": <CFBundleShortVersionString>]`. Omit `onEvent` if the app has no analytics.
- `policy: AfterglowPolicy(isEligibleUser: { <onboarding flag> && <one engagement signal> })`. Keep the defaults (2-day install age, 365-day cooldown, once per minor version).
- `accent`: the app's brand colour (not the system default if the app has its own).
- `ratingSummary` from step 5.
- `heroImage: .named("AppIcon60x60")`. This resolves for a single-size iOS 18 app icon too (Xcode generates the 60x60 variant); no separate asset is needed. Confirm in the screenshots that it is not the sparkles tile.

Strings: every `String(localized:)` for release notes, titles and the community line must also be added to the string catalog. Add English values; if the project ships other languages, add translations for those too (keep the tone of the existing catalog; flag machine translations to the user). Do not translate testimonials.

If the project is not file-system-synchronized, add the file to the pbxproj per step 1.

## 7. Wire it

Edit the root view found in step 1:

1. `.afterglow(configuration)` on the root view, where `configuration` is `<App>Afterglow.configuration` with `canPresent` filled in (Apnea builds it in a computed property: `var c = ApneaAfterglow.configuration; c.canPresent = { canPresentAfterglow }`). `canPresent` returns `false` while onboarding, the paywall, celebrations, any other sheet, alert or full-screen cover is up, mid-activity (e.g. a running session), and whenever the user is not on the main tab (gate on the selected tab of a `TabView`). Add `!Afterglow.shared.isPresenting` to the guards of the app's own automatic sheets (paywall prompts, reminders) so they wait for the next activation.
   - When the sheet, alert or busy state lives in a child view (e.g. the main tab's view), the root cannot see it. Add a small `@MainActor` gate object (an `@Observable` or plain class with a `isBusy` flag) that the child mirrors its busy state into (`onChange` of its sheet/alert/session state) and the root reads in `canPresent`.
2. **Seeding.** `Afterglow.shared.seedExistingUser(lastSeenVersion: "<current major.minor>")` must run for users who installed before Afterglow, and never for fresh installs; otherwise existing users look like fresh installs and the first release shows nothing. Do NOT put it in the root view's first `onAppear`/`.task` when that root view only exists after onboarding: a fresh install would be seeded as an existing user and get the sheet right after onboarding, a hard-rule violation. Seed in `App.init` (or wherever onboarding-completed is first known) and only when onboarding is already complete. Never seed on DEBUG/screenshot automation launches or under UI tests.
3. Settings row "What's new in <version>" (localized string, version from `CFBundleShortVersionString`) calling `Afterglow.shared.presentWhatsNew()`. Add `import Afterglow`.
4. Optional (ask the user): a "Rate <App>" row calling `Afterglow.shared.presentReview()`.
5. Inside `#if DEBUG` in Settings (copy the Apnea placement):
   - "Reset Afterglow": `Afterglow.shared.reset()`
   - "Afterglow: simulate upgrade": switch to the main tab first (so `canPresent` is true), then `reset()`, then `seedExistingUser(lastSeenVersion: "<previous minor>")`, then `evaluateOnActive()`. The previous minor is the minor below the new note's version.
6. **Retire or tame competing review asks** (from step 1's list). Show the user the list of changes.
   - A good success-moment `requestReview` already exists (e.g. after the 3rd goal-reaching fast with a 90-day gap): keep it, but suppress it for the rest of any session in which an Afterglow sheet appeared, by setting a session flag from `onEvent` (on `whatsNewShown`) that the existing call checks.
   - A bare per-session prompt, or one at an arbitrary moment: gate it to a genuine success (a finished workout, a personal best) at most once per minor version, and never in the same session as the Afterglow sheet; otherwise remove it.
   - Replace any "Rate the app" button that calls `requestReview` with `Afterglow.shared.openWriteReview()` (or the plain write-review deep link it wraps).

If the user asks to put the ask in onboarding or to add a happy/unhappy gate, refuse per the Hard rules.

## 8. Verify

1. Capture a unit-test baseline before your changes if the project has a unit-test target (on the clean base branch or a separate worktree), and run the suite again after. Report which failures were pre-existing.
2. Build for an iOS 26.5 simulator, e.g. `xcodebuild -scheme <Scheme> -destination 'platform=iOS Simulator,name=<device>,OS=26.5' build` (list runtimes with `xcrun simctl list runtimes`). Fix compile errors (Swift 6 concurrency: closures passed to `onEvent` are `@Sendable`, so capture only Sendable values). The first `xcodebuild test` on a fresh simulator can fail with "Failed to locate promise"; retry once before investigating.
3. If the project has UI-test launch-argument or environment infrastructure, add a `UITEST_AFTERGLOW_FLOW`-style hook (mirror `AppTestConfiguration.isAfterglowFlow`): when set, write `afterglow.lastSeenVersion` = previous minor, `afterglow.firstLaunchDate` = 30 days ago, onboarding completed and the engagement signal; and add a UI test modelled on `ApneaUITests/AfterglowUITests.swift` (What's New, Continue, review screen, Not now). This only works once `MARKETING_VERSION` matches the note's version (step 3). Run it headlessly with `xcodebuild test` and extract the attached screenshots from the `.xcresult`. Look at the screenshots; check for sparkles fallbacks and truncated text.
4. If there is no such infrastructure, tell the user to run a Debug build and tap Settings, "Afterglow: simulate upgrade", then background and reopen the app.
5. **Delete any simulator you created** (`xcrun simctl delete <udid>`); disk is tight. Do not delete simulators you did not create.

## 9. Measure

Tell the user, in the final message:
- On release day, note the rating count per storefront (App Store Connect, Ratings and Reviews). Compare new ratings per week per storefront for the four weeks before and the four weeks after the first release carrying Afterglow, and watch the average for a drop (README "Measuring it").
- Watch the `afterglow_*` event funnel (if analytics exist): `whatsNewShown`, `reviewScreenShown`, then `writeReviewTapped` or `dismissed` (`feedbackTapped` is the other exit). `systemPromptRequested` follows `dismissed` and means the request was made, not that Apple showed the prompt.

## 10. Report

End with a concise report:
- Files changed (absolute paths) and the dependency added (remote or local).
- What each review source answered (FeedbackThread, `asc`, public feed, iTunes lookup, user paste).
- The approved What's New content, the version bump, and the chosen testimonials (with storefront and version).
- Review-ask call sites removed or changed.
- Build and test results, pre-existing test failures (if any) and whether they were compared against a baseline, and which simulators were created and deleted.
- Left for the user: testimonials if fewer than 3, App Store ID if unconfirmed, rating summary if skipped, `asc` API key if it was missing, translations needing review, provisional notes still to approve, the release-day measurement.
