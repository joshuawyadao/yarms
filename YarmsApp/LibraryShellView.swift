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
    @State private var retryingDetails = false
    @State private var snapshotRevision: UInt64 = 0
    @State private var enrichmentQueue = WorkoutEnrichmentQueue()
    @State private var message: String?
    @State private var messageTitle = "Could not update workouts"
    @State private var backupDocument: WorkoutBackupDocument?
    @State private var exportedBackupExceedsImportLimit = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingBackup: WorkoutBackup?
    @State private var confirmingRestore = false
    @State private var saveConfirmation: String?
    @State private var saveEventID = 0
    @State private var celebratesSave = false

    private var nextRetryDate: Date? {
        WorkoutEnrichmentQueue.nextRetryDate(in: workouts, isActive: scenePhase == .active)
    }

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
                Button("Retry workout details", systemImage: "arrow.clockwise") { retryMetadata() }
                    .disabled(workouts.isEmpty || enrichmentQueue.hasActiveRequests || retryingDetails)
                    .accessibilityIdentifier("retryWorkoutDetailsButton")
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
            .task(id: nextRetryDate) {
                guard let date = nextRetryDate, scenePhase == .active else { return }
                let delay = max(0, date.timeIntervalSinceNow)
                do { try await Task.sleep(for: .seconds(delay)) }
                catch { return }
                guard !Task.isCancelled, scenePhase == .active else { return }
                await refresh()
            }
            .onAppear {
                saveConfirmation = nil
                Task { await refresh(showNewShares: true) }
            }
            .onChange(of: searchText) { _, _ in saveConfirmation = nil }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refresh(showNewShares: true) }
                } else {
                    saveConfirmation = nil
                }
            }
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        if workouts.isEmpty {
            VStack(spacing: YarmsTheme.Spacing.md) {
                YarmsEmptyState(title: "No workouts yet", symbol: "figure.strengthtraining.traditional",
                                message: "Spot a move you’d love to try? Save it here for your next workout.")
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
                Text(workouts.isEmpty ? "Your next move starts here." : "Find your feel-good move.")
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(workouts.isEmpty
                     ? "Share a TikTok to yarms, or paste a link to keep it here."
                     : "Pick a workout to try today, or save a new one for later.")
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
            YarmsSaveConfirmation(message: saveConfirmation, eventID: saveEventID,
                                  celebrates: celebratesSave)
                .accessibilityIdentifier("librarySaveConfirmation")
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
                        onNotesSaved: { Task { await refresh() } },
                        onFolderChanged: { destination in await moveWorkout(workout, to: destination) },
                        onDeleteWorkout: { await removeWorkout(workout) }
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
        .buttonStyle(YarmsPlainButtonStyle())
        .accessibilityIdentifier("newFolderButton")
    }

    private func folderChip(_ title: String, count: Int, selection: FolderSelection,
                            identifier: String) -> some View {
        FolderFilter(title: title, count: count, isSelected: selectedFolder == selection) {
            saveConfirmation = nil
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
            saveConfirmation = nil
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
        saveConfirmation = nil
        guard let store = WorkoutStore.live() else { return }
        let editing = editingFolder
        let name = folderName
        Task { @MainActor in
            do {
                let created = try await store.perform { store -> WorkoutFolder? in
                    if let editing {
                        guard try store.renameFolder(editing.id, to: name) else {
                            throw WorkoutStore.StoreError.invalidFolderReference
                        }
                        return nil
                    }
                    return try store.createFolder(named: name)
                }
                if let created { selectedFolder = .folder(created.id) }
                editingFolder = nil
                await refresh()
            } catch {
                showMessage("Could not save folder", "Use a different, nonempty folder name and try again.")
            }
        }
    }

    private func deleteSelectedFolder() {
        saveConfirmation = nil
        guard let folder = folderPendingDeletion, let store = WorkoutStore.live() else { return }
        folderPendingDeletion = nil
        Task { @MainActor in
            do {
                if try await store.perform({ try $0.deleteFolder(folder.id) }) {
                    if selectedFolder == .folder(folder.id) { selectedFolder = .unfiled }
                    await refresh()
                }
            } catch {
                showMessage("Could not delete folder", "Your workouts are still saved. Try again.")
            }
        }
    }

    private func finishMove(_ workout: Workout, to folderID: UUID?) {
        Task { @MainActor in
            if await moveWorkout(workout, to: folderID) { movingWorkout = nil }
        }
    }

    @MainActor
    private func moveWorkout(_ workout: Workout, to folderID: UUID?) async -> Bool {
        saveConfirmation = nil
        guard let store = WorkoutStore.live() else { return false }
        do {
            guard try await store.perform({ try $0.moveWorkout(workout.id, to: folderID) }) else {
                showMessage("Could not move workout", "This workout changed. Reopen it and try again.")
                return false
            }
            await refresh()
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
        saveConfirmation = nil
        guard let text = pastedText,
              let link = TikTokLink(text: text) else {
            showMessage("Could not update workouts", "Copy a TikTok video link, then try again.")
            return
        }
        guard let inbox = SharedInbox.live() else {
            showMessage("Could not update workouts", "yarms could not access its saved links.")
            return
        }
        guard let store = WorkoutStore.live() else { return }
        Task { @MainActor in
            do {
                let pending = try await store.perform { _ in try inbox.save(link) }
                selectedFolder = .unfiled
                guard await refresh() else { return }
                let isNew = workouts.contains { $0.id == pending.id }
                if !isNew { selectedFolder = .all }
                confirmSave(isNew ? "Saved for your next move." : "Already in your library.",
                            celebrates: isNew)
            } catch {
                showMessage("Could not update workouts", "yarms could not save that link.")
            }
        }
    }

    @MainActor @discardableResult
    private func refresh(showNewShares: Bool = false) async -> Bool {
        guard let store = WorkoutStore.live() else { return false }
        do {
            let snapshot = try await store.perform { try $0.refresh() }
            guard applySnapshot(snapshot) else { return true }
            selectedFolder = FolderSelection.afterImport(
                selectedFolder, previousIDs: snapshot.previousIDs, imported: snapshot.workouts,
                showNewShares: showNewShares
            )
            let addedCount = snapshot.workouts.filter { !snapshot.previousIDs.contains($0.id) }.count
            if showNewShares && addedCount > 0 {
                confirmSave(addedCount == 1 ? "Saved for your next move." : "\(addedCount) workouts saved for later.",
                            celebrates: true)
            }
            scheduleEnrichment(using: store)
            return true
        } catch {
            showMessage("Could not update workouts", "yarms could not read its saved workouts.")
            return false
        }
    }

    @discardableResult
    private func applySnapshot(_ snapshot: WorkoutStore.LibrarySnapshot) -> Bool {
        guard snapshot.revision >= snapshotRevision else { return false }
        snapshotRevision = snapshot.revision
        workouts = snapshot.workouts
        folders = snapshot.folders
        if case .folder(let id) = selectedFolder, !folders.contains(where: { $0.id == id }) {
            selectedFolder = .all
        }
        enrichmentQueue.reset(with: workouts)
        return true
    }

    private func retryMetadata() {
        guard !enrichmentQueue.hasActiveRequests, !retryingDetails else { return }
        guard let store = WorkoutStore.live() else { return }
        retryingDetails = true
        Task { @MainActor in
            do {
                applySnapshot(try await store.perform { try $0.resetEnrichmentRetry() })
                retryingDetails = false
                scheduleEnrichment(using: store)
            } catch {
                retryingDetails = false
                showMessage("Could not retry details", "Your workouts are still saved. Try again.")
            }
        }
    }

    private func confirmSave(_ text: String, celebrates: Bool) {
        saveConfirmation = text
        celebratesSave = celebrates
        saveEventID += 1
        YarmsAccessibility.announceSaveResult(text)
    }

    private func scheduleEnrichment(using store: WorkoutStore) {
        guard scenePhase == .active, !retryingDetails else { return }
        for workout in enrichmentQueue.takeAvailable() {
            Task { await enrich(workout, using: store) }
        }
    }

    @MainActor
    private func enrich(_ workout: Workout, using store: WorkoutStore) async {
        let result = await TikTokMetadataClient().enrich(workout.playbackLink)
        do {
            let snapshot = try await store.perform { try $0.applyEnrichment(result, to: workout.id) }
            enrichmentQueue.finish(workout.id)
            applySnapshot(snapshot)
        } catch {
            showMessage("Could not update workouts", "yarms saved the link but could not update its details.")
        }
        enrichmentQueue.finish(workout.id)
        scheduleEnrichment(using: store)
    }

    private func deleteSelectedWorkout() {
        guard let workout = workoutPendingDeletion else { return }
        workoutPendingDeletion = nil
        Task { @MainActor in
            if !(await removeWorkout(workout)) {
                showMessage("Could not delete workout", "The saved workout could not be removed. Select it again from the library and retry.")
            }
        }
    }

    @MainActor
    private func removeWorkout(_ workout: Workout) async -> Bool {
        saveConfirmation = nil
        guard let store = WorkoutStore.live() else { return false }
        do {
            let removed = try await store.perform { try $0.remove(workout.id) }
            await refresh()
            return removed
        } catch { return false }
    }

    private func exportBackup() {
        guard let store = WorkoutStore.live() else { return }
        Task { @MainActor in
            do {
                let data = try await store.perform { try $0.exportBackup() }
                exportedBackupExceedsImportLimit = data.count > WorkoutBackup.maximumBytes
                backupDocument = WorkoutBackupDocument(data: data)
                showingExporter = true
            } catch {
                showMessage("Could not export backup", "yarms could not prepare the backup file.")
            }
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            if !isCancellation(error) {
                showMessage("Could not read backup", "Choose a yarms JSON backup file and try again.")
            }
        case .success(let url):
            guard let store = WorkoutStore.live() else { return }
            Task { @MainActor in
                do {
                    pendingBackup = try await store.perform { _ in
                        let hasAccess = url.startAccessingSecurityScopedResource()
                        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                        return try WorkoutBackup.load(from: url)
                    }
                    confirmingRestore = true
                } catch let error as WorkoutBackup.BackupError where error == .tooLarge {
                    showMessage("Backup too large", "Choose a yarms backup smaller than 10 MB.")
                } catch {
                    showMessage("Could not read backup", "This file is not a supported yarms backup.")
                }
            }
        }
    }

    private func restoreBackup() {
        saveConfirmation = nil
        guard let backup = pendingBackup, let store = WorkoutStore.live() else { return }
        pendingBackup = nil
        Task { @MainActor in
            do {
                let result = try await store.perform { try $0.restoreBackup(backup) }
                guard await refresh() else {
                    showMessage("Backup restored", "The backup was restored, but yarms could not refresh every pending link. Reopen the app to refresh the library.")
                    return
                }
                showMessage("Backup restored", "Added \(result.added) workouts; updated or combined \(result.updated) existing records.")
            } catch {
                showMessage("Could not restore backup", "yarms could not save the backup. Try again.")
            }
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
