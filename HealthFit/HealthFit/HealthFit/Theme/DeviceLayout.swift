import SwiftUI
import UIKit

enum DeviceLayout {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static func contentMaxWidth(for horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat? {
        guard isPad else { return nil }
        switch horizontalSizeClass {
        case .regular:
            return 720
        case .compact:
            return nil
        default:
            return 680
        }
    }

    static func formMaxWidth(for horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        isPad ? min(contentMaxWidth(for: horizontalSizeClass) ?? 520, 520) : .infinity
    }

    static func adaptivePadding(for horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        guard isPad else { return AppTheme.padding }
        return horizontalSizeClass == .regular ? 28 : AppTheme.padding
    }

    static func gridColumns(for horizontalSizeClass: UserInterfaceSizeClass?, minWidth: CGFloat = 160) -> [GridItem] {
        if isPad && horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: minWidth), spacing: 12)]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    static var usesSplitWorkoutLayout: Bool {
        isPad
    }
}

struct AdaptiveContentWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var maxWidth: CGFloat?

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth ?? DeviceLayout.contentMaxWidth(for: horizontalSizeClass) ?? .infinity)
            .frame(maxWidth: .infinity)
    }
}

struct AdaptiveScreenModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .modifier(AdaptiveContentWidthModifier())
    }
}

extension View {
    func adaptiveContentWidth(_ maxWidth: CGFloat? = nil) -> some View {
        modifier(AdaptiveContentWidthModifier(maxWidth: maxWidth))
    }

    func adaptiveScreenPadding() -> some View {
        modifier(AdaptiveScreenModifier())
    }
}

struct AdaptiveBiotypeRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content
            }
        }
    }
}

struct AdaptiveGoalGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: DeviceLayout.gridColumns(for: horizontalSizeClass), spacing: 10) {
            content
        }
    }
}
