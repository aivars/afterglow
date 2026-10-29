import SwiftUI

struct WhatsNewSheet: View {
    let note: ReleaseNote
    let accent: Color
    var heroImage: AfterglowImage? = nil
    let onContinue: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 44
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 76

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    hero
                        .padding(.bottom, 6)
                    Text(L10n.whatsNewIn(L10n.versionLabel(note.version)))
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.8)
                        .foregroundStyle(accent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(note.title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    ForEach(Array(note.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider().padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : iconSize + 16)
                        }
                        row(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .afterglowCard()
            }
            .afterglowColumn()
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        .afterglowBackground(accent: accent)
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text(L10n.continueButton)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .afterglowPrimaryButton(accent: accent)
            .frame(maxWidth: AfterglowStyle.columnWidth)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 480)
        #endif
        .afterglowNavigationChrome()
    }

    @ViewBuilder
    private var hero: some View {
        let shape = RoundedRectangle(cornerRadius: heroSize * 18 / 76, style: .continuous)
        // A named asset (the app icon) is shown as-is. A system symbol, whether
        // configured or the fallback, sits white on the accent tile so it never
        // renders as a bare black glyph.
        if case .named = heroImage, let image = heroImage?.resolved {
            image
                .resizable()
                .scaledToFill()
                .frame(width: heroSize, height: heroSize)
                .clipShape(shape)
                .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
                .accessibilityHidden(true)
        } else {
            let symbol: String = {
                if case .system(let name) = heroImage {
                    return AfterglowImage.resolvedSystemName(for: name, exists: AfterglowImage.systemSymbolExists)
                }
                return AfterglowImage.fallbackSymbol
            }()
            shape
                .fill(LinearGradient(
                    colors: [accent, accent.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: heroSize, height: heroSize)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: heroSize * 34 / 76, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
                .accessibilityHidden(true)
        }
    }

    /// Unknown symbols and missing assets fall back to `sparkles`, never a blank circle.
    @ViewBuilder
    private func rowIcon(_ image: AfterglowImage) -> some View {
        if image.isSystem || image.resolved == nil {
            image.resolvedOrFallback
                .font(.title3)
                .foregroundStyle(accent)
        } else {
            image.resolvedOrFallback
                .resizable()
                .scaledToFit()
                .frame(width: iconSize * 0.55, height: iconSize * 0.55)
        }
    }

    private func row(_ item: ReleaseNote.Item) -> some View {
        // At accessibility sizes the icon moves above the text so the copy keeps the full card width.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        return layout {
            rowIcon(item.image)
                .frame(width: iconSize, height: iconSize)
                .background(accent.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.headline)
                    .font(.headline)
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

#Preview("What's new") {
    WhatsNewSheet(
        note: .preview,
        accent: .teal,
        onContinue: {}
    )
}

extension ReleaseNote {
    static let preview = ReleaseNote(
        version: "4.21",
        title: "Custom tables and Apple Watch",
        items: [
            .init(systemImage: "tablecells", headline: "Build your own tables", detail: "Design tables that fit your level."),
            .init(systemImage: "applewatch", headline: "Train from your wrist", detail: "Start a session on Apple Watch and keep your phone in your bag."),
            .init(systemImage: "chart.line.uptrend.xyaxis", headline: "Clearer progress", detail: "See personal bests and trends at a glance."),
        ]
    )
}
