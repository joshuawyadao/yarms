import SwiftUI

/// Informational metadata, deliberately lighter than an interactive folder filter.
struct FolderBadge: View {
    let name: String?
    @Environment(\.yarmsReduceMotion) private var reduceMotion

    var body: some View {
        Label(name ?? "Unfiled", systemImage: name == nil ? "tray" : "folder")
            .font(.caption)
            .foregroundStyle(YarmsTheme.accent)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
            .animation(YarmsMotion.transition(reduceMotion: reduceMotion), value: name)
            .accessibilityLabel("Folder: \(name ?? "Unfiled")")
    }
}

struct FolderFilter: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.yarmsReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: YarmsTheme.Spacing.sm) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 12)
                    .accessibilityHidden(true)
                Text(title)
                Text("\(count)")
                    .monospacedDigit()
                    .contentTransition(reduceMotion ? .identity : .numericText())
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, YarmsTheme.Spacing.lg)
            .padding(.vertical, YarmsTheme.Spacing.sm)
            .frame(minHeight: YarmsTheme.minimumTarget)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? YarmsTheme.action : YarmsTheme.soft, in: Capsule())
            .overlay {
                Capsule().strokeBorder(YarmsTheme.accent, lineWidth: contrast == .increased ? 1.5 : 0)
            }
        }
        .buttonStyle(YarmsPlainButtonStyle())
        .animation(YarmsMotion.transition(reduceMotion: reduceMotion), value: isSelected)
        .animation(YarmsMotion.transition(reduceMotion: reduceMotion), value: count)
        .accessibilityLabel("\(title), \(count) \(count == 1 ? "workout" : "workouts")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct WorkoutCardContent: View {
    let workout: Workout
    let folderName: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.yarmsReduceMotion) private var reduceMotion

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: YarmsTheme.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: YarmsTheme.Spacing.md))
        layout {
            thumbnail
            VStack(alignment: .leading, spacing: YarmsTheme.Spacing.xs) {
                Text(workout.title ?? "TikTok workout")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                if let creator = workout.creator {
                    Text(creator)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                }
                if workout.title == nil {
                    Text(sourceReference)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                        .truncationMode(.middle)
                }
                FolderBadge(name: folderName)
                    .padding(.top, YarmsTheme.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(YarmsTheme.Spacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var thumbnail: some View {
        AsyncImage(url: workout.thumbnailURL,
                   transaction: Transaction(animation: YarmsMotion.transition(reduceMotion: reduceMotion))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(YarmsTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(YarmsTheme.soft)
            }
        }
        .frame(width: typeSize.isAccessibilitySize ? 48 : 64,
               height: typeSize.isAccessibilitySize ? 48 : 84)
        .clipShape(RoundedRectangle(cornerRadius: YarmsTheme.Radius.control))
        .accessibilityHidden(true)
    }

    private var sourceReference: String {
        let url = workout.sourceLink.url
        return (url.host ?? "tiktok.com") + url.path
    }

    private var accessibilitySummary: String {
        [workout.title ?? "TikTok workout", workout.creator,
         workout.title == nil ? sourceReference : nil, "Folder: \(folderName ?? "Unfiled")"]
            .compactMap { $0 }.joined(separator: ", ")
    }
}

/// A persistent inline result. Only a new successful event briefly blooms behind its checkmark.
struct YarmsSaveConfirmation: View {
    let message: String?
    let eventID: Int
    let celebrates: Bool
    let placeholder: String
    @Environment(\.yarmsReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var symbolSize = 22

    init(message: String?, eventID: Int, celebrates: Bool = true,
         placeholder: String = "Saved for your next move.") {
        self.message = message
        self.eventID = eventID
        self.celebrates = celebrates
        self.placeholder = placeholder
    }

    var body: some View {
        HStack(spacing: YarmsTheme.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(Color("YarmsBloom"))
                    .frame(width: symbolSize, height: symbolSize)
                    .phaseAnimator([0, 1, 2], trigger: eventID) { bloom, phase in
                        bloom
                            .scaleEffect(phase == 1 ? 1.4 : 0.45)
                            .opacity(phase == 1 && celebrates && !reduceMotion && message != nil ? 0.55 : 0)
                    } animation: { phase in
                        guard celebrates && message != nil else { return nil }
                        return phase == 1
                            ? YarmsMotion.feedback(reduceMotion: reduceMotion)
                            : YarmsMotion.transition(reduceMotion: reduceMotion)
                    }
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(YarmsTheme.accent)
                    .opacity(message == nil ? 0 : 1)
            }
            .frame(width: symbolSize * 1.4, height: symbolSize)
            .accessibilityHidden(true)

            ZStack(alignment: .leading) {
                Text(placeholder)
                    .hidden()
                if let message {
                    Text(message)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        // A reserved multiline message costs too much browsing space at large text sizes.
        .frame(height: message == nil && typeSize.isAccessibilitySize ? 0 : nil)
        .accessibilityElement(children: .combine)
        .accessibilityHidden(message == nil)
    }
}

struct YarmsEmptyState: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        VStack(spacing: YarmsTheme.Spacing.md) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(YarmsTheme.accent)
                .padding(YarmsTheme.Spacing.lg)
                .background(YarmsTheme.soft, in: RoundedRectangle(cornerRadius: YarmsTheme.Radius.surface))
                .accessibilityHidden(true)
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}

/// A self-reported workout finish deserves a brief, dismissible celebration.
struct WorkoutCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yarmsReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var hasAnimated = false
    @State private var heartSettled = false
    @State private var sparklesShown = false

    var body: some View {
        ScrollView {
            VStack(spacing: YarmsTheme.Spacing.md) {
                artwork
                    .frame(height: typeSize.isAccessibilitySize ? 76 : 112)
                    .accessibilityHidden(true)

                Text("Good Job BUNS!")
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("workoutCompletionTitle")

                Text("You showed up and moved today. Be proud of yourself!")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, YarmsTheme.Spacing.xl)
            .padding(.top, YarmsTheme.Spacing.lg)
            .padding(.bottom, YarmsTheme.Spacing.xl)
            .frame(maxWidth: YarmsTheme.maximumContentWidth)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                dismiss()
            } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(YarmsActionButtonStyle())
            .accessibilityIdentifier("workoutCompletionDoneButton")
            .padding(.horizontal, YarmsTheme.Spacing.xl)
            .padding(.vertical, YarmsTheme.Spacing.md)
            .frame(maxWidth: YarmsTheme.maximumContentWidth)
            .frame(maxWidth: .infinity)
            .background(YarmsTheme.canvas)
        }
        .background(YarmsTheme.canvas)
        .onAppear(perform: animateOnce)
        .onDisappear {
            // A fresh presentation starts from the resting entrance state.
            hasAnimated = false
            heartSettled = false
            sparklesShown = false
        }
    }

    private var artwork: some View {
        let compact = typeSize.isAccessibilitySize
        return ZStack {
            Image(systemName: "sparkle")
                .font(.system(size: compact ? 11 : 16, weight: .medium))
                .offset(x: compact ? -39 : -60, y: compact ? -17 : -31)
            Image(systemName: "sparkle")
                .font(.system(size: compact ? 9 : 12, weight: .medium))
                .offset(x: compact ? 43 : 64, y: compact ? -11 : -21)
            Image(systemName: "sparkle")
                .font(.system(size: compact ? 8 : 11, weight: .medium))
                .offset(x: compact ? 34 : 51, y: compact ? 22 : 35)
        }
        .foregroundStyle(YarmsTheme.accent.opacity(0.65))
        .scaleEffect(reduceMotion || sparklesShown ? 1 : 0.55)
        .opacity(reduceMotion || sparklesShown ? 1 : 0)
        .overlay {
            SmilingHeart()
                .frame(width: compact ? 62 : 94, height: compact ? 58 : 88)
                .scaleEffect(reduceMotion || heartSettled ? 1 : 0.72)
                .offset(y: reduceMotion || heartSettled ? 0 : 10)
        }
    }

    private func animateOnce() {
        guard !hasAnimated else { return }
        hasAnimated = true
        guard !reduceMotion else {
            heartSettled = true
            sparklesShown = true
            return
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.64)) {
            heartSettled = true
        }
        withAnimation(.easeOut(duration: 0.32).delay(0.14)) {
            sparklesShown = true
        }
    }
}

private struct SmilingHeart: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HeartShape()
                    .fill(Color("YarmsBloom"))
                Circle()
                    .fill(YarmsTheme.action)
                    .frame(width: geometry.size.width * 0.07)
                    .position(x: geometry.size.width * 0.39, y: geometry.size.height * 0.42)
                Circle()
                    .fill(YarmsTheme.action)
                    .frame(width: geometry.size.width * 0.07)
                    .position(x: geometry.size.width * 0.61, y: geometry.size.height * 0.42)
                SmileShape()
                    .stroke(YarmsTheme.action, style: StrokeStyle(lineWidth: geometry.size.width * 0.035,
                                                                    lineCap: .round))
            }
        }
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.22))
        path.addCurve(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.19),
                      control1: CGPoint(x: rect.width * 0.34, y: rect.height * -0.03),
                      control2: CGPoint(x: rect.width * 0.08, y: rect.height * 0.01))
        path.addCurve(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.96),
                      control1: CGPoint(x: rect.width * -0.02, y: rect.height * 0.48),
                      control2: CGPoint(x: rect.width * 0.31, y: rect.height * 0.80))
        path.addCurve(to: CGPoint(x: rect.width * 0.92, y: rect.height * 0.19),
                      control1: CGPoint(x: rect.width * 0.69, y: rect.height * 0.80),
                      control2: CGPoint(x: rect.width * 1.02, y: rect.height * 0.48))
        path.addCurve(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.22),
                      control1: CGPoint(x: rect.width * 0.92, y: rect.height * 0.01),
                      control2: CGPoint(x: rect.width * 0.66, y: rect.height * -0.03))
        path.closeSubpath()
        return path
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.39, y: rect.height * 0.55))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.61, y: rect.height * 0.55),
                          control: CGPoint(x: rect.width * 0.5, y: rect.height * 0.67))
        return path
    }
}

