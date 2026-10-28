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
    static let groupedBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
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
        sheet(item: item, content: content)
    }
    func fullScreenCoverCompat<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented, content: content)
    }
    func dragIndicator() -> some View { self }
}

enum Haptics {
    static func answer(_ ok: Bool) {}
}
#endif
