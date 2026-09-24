import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LibraryShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var workouts: [Workout] = []
    @State private var searchText = ""
    @State private var enrichmentQueue = WorkoutEnrichmentQueue()
    @State private var message: String?
    @State private var messageTitle = "Could not update workouts"
    @State private var backupDocument: WorkoutBackupDocument?
    @State private var exportedBackupExceedsImportLimit = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingBackup: WorkoutBackup?
    @State private var confirmingRestore = false

    private var visibleWorkouts: [Workout] {
        workouts.filter { $0.matches(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "No workouts yet",
                            systemImage: "figure.strengthtraining.traditional",
                            description: Text("Share a TikTok workout to Yarms, or paste its link here.")
                        )
                        pasteButton(identifier: "emptyPasteLinkButton")
                            .tint(.purple)
                        Button("Restore a backup", systemImage: "square.and.arrow.down") {
                            showingImporter = true
                        }
                        .buttonStyle(.bordered)
                    }
                } else if visibleWorkouts.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "No matching workouts",
                            systemImage: "magnifyingglass",
                            description: Text("Try a different title, creator, or link.")
                        )
                        pasteButton(identifier: "noMatchesPasteLinkButton")
                            .tint(.purple)
                    }
                } else {
                    List {
                        HStack {
                            pasteButton(identifier: "libraryPasteLinkButton")
                            Text("a TikTok link")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(visibleWorkouts) { workout in
                            NavigationLink {
                                EmbeddedPlayerView(workout: workout) {
                                    _ = refresh()
                                }
                            } label: {
                                WorkoutRow(workout: workout)
                            }
                            .accessibilityIdentifier("workout-\(workout.sourceLink.videoID ?? workout.id.uuidString)")
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("yarms")
            .searchable(text: $searchText, prompt: "Search workouts")
            .toolbar {
                Menu {
                    Button("Export backup", systemImage: "square.and.arrow.up", action: exportBackup)
                        .disabled(workouts.isEmpty)
                    Button("Restore backup", systemImage: "square.and.arrow.down") {
                        showingImporter = true
                    }
                } label: {
                    Label("Backup", systemImage: "externaldrive")
                }
                .accessibilityLabel("Backup and restore")
            }
            .alert(messageTitle, isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
            .confirmationDialog("Restore this backup?", isPresented: $confirmingRestore,
                                titleVisibility: .visible) {
                Button("Restore \(pendingBackup?.workouts.count ?? 0) workouts") {
                    restoreBackup()
                }
                Button("Cancel", role: .cancel) { pendingBackup = nil }
            } message: {
                Text("Current workouts and notes stay on this iPhone. Distinct notes from the backup are added.")
            }
            .fileExporter(isPresented: $showingExporter, document: backupDocument,
                          contentType: .json, defaultFilename: "Yarms Backup") { result in
                backupDocument = nil
                switch result {
                case .success:
                    if exportedBackupExceedsImportLimit {
                        showMessage("Backup exported", "Keep this file private. It exceeds this version's 10 MB restore limit, so Yarms cannot import it yet.")
                    } else {
                        showMessage("Backup exported", "Your backup includes workout links and notes. Keep the file somewhere private.")
                    }
                case .failure(let error):
                    if !isCancellation(error) {
                        showMessage("Could not export backup", "Yarms could not save the backup file. Try again.")
                    }
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
            .onAppear { refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
        }
    }

    private func pasteButton(identifier: String) -> some View {
        PasteButton(payloadType: String.self) { strings in
            pasteLink(strings.first)
        }
        .accessibilityIdentifier(identifier)
    }

    private func pasteLink(_ pastedText: String?) {
        guard let text = pastedText,
              let link = TikTokLink(text: text) else {
            showMessage("Could not update workouts", "Copy a TikTok video link, then try again.")
            return
        }
        guard let inbox = SharedInbox.live() else {
            showMessage("Could not update workouts", "Yarms could not access its saved links.")
            return
        }
        do {
            try inbox.save(link)
            refresh()
        } catch {
            showMessage("Could not update workouts", "Yarms could not save that link.")
        }
    }

    @discardableResult
    private func refresh() -> Bool {
        guard let store = WorkoutStore.live() else {
            showMessage("Could not update workouts", "Yarms could not access its saved workouts.")
            return false
        }
        do {
            workouts = try store.importPending()
            enrichmentQueue.reset(with: workouts)
            scheduleEnrichment(using: store)
            return true
        } catch {
            showMessage("Could not update workouts", "Yarms could not read its saved workouts.")
            return false
        }
    }

    private func scheduleEnrichment(using store: WorkoutStore) {
        for workout in enrichmentQueue.takeAvailable() {
            Task { await enrich(workout, using: store) }
        }
    }

    private func enrich(_ workout: Workout, using store: WorkoutStore) async {
        let result = await TikTokMetadataClient().enrich(workout.playbackLink)
        do {
            try store.applyEnrichment(result, to: workout.id)
            workouts = try store.load()
        } catch {
            showMessage("Could not update workouts", "Yarms saved the link but could not update its details.")
        }
        enrichmentQueue.finish(workout.id)
        scheduleEnrichment(using: store)
    }

    private func delete(at offsets: IndexSet) {
        guard let store = WorkoutStore.live() else { return }
        let selected = offsets.map { visibleWorkouts[$0].id }
        do {
            for id in selected { try store.remove(id) }
            workouts = try store.load()
        } catch {
            showMessage("Could not update workouts", "Yarms could not remove that workout.")
        }
    }

    private func exportBackup() {
        guard let store = WorkoutStore.live() else {
            showMessage("Could not export backup", "Yarms could not access its saved workouts.")
            return
        }
        do {
            let data = try store.exportBackup()
            exportedBackupExceedsImportLimit = data.count > WorkoutBackup.maximumBytes
            backupDocument = WorkoutBackupDocument(data: data)
            showingExporter = true
        } catch {
            showMessage("Could not export backup", "Yarms could not prepare the backup file.")
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            if !isCancellation(error) {
                showMessage("Could not read backup", "Choose a Yarms JSON backup file and try again.")
            }
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingBackup = try WorkoutBackup.load(from: url)
                confirmingRestore = true
            } catch let error as WorkoutBackup.BackupError where error == .tooLarge {
                showMessage("Backup too large", "Choose a Yarms backup smaller than 10 MB.")
            } catch {
                showMessage("Could not read backup", "This file is not a supported Yarms backup.")
            }
        }
    }

    private func restoreBackup() {
        guard let backup = pendingBackup, let store = WorkoutStore.live() else {
            showMessage("Could not restore backup", "Yarms could not access its saved workouts.")
            return
        }
        pendingBackup = nil
        do {
            let result = try store.restoreBackup(backup)
            if !refresh() {
                workouts = (try? store.load()) ?? workouts
                showMessage("Backup restored", "The backup was restored, but Yarms could not refresh every pending link. Reopen the app to refresh the library.")
                return
            }
            showMessage("Backup restored", "Added \(result.added) workouts; updated or combined \(result.updated) existing records.")
        } catch {
            showMessage("Could not restore backup", "Yarms could not save the backup. Try again.")
        }
    }

    private func showMessage(_ title: String, _ detail: String) {
        messageTitle = title
        message = detail
    }

    private func isCancellation(_ error: Error) -> Bool {
        let cocoaError = error as NSError
        return cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSUserCancelledError
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
