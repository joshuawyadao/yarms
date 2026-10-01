import SwiftUI

/// Shared visual roles. Native controls keep their system metrics and behavior.
enum YarmsTheme {
    static let canvas = Color("YarmsCanvas")
    static let surface = Color("YarmsSurface")
    static let soft = Color("YarmsSoft")
    static let accent = Color.accentColor
    static let action = Color("YarmsAction")

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 12
        static let surface: CGFloat = 20
        static let media: CGFloat = 20
    }

    static let minimumTarget: CGFloat = 44
    static let maximumContentWidth: CGFloat = 600
}

struct YarmsActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, YarmsTheme.Spacing.lg)
            .padding(.vertical, YarmsTheme.Spacing.sm)
            .frame(minHeight: YarmsTheme.minimumTarget)
            .foregroundStyle(isEnabled ? Color.white : Color.secondary)
            .background(isEnabled ? YarmsTheme.action : YarmsTheme.soft,
                        in: RoundedRectangle(cornerRadius: YarmsTheme.Radius.control))
            .overlay {
                if configuration.isPressed && isEnabled {
                    RoundedRectangle(cornerRadius: YarmsTheme.Radius.control)
                        .fill(.black.opacity(0.08))
                        .allowsHitTesting(false)
                }
            }
    }
}

struct YarmsSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, YarmsTheme.Spacing.lg)
            .padding(.vertical, YarmsTheme.Spacing.sm)
            .frame(minHeight: YarmsTheme.minimumTarget)
            .foregroundStyle(isEnabled ? YarmsTheme.accent : Color.secondary)
            .background(YarmsTheme.soft, in: RoundedRectangle(cornerRadius: YarmsTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: YarmsTheme.Radius.control)
                    .strokeBorder(YarmsTheme.accent, lineWidth: contrast == .increased ? 1.5 : 0)
                    .allowsHitTesting(false)
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
