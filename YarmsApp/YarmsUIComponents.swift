import SwiftUI

/// Informational metadata, deliberately lighter than an interactive folder filter.
struct FolderBadge: View {
    let name: String?

    var body: some View {
        Label(name ?? "Unfiled", systemImage: name == nil ? "tray" : "folder")
            .font(.caption)
            .foregroundStyle(YarmsTheme.accent)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Folder: \(name ?? "Unfiled")")
    }
}

struct FolderFilter: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(spacing: YarmsTheme.Spacing.sm) {
                if isSelected { Image(systemName: "checkmark").font(.caption.weight(.semibold)) }
                Text(title)
                Text("\(count)").monospacedDigit()
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
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) \(count == 1 ? "workout" : "workouts")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct WorkoutCardContent: View {
    let workout: Workout
    let folderName: String?
    @Environment(\.dynamicTypeSize) private var typeSize

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
        AsyncImage(url: workout.thumbnailURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
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

#Preview("Components · light") {
    componentExamples.preferredColorScheme(.light)
}

#Preview("Components · dark, large text") {
    componentExamples.preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
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
