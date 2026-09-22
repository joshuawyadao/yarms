import SwiftUI
import UIKit

struct LibraryShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var workouts: [Workout] = []
    @State private var searchText = ""
    @State private var enriching = Set<UUID>()
    @State private var message: String?

    private var visibleWorkouts: [Workout] {
        workouts.filter { $0.matches(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Share a TikTok workout to Yarms or paste its link here.")
                    )
                } else if visibleWorkouts.isEmpty {
                    ContentUnavailableView(
                        "No matching workouts",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different title, creator, or link.")
                    )
                } else {
                    List {
                        ForEach(visibleWorkouts) { workout in
                            NavigationLink {
                                EmbeddedPlayerView(workout: workout)
                            } label: {
                                WorkoutRow(workout: workout)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Yarms")
            .searchable(text: $searchText, prompt: "Search workouts")
            .toolbar {
                Button("Paste link", systemImage: "doc.on.clipboard", action: pasteLink)
            }
            .alert("Could not update workouts", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
            .onAppear(perform: refresh)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
        }
    }

    private func pasteLink() {
        guard let text = UIPasteboard.general.string,
              let link = TikTokLink(text: text) else {
            message = "Copy a TikTok video link, then try again."
            return
        }
        guard let inbox = SharedInbox.live() else {
            message = "Yarms could not access its saved links."
            return
        }
        do {
            try inbox.save(link)
            refresh()
        } catch {
            message = "Yarms could not save that link."
        }
    }

    private func refresh() {
        guard let store = WorkoutStore.live() else {
            message = "Yarms could not access its saved workouts."
            return
        }
        do {
            workouts = try store.importPending()
            for workout in workouts where workout.title == nil || workout.playbackLink.videoID == nil {
                guard enriching.insert(workout.id).inserted else { continue }
                Task { await enrich(workout, using: store) }
            }
        } catch {
            message = "Yarms could not read its saved workouts."
        }
    }

    private func enrich(_ workout: Workout, using store: WorkoutStore) async {
        let result = await TikTokMetadataClient().enrich(workout.playbackLink)
        do {
            try store.applyEnrichment(result, to: workout.id)
            workouts = try store.load()
        } catch {
            message = "Yarms saved the link but could not update its details."
        }
        enriching.remove(workout.id)
    }

    private func delete(at offsets: IndexSet) {
        guard let store = WorkoutStore.live() else { return }
        let selected = offsets.map { visibleWorkouts[$0].id }
        do {
            for id in selected { try store.remove(id) }
            workouts = try store.load()
        } catch {
            message = "Yarms could not remove that workout."
        }
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: workout.thumbnailURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary)
                }
            }
            .frame(width: 72, height: 88)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title ?? "TikTok workout")
                    .font(.headline)
                    .lineLimit(2)
                if let creator = workout.creator {
                    Text(creator).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(workout.sourceLink.url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}
