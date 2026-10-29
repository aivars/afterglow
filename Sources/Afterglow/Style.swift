import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Shared visual language for both sheets.
enum AfterglowStyle {
    static let gold = Color(red: 1.0, green: 0.72, blue: 0.1)
    /// Readable column width. Wider than any iPhone, so phones are unaffected; on iPad the content
    /// stays centered at this width instead of stretching across the form sheet.
    static let columnWidth: CGFloat = 560

    #if canImport(UIKit)
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    #else
    static let background = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    #endif
}

extension View {
    /// Grouped background with a soft accent wash at the top. Works in light and dark.
    func afterglowBackground(accent: Color) -> some View {
        background {
            ZStack {
                AfterglowStyle.background
                LinearGradient(
                    stops: [
                        .init(color: accent.opacity(0.22), location: 0),
                        .init(color: .clear, location: 0.45),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
    }

    /// Fills the available width up to ``AfterglowStyle/columnWidth``; the caller centers it in an outer
    /// `.frame(maxWidth: .infinity)`.
    func afterglowColumn() -> some View {
        frame(maxWidth: .infinity)
            .frame(maxWidth: AfterglowStyle.columnWidth)
    }

    /// Rounded card surface; the shadow is dropped in dark mode.
    func afterglowCard() -> some View {
        modifier(AfterglowCardModifier())
    }

    /// Full-width capsule primary button styling.
    func afterglowPrimaryButton(accent: Color) -> some View {
        buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(accent)
            .buttonBorderShape(.capsule)
    }

    /// Empty inline title and a clear bar, so each screen's own accent wash shows through the
    /// navigation bar area (no white strip when a screen is pushed).
    @ViewBuilder
    func afterglowNavigationChrome() -> some View {
        #if os(iOS)
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Sheet-level presentation, applied once to the flow's root, never to pushed screens.
    @ViewBuilder
    func afterglowPresentation() -> some View {
        #if os(iOS)
        modifier(AfterglowPresentationModifier())
        #else
        self
        #endif
    }
}

#if os(iOS)
/// Full-height sheet on compact widths (iPhone); the system form sheet on regular widths (iPad).
private struct AfterglowPresentationModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        let base = content
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        if #available(iOS 18.0, *) {
            detented(base.presentationSizing(.form))
        } else {
            detented(base)
        }
    }

    @ViewBuilder
    private func detented(_ view: some View) -> some View {
        if horizontalSizeClass == .compact {
            view.presentationDetents([.large])
        } else {
            view
        }
    }
}
#endif

private struct AfterglowCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                AfterglowStyle.card,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 12, y: 4)
    }
}

/// Up to two initials from the first two words of an author name.
/// "Scott E." becomes "SE", "@jason" becomes "J", "Donnie" becomes "D", "王小明" becomes "王".
/// Latin letters are uppercased, CJK characters are kept as they are. No usable letter gives "\u{2605}".
func afterglowInitials(_ name: String) -> String {
    let initials = name
        .split(whereSeparator: { $0.isWhitespace })
        .prefix(2)
        .compactMap { word -> String? in
            guard let first = word.drop(while: { $0 == "@" }).first(where: { $0.isLetter || $0.isNumber }) else { return nil }
            let upper = String(first).uppercased()
            // "\u{DF}" uppercases to "SS"; keep a single character per word.
            return upper.count == 1 ? upper : String(first)
        }
        .joined()
    return initials.isEmpty ? "\u{2605}" : initials
}

extension AfterglowImage {
    /// Symbol shown when a requested one is unknown on this OS or a named asset is missing.
    static let fallbackSymbol = "sparkles"

    /// `name` if it exists, `sparkles` otherwise. Pure so it can be tested without UIKit.
    static func resolvedSystemName(for name: String, exists: (String) -> Bool) -> String {
        exists(name) ? name : fallbackSymbol
    }

    /// Whether this OS has an SF Symbol with that name.
    static func systemSymbolExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(systemName: name) != nil
        #else
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        #endif
    }

    /// A resolved SwiftUI image. A `.system` symbol that does not exist here resolves to `sparkles`.
    /// Nil only when a `.named` image is not in the main bundle.
    var resolved: Image? {
        switch self {
        case .system(let name):
            return Image(systemName: Self.resolvedSystemName(for: name, exists: Self.systemSymbolExists))
        case .named(let name):
            #if canImport(UIKit)
            return UIImage(named: name).map { Image(uiImage: $0) }
            #else
            return NSImage(named: name).map { Image(nsImage: $0) }
            #endif
        }
    }

    /// Like ``resolved`` but never nil: a missing asset falls back to `sparkles`.
    var resolvedOrFallback: Image {
        resolved ?? Image(systemName: Self.fallbackSymbol)
    }

    /// True for `.system` images, which should be tinted and sized like text; assets are sized to fit.
    var isSystem: Bool {
        if case .system = self { return true }
        return false
    }
}
