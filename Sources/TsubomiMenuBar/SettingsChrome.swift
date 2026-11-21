// tsubomi のアプリの設定画面の見た目（システム設定と同じ寸法の枠と行）。
// もとは TouchRotator の SettingsChrome.swift。各アプリが写しを持っていたのを、ここ 1 か所にまとめた。

import AppKit
import SwiftUI

/// How System Settings draws a settings pane, measured rather than guessed.
///
/// The numbers come from a screenshot of プライバシーとセキュリティ → 入力監視.
/// Its traffic-light buttons are 32.36px between centres, and those are 20pt
/// apart, which fixes the scale at 1.618px/pt; everything else is read off
/// against that:
///
/// - the group box is inset 20pt from the pane's edges,
/// - its corners are 17.1px — **10pt**,
/// - it is filled #f8f8f8 on a #ffffff page: black at 7/255,
/// - its rows are 35.5pt apart, and the separators run the full width.
///
/// SwiftUI's own `.formStyle(.grouped)` draws a 4.25pt corner and a fill only
/// 4 levels from the page, and neither is reachable: `listRowBackground` has
/// no effect at all inside a macOS `Form` — changing it does not alter a
/// single pixel of the render. So the box is drawn here instead.
public enum SettingsChrome {
    public static let cardCornerRadius: CGFloat = 10
    /// Inset of the cards from the edges of the pane.
    public static let cardInset: CGFloat = 20
    /// Gap between one card and the next.
    public static let cardSpacing: CGFloat = 20
    public static let rowHorizontalPadding: CGFloat = 10
    public static let rowMinHeight: CGFloat = 36

    /// A hair of contrast against the page, in whichever direction the page
    /// is not.
    ///
    /// System Settings on macOS 26 draws #f8f8f8 boxes on a #ffffff page —
    /// black at 7/255 — and in dark mode the pair is the other way up. That
    /// is what `Color.primary` already is: black on a light page, white on a
    /// dark one, so one number covers both.
    ///
    /// This was `controlBackgroundColor` (plain white) for one release. That
    /// was right while the app was built against the macOS 14 SDK, where the
    /// window's own page comes out grey; built against macOS 26 the page is
    /// white and white cards vanish into it. The build machine's photographs
    /// of both are what settled it.
    public static let cardFill = Color.primary.opacity(7.0 / 255.0)

}

/// One settings pane: a scrolling column of cards on the page colour.
public struct SettingsPane<Content: View>: View {
    @ViewBuilder var content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsChrome.cardSpacing) {
                content
            }
            .padding(SettingsChrome.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // No background of our own. A settings window's content runs up
        // under the title bar, and an opaque fill painted there is square
        // where the window's corner is round — which is the dark wedge that
        // showed at the top corners. The platform's own page colour is
        // already correct, and it is clipped to the window's shape.
        //
        // A row spreads its label and its control apart, the way every row in
        // System Settings does. Setting the styles here means the rows
        // themselves stay ordinary `Toggle`s and `LabeledContent`s.
        .labeledContentStyle(SettingsRowStyle())
        .toggleStyle(SettingsRowToggleStyle())
    }
}

/// A run of related rows, drawn as one group box.
///
/// Padding and separators belong to the card rather than to the rows, so
/// every kind of row — a toggle, a button, a slider, a plain line of text —
/// lines up without knowing anything about the card it is in.
public struct SettingsCard<Content: View, Header: View, Footer: View>: View {
    @ViewBuilder private let content: Content
    @ViewBuilder private let header: Header
    @ViewBuilder private let footer: Footer

    public init(
        @ViewBuilder content: () -> Content
    ) where Header == EmptyView, Footer == EmptyView {
        self.content = content()
        header = EmptyView()
        footer = EmptyView()
    }

    /// The shorthand `Section("題名") { … }` has, so call sites that only
    /// want a heading do not have to grow a trailing closure for it.
    public init(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) where Header == Text, Footer == EmptyView {
        self.content = content()
        header = Text(title)
        footer = EmptyView()
    }

    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) where Footer == EmptyView {
        self.content = content()
        self.header = header()
        footer = EmptyView()
    }

    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) where Header == EmptyView {
        self.content = content()
        header = EmptyView()
        self.footer = footer()
    }

    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.header = header()
        self.footer = footer()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if Header.self != EmptyView.self {
                header
                    .font(.headline)
                    .padding(.leading, 4)
            }
            _VariadicView.Tree(Rows()) { content }
                .background(
                    RoundedRectangle(cornerRadius: SettingsChrome.cardCornerRadius, style: .continuous)
                        .fill(SettingsChrome.cardFill)
                )
            if Footer.self != EmptyView.self {
                footer
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Lays the card's children out as rows: each one padded and given the
    /// row height, with a hairline between neighbours.
    ///
    /// `_VariadicView` is how SwiftUI's own container views see their
    /// children one at a time; there is no public way to ask. It resolves at
    /// compile time, so a SwiftUI that dropped it would fail the build rather
    /// than misbehave in front of anyone.
    private struct Rows: _VariadicView_MultiViewRoot {
        @ViewBuilder
        func body(children: _VariadicView.Children) -> some View {
            VStack(spacing: 0) {
                ForEach(children) { child in
                    child
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                        .frame(minHeight: SettingsChrome.rowMinHeight)
                    if child.id != children.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

/// Label on the left, control hard against the right.
public struct SettingsRowStyle: LabeledContentStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 12)
            configuration.content
        }
    }
}

/// The same shape for a toggle, whose switch System Settings always parks at
/// the trailing edge.
public struct SettingsRowToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 12)
            Toggle(configuration)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

/// A picker laid out like every other row: the label on the left, the control
/// against the trailing edge.
///
/// `Picker` has no style protocol that could do this the way `LabeledContent`
/// and `Toggle` do, so the row shape is built around it instead. Modifiers
/// applied outside — `.pickerStyle`, `.disabled` — still reach the picker
/// through the environment.
public struct SettingsPicker<SelectionValue: Hashable, Content: View>: View {
    private let title: LocalizedStringKey
    @Binding private var selection: SelectionValue
    @ViewBuilder private let content: Content

    public init(
        _ title: LocalizedStringKey,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        _selection = selection
        self.content = content()
    }

    public var body: some View {
        LabeledContent(title) {
            Picker(title, selection: $selection) { content }
                .labelsHidden()
                .fixedSize()
        }
    }
}
