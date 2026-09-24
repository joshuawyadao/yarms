import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LibraryShellView: View {
    private enum FolderSelection: Equatable {
        case all
        case unfiled
        case folder(UUID)

        func includes(_ workout: Workout) -> Bool {
            switch self {
            case .all: return true
            case .unfiled: return workout.folderID == nil
            case .folder(let id): return workout.folderID == id
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    @State private var workouts: [Workout] = []
    @State private var folders: [WorkoutFolder] = []
    @State private var selectedFolder: FolderSelection = .all
    @State private var searchText = ""
    @State private var folderName = ""
    @State private var editingFolder: WorkoutFolder?
    @State private var showingFolderEditor = false
    @State private var folderPendingDeletion: WorkoutFolder?
    @State private var showingDeleteFolder = false
    @State private var movingWorkout: Workout?
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
        workouts.filter { selectedFolder.includes($0) && $0.matches(searchText) }
    }

    private var emptySelectionTitle: String {
        if !searchText.isEmpty { return "No matching workouts" }
        switch selectedFolder {
        case .all: return "No workouts yet"
        case .unfiled: return "No unfiled workouts"
        case .folder: return "This folder is empty"
        }
    }

    private var emptySelectionDescription: String {
        searchText.isEmpty
            ? "Move a saved workout here, or share another TikTok workout."
            : "Try a different title, creator, or link."
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                folderBar
                libraryContent
            }
            .navigationTitle("yarms")
            .searchable(text: $searchText, prompt: "Search workouts")
            .toolbar {
                Menu {
                    Button("New folder", systemImage: "folder.badge.plus", action: prepareNewFolder)
                    if case .folder(let id) = selectedFolder,
                       let folder = folders.first(where: { $0.id == id }) {
                        Button("Rename folder", systemImage: "pencil") { prepareRename(folder) }
                        Button("Delete folder", systemImage: "trash", role: .destructive) {
                            folderPendingDeletion = folder
                            showingDeleteFolder = true
                        }
                    }
                } label: {
                    Label("Folders", systemImage: "folder")
                }
                .accessibilityIdentifier("folderActionsButton")
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
                Text("Current workouts and notes stay on this iPhone. Backup folders and distinct notes are added.")
            }
            .alert(editingFolder == nil ? "New folder" : "Rename folder",
                   isPresented: $showingFolderEditor) {
                TextField("Folder name", text: $folderName)
                Button(editingFolder == nil ? "Create" : "Save", action: saveFolder)
                Button("Cancel", role: .cancel) { editingFolder = nil }
            } message: {
                Text("Choose a short name you can recognize while browsing workouts.")
            }
            .confirmationDialog("Delete folder?", isPresented: $showingDeleteFolder,
                                titleVisibility: .visible) {
                Button("Delete folder", role: .destructive, action: deleteSelectedFolder)
                Button("Cancel", role: .cancel) { folderPendingDeletion = nil }
            } message: {
                Text("Workouts in this folder will stay saved in Unfiled.")
            }
            .sheet(item: $movingWorkout) { workout in
                moveSheet(for: workout)
            }
            .fileExporter(isPresented: $showingExporter, document: backupDocument,
                          contentType: .json, defaultFilename: "Yarms Backup") { result in
                backupDocument = nil
                switch result {
                case .success:
                    if exportedBackupExceedsImportLimit {
                        showMessage("Backup exported", "Keep this file private. It exceeds this version's 10 MB restore limit, so Yarms cannot import it yet.")
                    } else {
                        showMessage("Backup exported", "Your backup includes workout links, notes, and folders. Keep the file somewhere private.")
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
                if phase == .active { refresh(showNewShares: true) }
            }
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
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
                    emptySelectionTitle,
                    systemImage: searchText.isEmpty ? "folder" : "magnifyingglass",
                    description: Text(emptySelectionDescription)
                )
                pasteButton(identifier: "noMatchesPasteLinkButton")
                    .tint(.purple)
                if searchText.isEmpty && selectedFolder != .all {
                    Button("Show all workouts") { selectedFolder = .all }
                        .buttonStyle(.bordered)
                }
            }
        } else {
            workoutList
        }
    }

    private var workoutList: some View {
        List {
            HStack {
                pasteButton(identifier: "libraryPasteLinkButton")
                Text("a TikTok link")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(visibleWorkouts) { workout in
                NavigationLink {
                    EmbeddedPlayerView(
                        workout: workout,
                        folders: folders,
                        onNotesSaved: { _ = refresh() },
                        onFolderChanged: { destination in moveWorkout(workout, to: destination) }
                    )
                } label: {
                    WorkoutRow(workout: workout)
                }
                .accessibilityIdentifier("workout-\(workout.sourceLink.videoID ?? workout.id.uuidString)")
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Move", systemImage: "folder") { movingWorkout = workout }
                        .tint(.purple)
                }
            }
            .onDelete(perform: delete)
        }
    }

    private var folderBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    folderChip("All", selection: .all, identifier: "folder-all")
                    folderChip("Unfiled", selection: .unfiled, identifier: "folder-unfiled")
                    ForEach(folders) { folder in
                        folderChip(folder.name, selection: .folder(folder.id),
                                   identifier: "folder-\(folder.id.uuidString)")
                            .contextMenu {
                                Button("Rename folder", systemImage: "pencil") {
                                    prepareRename(folder)
                                }
                                Button("Delete folder", systemImage: "trash", role: .destructive) {
                                    folderPendingDeletion = folder
                                    showingDeleteFolder = true
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)

            Button(action: prepareNewFolder) {
                Image(systemName: "folder.badge.plus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("New folder")
            .accessibilityIdentifier("newFolderButton")
            .padding(.trailing, 12)
        }
        .padding(.vertical, 8)
    }

    private func folderChip(_ title: String, selection: FolderSelection,
                            identifier: String) -> some View {
        let count = workouts.filter { selection.includes($0) }.count
        return Button { selectedFolder = selection } label: {
            HStack(spacing: 5) {
                Text(title).lineLimit(1)
                Text("\(count)").font(.caption.monospacedDigit())
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 13)
            .frame(minHeight: 38)
            .foregroundStyle(selectedFolder == selection ? .white : .primary)
            .background(selectedFolder == selection ? Color.purple : Color(.secondarySystemBackground),
                        in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) workouts")
        .accessibilityIdentifier(identifier)
    }

    private func moveSheet(for workout: Workout) -> some View {
        NavigationStack {
            List {
                Button { finishMove(workout, to: nil) } label: {
                    Label("Unfiled", systemImage: "tray")
                }
                .accessibilityIdentifier("moveToUnfiledButton")
                ForEach(folders) { folder in
                    Button { finishMove(workout, to: folder.id) } label: {
                        Label(folder.name, systemImage: "folder")
                    }
                    .accessibilityIdentifier("moveToFolder-\(folder.id.uuidString)")
                }
            }
            .navigationTitle("Move workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { movingWorkout = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func prepareNewFolder() {
        editingFolder = nil
        folderName = ""
        showingFolderEditor = true
    }

    private func prepareRename(_ folder: WorkoutFolder) {
        editingFolder = folder
        folderName = folder.name
        showingFolderEditor = true
    }

    private func saveFolder() {
        guard let store = WorkoutStore.live() else {
            showMessage("Could not update folders", "yarms could not access its saved workouts.")
            return
        }
        do {
            if let editingFolder {
                guard try store.renameFolder(editingFolder.id, to: folderName) else {
                    showMessage("Could not rename folder", "This folder is no longer available.")
                    return
                }
            } else {
                let created = try store.createFolder(named: folderName)
                selectedFolder = .folder(created.id)
            }
            self.editingFolder = nil
            _ = refresh()
        } catch {
            showMessage("Could not save folder", "Use a different, nonempty folder name and try again.")
        }
    }

    private func deleteSelectedFolder() {
        defer { folderPendingDeletion = nil }
        guard let folder = folderPendingDeletion, let store = WorkoutStore.live() else { return }
        do {
            if try store.deleteFolder(folder.id) {
                if selectedFolder == .folder(folder.id) { selectedFolder = .unfiled }
                _ = refresh()
            }
        } catch {
            showMessage("Could not delete folder", "Your workouts are still saved. Try again.")
        }
    }

    private func finishMove(_ workout: Workout, to folderID: UUID?) {
        if moveWorkout(workout, to: folderID) { movingWorkout = nil }
    }

    private func moveWorkout(_ workout: Workout, to folderID: UUID?) -> Bool {
        guard let store = WorkoutStore.live() else {
            showMessage("Could not move workout", "yarms could not access its saved workouts.")
            return false
        }
        do {
            guard try store.moveWorkout(workout.id, to: folderID) else {
                showMessage("Could not move workout", "This workout changed. Reopen it and try again.")
                return false
            }
            _ = refresh()
            return true
        } catch {
            showMessage("Could not move workout", "Your workout is still saved. Try again.")
            return false
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
            selectedFolder = .unfiled
            refresh()
        } catch {
            showMessage("Could not update workouts", "Yarms could not save that link.")
        }
    }

    @discardableResult
    private func refresh(showNewShares: Bool = false) -> Bool {
        guard let store = WorkoutStore.live() else {
            showMessage("Could not update workouts", "Yarms could not access its saved workouts.")
            return false
        }
        do {
            let currentIDs = Set(workouts.map(\.id))
            let imported = try store.importPending()
            folders = try store.loadFolders()
            if showNewShares && !currentIDs.isEmpty &&
                imported.contains(where: { !currentIDs.contains($0.id) }) {
                selectedFolder = .unfiled
            }
            if case .folder(let id) = selectedFolder,
               !folders.contains(where: { $0.id == id }) {
                selectedFolder = .all
            }
            workouts = imported
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
                folders = (try? store.loadFolders()) ?? folders
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
