import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LibraryShellView: View {
    enum FolderSelection: Equatable {
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

        static func afterImport(_ current: Self, previousIDs: Set<UUID>,
                                imported: [Workout], showNewShares: Bool) -> Self {
            guard showNewShares,
                  imported.contains(where: { !previousIDs.contains($0.id) }) else { return current }
            return .unfiled
        }
    }

    struct FolderCounts {
        let total: Int
        let unfiled: Int
        let byID: [UUID: Int]

        init(workouts: [Workout]) {
            total = workouts.count
            var unfiled = 0
            var byID: [UUID: Int] = [:]
            for workout in workouts {
                if let folderID = workout.folderID {
                    byID[folderID, default: 0] += 1
                } else {
                    unfiled += 1
                }
            }
            self.unfiled = unfiled
            self.byID = byID
        }

        func count(for selection: FolderSelection) -> Int {
            switch selection {
            case .all: return total
            case .unfiled: return unfiled
            case .folder(let id): return byID[id] ?? 0
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
    @State private var workoutPendingDeletion: Workout?
    @State private var showingDeleteWorkout = false
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
            List {
                saveCard
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                folderBar
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                libraryContent
            }
            .listStyle(.plain)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background(Color("YarmsCanvas").ignoresSafeArea())
            .navigationTitle("yarms")
            .navigationBarTitleDisplayMode(.inline)
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
                        .disabled(workouts.isEmpty && folders.isEmpty)
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
            .alert("Delete saved workout?", isPresented: $showingDeleteWorkout) {
                Button("Delete workout", role: .destructive, action: deleteSelectedWorkout)
                Button("Cancel", role: .cancel) { workoutPendingDeletion = nil }
            } message: {
                Text("The saved link and its notes will be removed from this iPhone. The TikTok post will not be affected.")
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
            VStack(spacing: 12) {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Share a workout from TikTok and it will appear here.")
                )
                Button("Restore a backup", systemImage: "square.and.arrow.down") {
                    showingImporter = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        } else if visibleWorkouts.isEmpty {
            VStack(spacing: 12) {
                ContentUnavailableView(
                    emptySelectionTitle,
                    systemImage: searchText.isEmpty ? "folder" : "magnifyingglass",
                    description: Text(emptySelectionDescription)
                )
                if searchText.isEmpty && selectedFolder != .all {
                    Button("Show all workouts") { selectedFolder = .all }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        } else {
            workoutRows
        }
    }

    private var saveCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Save a workout")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                Text("Share from TikTok, or paste a link")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            pasteButton(identifier: pasteButtonIdentifier)
                .tint(Color("YarmsAction"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color("YarmsSurface"))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color("YarmsBloom").opacity(0.35), lineWidth: 1)
                }
        }
        .padding(.top, 12)
    }

    private var pasteButtonIdentifier: String {
        if workouts.isEmpty { return "emptyPasteLinkButton" }
        if visibleWorkouts.isEmpty { return "noMatchesPasteLinkButton" }
        return "libraryPasteLinkButton"
    }

    private var workoutRows: some View {
        let namesByID = Dictionary(folders.map { ($0.id, $0.name) },
                                   uniquingKeysWith: { first, _ in first })
        return Group {
            HStack {
                Text("Saved workouts")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(visibleWorkouts.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 6, trailing: 4))
            ForEach(visibleWorkouts) { workout in
                NavigationLink {
                    EmbeddedPlayerView(
                        workout: workout,
                        folders: folders,
                        onNotesSaved: { _ = refresh() },
                        onFolderChanged: { destination in moveWorkout(workout, to: destination) },
                        onDeleteWorkout: { removeWorkout(workout) }
                    )
                } label: {
                    WorkoutRow(workout: workout, folderName: workout.folderID.flatMap { namesByID[$0] })
                }
                .accessibilityIdentifier("workout-\(workout.sourceLink.videoID ?? workout.id.uuidString)")
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color("YarmsSurface"))
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Move", systemImage: "folder") { movingWorkout = workout }
                        .tint(Color("YarmsAction"))
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        workoutPendingDeletion = workout
                        showingDeleteWorkout = true
                    }
                    .accessibilityIdentifier("deleteWorkoutSwipeButton")
                }
            }
        }
    }

    private var folderBar: some View {
        let counts = FolderCounts(workouts: workouts)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Folders")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: prepareNewFolder) {
                    Label("New folder", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("newFolderButton")
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    folderChip("All", count: counts.total, selection: .all, identifier: "folder-all")
                    folderChip("Unfiled", count: counts.unfiled,
                               selection: .unfiled, identifier: "folder-unfiled")
                    ForEach(folders) { folder in
                        folderChip(folder.name, count: counts.byID[folder.id] ?? 0,
                                   selection: .folder(folder.id),
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
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func folderChip(_ title: String, count: Int, selection: FolderSelection,
                            identifier: String) -> some View {
        return Button { selectedFolder = selection } label: {
            HStack(spacing: 5) {
                Text(title).lineLimit(1)
                Text("\(count)").font(.caption.monospacedDigit())
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 13)
            .frame(minHeight: 44)
            .foregroundStyle(selectedFolder == selection ? .white : .primary)
            .background(selectedFolder == selection ? Color("YarmsAction") : Color("YarmsSoft"),
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
            selectedFolder = FolderSelection.afterImport(
                selectedFolder, previousIDs: currentIDs, imported: imported,
                showNewShares: showNewShares
            )
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

    private func deleteSelectedWorkout() {
        defer { workoutPendingDeletion = nil }
        guard let workout = workoutPendingDeletion else { return }
        if !removeWorkout(workout) {
            showMessage("Could not delete workout", "The saved workout could not be removed. Try again.")
        }
    }

    private func removeWorkout(_ workout: Workout) -> Bool {
        guard let store = WorkoutStore.live() else { return false }
        do {
            try store.remove(workout.id)
            workouts.removeAll { $0.id == workout.id }
            enrichmentQueue.reset(with: workouts)
            return true
        } catch {
            return false
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
    let folderName: String?

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: workout.thumbnailURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color("YarmsSoft"))
                }
            }
            .frame(width: 84, height: 104)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(workout.title ?? "TikTok workout")
                    .font(.headline)
                    .lineLimit(2)
                if let creator = workout.creator {
                    Text(creator)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if workout.title == nil {
                    Text(sourceReference)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(spacing: 5) {
                    Image(systemName: folderName == nil ? "tray" : "folder.fill")
                    Text(folderName ?? "Unfiled")
                        .lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private var sourceReference: String {
        let url = workout.sourceLink.url
        return (url.host ?? "tiktok.com") + url.path
    }
}
