import StoreKit
import SwiftUI

public extension View {
    /// Installs the What's New sheet (with the review screen pushed onto it) and re-evaluates whenever the scene becomes active.
    func afterglow(_ configuration: AfterglowConfiguration) -> some View {
        modifier(AfterglowModifier(configuration: configuration))
    }
}

@MainActor
struct AfterglowModifier: ViewModifier {
    let configuration: AfterglowConfiguration

    @Bindable private var afterglow = Afterglow.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content
            .onAppear {
                afterglow.requestReview = { requestReview() }
                afterglow.configure(configuration)
                if scenePhase == .active { afterglow.evaluateOnActive() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                afterglow.configure(configuration)
                afterglow.evaluateOnActive()
            }
            .sheet(isPresented: $afterglow.isSheetPresented, onDismiss: afterglow.sheetDidDismiss) {
                if let note = afterglow.activeNote {
                    AfterglowFlowView(afterglow: afterglow, configuration: configuration, note: note)
                }
            }
    }
}
