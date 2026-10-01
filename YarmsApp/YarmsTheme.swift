import Accessibility
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

/// Report completed save actions without moving focus or interrupting existing speech.
enum YarmsAccessibility {
    @MainActor
    static func announceSaveResult(_ message: String) {
        var announcement = AttributedString(message)
        announcement.accessibilitySpeechAnnouncementPriority = .low
        AccessibilityNotification.Announcement(announcement).post()
    }
}

/// Brief, restrained motion for direct actions and local state changes.
enum YarmsMotion {
    static func feedback(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.16)
    }

    static func transition(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.22)
    }
}

private struct YarmsReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Writable preview/test override; the system Reduce Motion setting always takes precedence.
    var yarmsReduceMotion: Bool {
        get { accessibilityReduceMotion || self[YarmsReduceMotionKey.self] }
        set { self[YarmsReduceMotionKey.self] = newValue }
    }
}

private struct YarmsPressFeedback: ViewModifier {
    let isPressed: Bool
    @Environment(\.yarmsReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && isEnabled && !reduceMotion ? 0.98 : 1)
            .animation(YarmsMotion.feedback(reduceMotion: reduceMotion), value: isPressed)
            .frame(minWidth: YarmsTheme.minimumTarget,
                   minHeight: YarmsTheme.minimumTarget)
            .contentShape(Rectangle())
    }
}

extension View {
    func yarmsPressFeedback(isPressed: Bool) -> some View {
        modifier(YarmsPressFeedback(isPressed: isPressed))
    }
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
            .yarmsPressFeedback(isPressed: configuration.isPressed)
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
            .yarmsPressFeedback(isPressed: configuration.isPressed)
    }
}

/// Adds only interaction feedback; the caller supplies the control's shape and colors.
struct YarmsPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .yarmsPressFeedback(isPressed: configuration.isPressed)
    }
}
