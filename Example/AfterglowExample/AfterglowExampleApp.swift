import Afterglow
import SwiftUI

@main
struct AfterglowExampleApp: App {
    init() {
        // Debug launch arguments, handled before the first view appears so the first evaluation sees them.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--afterglow-demo") {
            Afterglow.shared.reset()
            Afterglow.shared.seedExistingUser(lastSeenVersion: "1.0")
        } else if args.contains("--afterglow-review") {
            // Already on 1.1, so nothing fires automatically; the review screen is presented by ContentView.
            Afterglow.shared.reset()
            Afterglow.shared.seedExistingUser(lastSeenVersion: "1.1")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
