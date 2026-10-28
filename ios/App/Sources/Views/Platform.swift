import SwiftUI

// The few places where iPhone and Mac differ, so the views can be shared as they are.

#if canImport(UIKit)
import UIKit

typealias PlatformImage = UIImage

extension Image {
    init(platformImage: PlatformImage) { self.init(uiImage: platformImage) }
}

extension PlatformImage {
    static func inCatalog(_ name: String) -> Bool { UIImage(named: name) != nil }
}

extension Color {
    /// Dark mode is a soft graphite like the site, not the system's pure black.
    static let groupedBackground = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.137, green: 0.137, blue: 0.149, alpha: 1) : .systemGroupedBackground })
    static let cardBackground = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.188, green: 0.188, blue: 0.204, alpha: 1) : .secondarySystemGroupedBackground })
    static let nestedBackground = Color(.tertiarySystemGroupedBackground)
    static let subtleFill = Color(.tertiarySystemFill)
}

extension View {
    func inlineTitle() -> some View { navigationBarTitleDisplayMode(.inline) }
    func fullScreenCoverCompat<Item: Identifiable, Content: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        fullScreenCover(item: item, content: content)
    }
    func fullScreenCoverCompat<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        fullScreenCover(isPresented: isPresented, content: content)
    }
    func dragIndicator() -> some View { presentationDragIndicator(.visible) }
    func sheetSize() -> some View { self }
}

enum Haptics {
    static func answer(_ ok: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .error)
    }
}
#else
import AppKit

typealias PlatformImage = NSImage

extension Image {
    init(platformImage: PlatformImage) { self.init(nsImage: platformImage) }
}

extension PlatformImage {
    static func inCatalog(_ name: String) -> Bool { NSImage(named: name) != nil }
}

extension Color {
    static let groupedBackground = Color(nsColor: .underPageBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let nestedBackground = Color(nsColor: .windowBackgroundColor)
    static let subtleFill = Color.primary.opacity(0.08)
}

extension View {
    func inlineTitle() -> some View { self }
    // A Mac has no full-screen cover: a sheet is the closest thing.
    func fullScreenCoverCompat<Item: Identifiable, Content: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        sheet(item: item) { content($0).sheetSize() }
    }
    func fullScreenCoverCompat<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented) { content().sheetSize() }
    }
    func dragIndicator() -> some View { self }
    /// A sheet on the Mac has no size of its own: give it room for a question and its explanation.
    func sheetSize() -> some View { frame(minWidth: 640, idealWidth: 760, minHeight: 680, idealHeight: 820) }
}

enum Haptics {
    static func answer(_ ok: Bool) {}
}
#endif

extension View {
    /// A rounded white card on the grey page. `stretch` makes it as tall as its row.
    func card(stretch: Bool = false) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, maxHeight: stretch ? .infinity : nil, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.06)))
    }

    /// Keeps content at a readable width, centred, on wide windows (Mac, iPad). No effect on an iPhone.
    func readableWidth(_ width: CGFloat = 720) -> some View {
        frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}