#Preview("Components · light") {
    componentExamples.preferredColorScheme(.light)
}

#Preview("Components · dark, large text") {
    componentExamples.preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}

#Preview("Save confirmation · action and Reduce Motion") {
    SaveConfirmationPreview()
}

#Preview("Workout completion · light") {
    WorkoutCompletionView().preferredColorScheme(.light)
}

#Preview("Workout completion · dark, large text and Reduce Motion") {
    WorkoutCompletionView()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
        .environment(\.yarmsReduceMotion, true)
}

private struct SaveConfirmationPreview: View {
    @State private var message: String?
    @State private var eventID = 0
    @State private var reduceMotion = false
    @State private var celebrates = true

    var body: some View {
        VStack(alignment: .leading, spacing: YarmsTheme.Spacing.lg) {
            Toggle("Reduce Motion", isOn: $reduceMotion)
            Button("Save example") {
                message = "Saved on this iPhone."
                celebrates = true
                eventID += 1
            }
            .buttonStyle(YarmsActionButtonStyle())
            Button("Show duplicate") {
                message = "Already in your library."
                celebrates = false
                eventID += 1
            }
            .buttonStyle(YarmsSecondaryButtonStyle())
            Button("Clear status") { message = nil }
                .buttonStyle(YarmsSecondaryButtonStyle())
            YarmsSaveConfirmation(message: message, eventID: eventID, celebrates: celebrates)
        }
        .padding(YarmsTheme.Spacing.lg)
        .background(YarmsTheme.canvas)
        .environment(\.yarmsReduceMotion, reduceMotion)
    }
}

@MainActor private var componentExamples: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: YarmsTheme.Spacing.lg) {
            Text("Find your feel-good move.").font(.title2.bold())
            FolderBadge(name: nil)
            FolderBadge(name: "A little movement for the end of the day")
            FolderFilter(title: "All", count: 3, isSelected: true, action: {})
            Button("Open in TikTok") {}.buttonStyle(YarmsActionButtonStyle())
            Button("Save notes") {}.buttonStyle(YarmsSecondaryButtonStyle())
            YarmsEmptyState(title: "No workouts yet", symbol: "figure.strengthtraining.traditional",
                            message: "Spot a move you’d love to try? Save it here for your next workout.")
        }
        .padding(YarmsTheme.Spacing.lg)
    }
    .background(YarmsTheme.canvas)
}
