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
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var workouts: [Workout] = []
    @State private var folders: [WorkoutFolder] = []
    @State private var selectedFolder: FolderSelection = .all
    @State private var searchText = ""
    @State private var folderName = ""
    @State private var editingFolder: WorkoutFolder?
    @State private var showingFolderEditor = false
    @State private var showingFolderPicker = false
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
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.horizontal, YarmsTheme.Spacing.lg, for: .scrollContent)
            .frame(maxWidth: YarmsTheme.maximumContentWidth)
            .frame(maxWidth: .infinity)
            .scrollContentBackground(.hidden)
            .background(YarmsTheme.canvas.ignoresSafeArea())
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
            .sheet(isPresented: $showingFolderPicker) { folderPicker }
            .sheet(item: $movingWorkout) { workout in
                moveSheet(for: workout)
            }
            .fileExporter(isPresented: $showingExporter, document: backupDocument,
                          contentType: .json, defaultFilename: "yarms Backup") { result in
                backupDocument = nil
                switch result {
                case .success:
                    if exportedBackupExceedsImportLimit {
                        showMessage("Backup exported", "Keep this file private. It exceeds this version's 10 MB restore limit, so yarms cannot import it yet.")
                    } else {
                        showMessage("Backup exported", "Your backup includes workout links, notes, and folders. Keep the file somewhere private.")
                    }
                case .failure(let error):
                    if !isCancellation(error) {
                        showMessage("Could not export backup", "yarms could not save the backup file. Try again.")
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
            VStack(spacing: YarmsTheme.Spacing.md) {
                YarmsEmptyState(title: "No workouts yet", symbol: "figure.strengthtraining.traditional",
                                message: "Save a workout that catches your eye. It will be here when you’re ready.")
                Button("Restore a backup", systemImage: "square.and.arrow.down") {
                    showingImporter = true
                }
                .buttonStyle(YarmsSecondaryButtonStyle())
            }
            .padding(.vertical, YarmsTheme.Spacing.xl)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        } else if visibleWorkouts.isEmpty {
            VStack(spacing: YarmsTheme.Spacing.md) {
                YarmsEmptyState(title: emptySelectionTitle,
                                symbol: searchText.isEmpty ? (selectedFolder == .unfiled ? "tray" : "folder") : "magnifyingglass",
                                message: emptySelectionDescription)
                if searchText.isEmpty && selectedFolder != .all {
                    Button("Show all workouts") { selectedFolder = .all }
                        .buttonStyle(YarmsSecondaryButtonStyle())
                }
            }
            .padding(.vertical, YarmsTheme.Spacing.xl)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        } else {
            workoutRows
        }
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: YarmsTheme.Spacing.md) {
            if searchText.isEmpty {
                Text(workouts.isEmpty ? "Your next move starts here." : "Ready when you are.")
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Share a TikTok to yarms, or paste a link to keep it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: YarmsTheme.Spacing.md))
                : AnyLayout(HStackLayout(spacing: YarmsTheme.Spacing.md))
            layout {
                Label("Save a workout", systemImage: "plus.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                pasteButton(identifier: pasteButtonIdentifier)
                    .controlSize(.large)
                    .tint(YarmsTheme.action)
                    .frame(minHeight: YarmsTheme.minimumTarget)
            }
            .padding(YarmsTheme.Spacing.lg)
            .background(YarmsTheme.surface,
                        in: RoundedRectangle(cornerRadius: YarmsTheme.Radius.surface))
        }
        .padding(.top, YarmsTheme.Spacing.lg)
        .padding(.bottom, YarmsTheme.Spacing.sm)
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
            .listRowInsets(EdgeInsets(top: YarmsTheme.Spacing.sm, leading: 0, bottom: YarmsTheme.Spacing.md, trailing: 0))
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
                    WorkoutCardContent(workout: workout, folderName: workout.folderID.flatMap { namesByID[$0] })
                }
                .accessibilityIdentifier("workout-\(workout.sourceLink.videoID ?? workout.id.uuidString)")
                .listRowBackground(
                    RoundedRectangle(cornerRadius: YarmsTheme.Radius.surface, style: .continuous)
                        .fill(YarmsTheme.surface)
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: YarmsTheme.Spacing.xs, leading: 0, bottom: YarmsTheme.Spacing.xs, trailing: 0))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Move", systemImage: "folder") { movingWorkout = workout }
                        .tint(YarmsTheme.action)
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        workoutPendingDeletion = workout
                        showingDeleteWorkout = true
                    }
                    .accessibilityIdentifier("deleteWorkoutSwipeButton")
                }
            }
        }
    }

    private var usesFolderPicker: Bool {
        typeSize.isAccessibilitySize || folders.count > 6 || folders.contains { $0.name.count > 24 }
    }

    private var selectedFolderTitle: String {
        switch selectedFolder {
        case .all: return "All"
        case .unfiled: return "Unfiled"
        case .folder(let id): return folders.first { $0.id == id }?.name ?? "All"
        }
    }

    private var folderBar: some View {
        let counts = FolderCounts(workouts: workouts)
        return VStack(alignment: .leading, spacing: YarmsTheme.Spacing.sm) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: YarmsTheme.Spacing.sm) {
                    Text("Folders").font(.headline).accessibilityAddTraits(.isHeader)
                    newFolderButton
                }
            } else {
                HStack {
                    Text("Folders").font(.headline).accessibilityAddTraits(.isHeader)
                    Spacer()
                    newFolderButton
                }
            }
            if usesFolderPicker {
                Button { showingFolderPicker = true } label: {
                    HStack(spacing: YarmsTheme.Spacing.sm) {
                        Text(selectedFolderTitle).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Text("\(counts.count(for: selectedFolder))").monospacedDigit()
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(YarmsSecondaryButtonStyle())
                .accessibilityLabel("Choose folder")
                .accessibilityValue(selectedFolderTitle)
                .accessibilityIdentifier("folderPickerButton")
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: YarmsTheme.Spacing.sm) {
                        folderChip("All", count: counts.total, selection: .all, identifier: "folder-all")
                        folderChip("Unfiled", count: counts.unfiled,
                                   selection: .unfiled, identifier: "folder-unfiled")
                        ForEach(folders) { folder in
                            folderChip(folder.name, count: counts.byID[folder.id] ?? 0,
                                       selection: .folder(folder.id), identifier: "folder-\(folder.id.uuidString)")
                                .contextMenu {
                                    Button("Rename folder", systemImage: "pencil") { prepareRename(folder) }
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
        }
        .padding(.top, YarmsTheme.Spacing.md)
        .padding(.bottom, YarmsTheme.Spacing.sm)
    }

    private var newFolderButton: some View {
        Button(action: prepareNewFolder) {
            Label("New folder", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: YarmsTheme.minimumTarget)
        }
        .accessibilityIdentifier("newFolderButton")
    }

    private func folderChip(_ title: String, count: Int, selection: FolderSelection,
                            identifier: String) -> some View {
        FolderFilter(title: title, count: count, isSelected: selectedFolder == selection) {
            selectedFolder = selection
        }
        .accessibilityIdentifier(identifier)
    }

    private var folderPicker: some View {
        let counts = FolderCounts(workouts: workouts)
        return NavigationStack {
            List {
                folderChoice("All", symbol: "square.grid.2x2", count: counts.total,
                             selection: .all, identifier: "folder-all")
                folderChoice("Unfiled", symbol: "tray", count: counts.unfiled,
                             selection: .unfiled, identifier: "folder-unfiled")
                ForEach(folders) { folder in
                    folderChoice(folder.name, symbol: "folder", count: counts.byID[folder.id] ?? 0,
                                 selection: .folder(folder.id), identifier: "folder-\(folder.id.uuidString)")
                }
            }
            .navigationTitle("Choose folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showingFolderPicker = false }
                }
            }
        }
        .tint(YarmsTheme.accent)
        .presentationDetents([.large])
    }

    private func folderChoice(_ title: String, symbol: String, count: Int,
                              selection: FolderSelection, identifier: String) -> some View {
        Button {
            selectedFolder = selection
            showingFolderPicker = false
        } label: {
            HStack(spacing: YarmsTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: YarmsTheme.Spacing.xs) {
                    Label(title, systemImage: symbol)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(count) \(count == 1 ? "workout" : "workouts")")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if selectedFolder == selection { Image(systemName: "checkmark") }
            }
            .frame(minHeight: YarmsTheme.minimumTarget)
        }
        .accessibilityLabel("\(title), \(count) \(count == 1 ? "workout" : "workouts")")
        .accessibilityAddTraits(selectedFolder == selection ? .isSelected : [])
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
            showMessage("Could not update workouts", "yarms could not access its saved links.")
            return
        }
        do {
            try inbox.save(link)
            selectedFolder = .unfiled
            refresh()
        } catch {
            showMessage("Could not update workouts", "yarms could not save that link.")
        }
    }

    @discardableResult
    private func refresh(showNewShares: Bool = false) -> Bool {
        guard let store = WorkoutStore.live() else {
            showMessage("Could not update workouts", "yarms could not access its saved workouts.")
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
            showMessage("Could not update workouts", "yarms could not read its saved workouts.")
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
            showMessage("Could not update workouts", "yarms saved the link but could not update its details.")
        }
        enrichmentQueue.finish(workout.id)
        scheduleEnrichment(using: store)
    }

    private func deleteSelectedWorkout() {
        defer { workoutPendingDeletion = nil }
        guard let workout = workoutPendingDeletion else { return }
        if !removeWorkout(workout) {
            showMessage("Could not delete workout", "The saved workout could not be removed. Select it again from the library and retry.")
        }
    }

    private func removeWorkout(_ workout: Workout) -> Bool {
        guard let store = WorkoutStore.live() else { return false }
        do {
            guard try store.remove(workout.id) else {
                // Enrichment may have combined this selection with an older save.
                workouts = try store.load()
                enrichmentQueue.reset(with: workouts)
                return false
            }
            workouts.removeAll { $0.id == workout.id }
            enrichmentQueue.reset(with: workouts)
            return true
        } catch {
            return false
        }
    }

    private func exportBackup() {
        guard let store = WorkoutStore.live() else {
            showMessage("Could not export backup", "yarms could not access its saved workouts.")
            return
        }
        do {
            let data = try store.exportBackup()
            exportedBackupExceedsImportLimit = data.count > WorkoutBackup.maximumBytes
            backupDocument = WorkoutBackupDocument(data: data)
            showingExporter = true
        } catch {
            showMessage("Could not export backup", "yarms could not prepare the backup file.")
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            if !isCancellation(error) {
                showMessage("Could not read backup", "Choose a yarms JSON backup file and try again.")
            }
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingBackup = try WorkoutBackup.load(from: url)
                confirmingRestore = true
            } catch let error as WorkoutBackup.BackupError where error == .tooLarge {
                showMessage("Backup too large", "Choose a yarms backup smaller than 10 MB.")
            } catch {
                showMessage("Could not read backup", "This file is not a supported yarms backup.")
            }
        }
    }

    private func restoreBackup() {
        guard let backup = pendingBackup, let store = WorkoutStore.live() else {
            showMessage("Could not restore backup", "yarms could not access its saved workouts.")
            return
        }
        pendingBackup = nil
        do {
            let result = try store.restoreBackup(backup)
            if !refresh() {
                workouts = (try? store.load()) ?? workouts
                folders = (try? store.loadFolders()) ?? folders
                showMessage("Backup restored", "The backup was restored, but yarms could not refresh every pending link. Reopen the app to refresh the library.")
                return
            }
            showMessage("Backup restored", "Added \(result.added) workouts; updated or combined \(result.updated) existing records.")
        } catch {
            showMessage("Could not restore backup", "yarms could not save the backup. Try again.")
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
