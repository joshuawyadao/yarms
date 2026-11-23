import SwiftUI
import UIKit
import WebKit

struct EmbeddedPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(PlaybackSkipInterval.preferenceKey) private var storedSkipInterval = PlaybackSkipInterval.defaultSeconds
    @StateObject private var player = TikTokPlayerController()
    @State private var notesOpen: Bool
    @State private var noteText: String
    @State private var selectedFolderID: UUID?
    @State private var noteSaved = false
    @State private var noteSaveEventID = 0
    @State private var message: String?
    @State private var messageTitle = "Could not save notes"
    @State private var showingDeleteWorkout = false
    @State private var showingWorkoutCompletion = false
    @State private var isLoggingWorkout = false
    @State private var workoutHeadingHeight: CGFloat = 0
    @FocusState private var notesFocused: Bool
    @AccessibilityFocusState(for: .voiceOver) private var finishButtonFocused: Bool

    let workout: Workout
    let folders: [WorkoutFolder]
    let onNotesSaved: () -> Void
    let onFolderChanged: (UUID?) async -> Bool
    let onDeleteWorkout: () async -> Bool
    let onLogWorkout: () async -> Bool

    init(workout: Workout, folders: [WorkoutFolder], onNotesSaved: @escaping () -> Void,
         onFolderChanged: @escaping (UUID?) async -> Bool, onDeleteWorkout: @escaping () async -> Bool,
         onLogWorkout: @escaping () async -> Bool) {
        self.workout = workout
        self.folders = folders
        self.onNotesSaved = onNotesSaved
        self.onFolderChanged = onFolderChanged
        self.onDeleteWorkout = onDeleteWorkout
        self.onLogWorkout = onLogWorkout
        _notesOpen = State(initialValue: workout.notes != nil)
        _noteText = State(initialValue: workout.notes ?? "")
        _selectedFolderID = State(initialValue: workout.folderID)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: YarmsTheme.Spacing.xl) {
                    workoutHeading
                        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                            workoutHeadingHeight = height
                        }

                    if let playerURL = workout.playbackLink.playerURL,
                       let html = TikTokPlayerHTML.presentationDocument(for: playerURL) {
                        let playerWidth = playerViewportWidth(in: geometry.size)
                        TikTokWebPlayer(html: html, controller: player)
                            .frame(width: playerWidth, height: playerWidth * 16 / 9)
                            .frame(maxWidth: .infinity)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: YarmsTheme.Radius.media))
                            .overlay {
                                RoundedRectangle(cornerRadius: YarmsTheme.Radius.media)
                                    .strokeBorder(Color.white.opacity(0.12))
                            }

                        if player.hasError {
                            Label("This video couldn't play here. Open it in TikTok below.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if !player.isReady {
                            Label("Loading video. Player controls will be available when it's ready.",
                                  systemImage: "play.rectangle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                    } else {
                        YarmsEmptyState(
                            title: "Player unavailable",
                            symbol: "play.slash",
                            message: "Open this workout in TikTok to watch it."
                        )
                    }

                    Button(action: logWorkout) {
                        Label("Log workout", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(YarmsSecondaryButtonStyle())
                    .disabled(isLoggingWorkout)
                    .accessibilityIdentifier("finishWorkoutButton")
                    .accessibilityFocused($finishButtonFocused)

                    DisclosureGroup(isExpanded: $notesOpen) {
                        TextEditor(text: $noteText)
                            .frame(minHeight: 110)
                            .accessibilityLabel("Workout notes")
                            .focused($notesFocused)
                            .scrollContentBackground(.hidden)
                            .padding(YarmsTheme.Spacing.sm)
                            .background(YarmsTheme.canvas, in: RoundedRectangle(cornerRadius: YarmsTheme.Radius.control))
                            .overlay {
                                RoundedRectangle(cornerRadius: YarmsTheme.Radius.control)
                                    .strokeBorder(YarmsTheme.soft, lineWidth: 1)
                            }
                            .onChange(of: noteText) { _, _ in noteSaved = false }
                        if typeSize.isAccessibilitySize {
                            noteActionsVertical
                        } else {
                            ViewThatFits(in: .horizontal) {
                                noteActions
                                noteActionsVertical
                            }
                        }
                    } label: {
                        Label("Notes (optional)", systemImage: "square.and.pencil")
                            .font(.headline.weight(.semibold))
                    }
                    .tint(YarmsTheme.accent)
                    .padding(YarmsTheme.Spacing.lg)
                    .background(YarmsTheme.surface, in: RoundedRectangle(cornerRadius: YarmsTheme.Radius.surface))
                }
                .padding(.horizontal, YarmsTheme.Spacing.lg)
                .padding(.top, YarmsTheme.Spacing.lg)
                .padding(.bottom, YarmsTheme.Spacing.xl)
                .frame(maxWidth: YarmsTheme.maximumContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(YarmsTheme.canvas)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: YarmsTheme.Spacing.sm) {
                if workout.playbackLink.playerURL != nil {
                    playbackControls
                }
                Button {
                    openURL(workout.playbackLink.url)
                } label: {
                    Label("Open in TikTok", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(YarmsActionButtonStyle())
                .accessibilityIdentifier("openInTikTokButton")
            }
            .padding(.horizontal, YarmsTheme.Spacing.lg)
            .padding(.top, YarmsTheme.Spacing.sm)
            .padding(.bottom, YarmsTheme.Spacing.sm)
            .frame(maxWidth: YarmsTheme.maximumContentWidth)
            .frame(maxWidth: .infinity)
            .background(YarmsTheme.surface)
            .overlay(alignment: .top) { Rectangle().fill(YarmsTheme.soft).frame(height: 1) }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingWorkoutCompletion, onDismiss: {
            finishButtonFocused = true
        }) {
            WorkoutCompletionView()
                .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(YarmsTheme.canvas)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Unfiled", systemImage: selectedFolderID == nil ? "checkmark" : "tray") {
                        selectFolder(nil)
                    }
                    ForEach(folders) { folder in
                        Button(folder.name,
                               systemImage: selectedFolderID == folder.id ? "checkmark" : "folder") {
                            selectFolder(folder.id)
                        }
                    }
                } label: {
                    Label("Move to folder", systemImage: "folder")
                }
                .accessibilityIdentifier("workoutFolderMenu")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete workout", systemImage: "trash", role: .destructive) {
                    showingDeleteWorkout = true
                }
                .accessibilityIdentifier("deleteWorkoutDetailButton")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { notesFocused = false }
            }
        }
        .alert("Delete saved workout?", isPresented: $showingDeleteWorkout) {
            Button("Delete workout", role: .destructive) {
                Task { @MainActor in
                    if await onDeleteWorkout() { dismiss() }
                    else {
                        messageTitle = "Could not delete workout"
                        message = "The saved workout could not be removed. Return to the library, select it again, and retry."
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved link and its notes from this device. Your workout history stays.")
        }
        .alert(messageTitle, isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func playerViewportWidth(in size: CGSize) -> CGFloat {
        let availableWidth = max(0, min(size.width, YarmsTheme.maximumContentWidth) - 2 * YarmsTheme.Spacing.lg)
        guard UIDevice.current.userInterfaceIdiom == .pad else { return availableWidth }

        // The safe-area inset already reserves the playback tray. Fit the video
        // beneath the heading and keep it usable in very short, scrollable windows.
        let headingSpace = workoutHeadingHeight + YarmsTheme.Spacing.lg + YarmsTheme.Spacing.xl
        let availableHeight = max(160, size.height - headingSpace)
        return min(availableWidth, availableHeight * 9 / 16)
    }

    private var noteActions: some View {
        HStack(spacing: YarmsTheme.Spacing.md) {
            Button("Save notes", action: saveNotes)
                .buttonStyle(YarmsSecondaryButtonStyle())
            noteSaveConfirmation
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var noteActionsVertical: some View {
        VStack(alignment: .leading, spacing: YarmsTheme.Spacing.sm) {
            Button("Save notes", action: saveNotes)
                .buttonStyle(YarmsSecondaryButtonStyle())
            noteSaveConfirmation
        }
    }

    private var noteSaveConfirmation: some View {
        YarmsSaveConfirmation(message: noteSaved ? "Saved on this device" : nil,
                              eventID: noteSaveEventID, placeholder: "Saved on this device")
            .accessibilityIdentifier("noteSaveConfirmation")
    }

    private var workoutHeading: some View {
        VStack(alignment: .leading, spacing: YarmsTheme.Spacing.sm) {
            Text(workout.displayTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("workoutHeading")

            if typeSize.isAccessibilitySize {
                metadataVertical
            } else {
                ViewThatFits(in: .horizontal) {
                    metadataHorizontal
                    metadataVertical
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataHorizontal: some View {
        HStack(spacing: YarmsTheme.Spacing.sm) {
            if let creator = workout.creator {
                Text(creator)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            FolderBadge(name: selectedFolderName)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var metadataVertical: some View {
        VStack(alignment: .leading, spacing: YarmsTheme.Spacing.sm) {
            if let creator = workout.creator {
                Text(creator)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FolderBadge(name: selectedFolderName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedFolderName: String? {
        folders.first(where: { $0.id == selectedFolderID })?.name
    }

    private func selectFolder(_ id: UUID?) {
        Task { @MainActor in
            if await onFolderChanged(id) { selectedFolderID = id }
        }
    }

    private var playbackControls: some View {
        let skipInterval = PlaybackSkipInterval.supportedSeconds(storedSkipInterval)
        return VStack(spacing: YarmsTheme.Spacing.sm) {
            HStack(spacing: YarmsTheme.Spacing.md) {
                Button { player.seek(by: -Double(skipInterval)) } label: {
                    Image(systemName: "gobackward.\(skipInterval)")
                }
                .accessibilityLabel("Back \(skipInterval) seconds")
                .accessibilityIdentifier("skipBackwardButton")

                Button {
                    player.send(player.isPlaying ? .pause : .play)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button { player.seek(by: Double(skipInterval)) } label: {
                    Image(systemName: "goforward.\(skipInterval)")
                }
                .accessibilityLabel("Forward \(skipInterval) seconds")
                .accessibilityIdentifier("skipForwardButton")

                Button { player.send(.seekTo(0)) } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Replay from start")
            }
            .buttonStyle(CompactPlaybackButtonStyle())
            .disabled(!player.isReady || player.hasError)
            .opacity(!player.isReady || player.hasError ? 0.45 : 1)
            .frame(maxWidth: .infinity)

            if player.duration > 0 {
                Text("\(timeLabel(player.currentTime)) / \(timeLabel(player.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func timeLabel(_ seconds: Double) -> String {
        let whole = Int(min(max(0, seconds), 86_400))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private func logWorkout() {
        guard !isLoggingWorkout, !showingWorkoutCompletion else { return }
        isLoggingWorkout = true
        notesFocused = false
        player.send(.pause)

        Task { @MainActor in
            defer { isLoggingWorkout = false }
            if await onLogWorkout() {
                showingWorkoutCompletion = true
            } else {
                messageTitle = "Could not log workout"
                message = "Try logging this workout again."
            }
        }
    }

    private func saveNotes() {
        let wasSaved = noteSaved
        noteSaved = false
        messageTitle = "Could not save notes"
        guard let store = WorkoutStore.live() else {
            message = "yarms could not access its saved workouts."
            return
        }
        let text = noteText
        let id = workout.id
        Task { @MainActor in
            do {
                if try await store.perform({ try $0.updateNotes(text, for: id) }) {
                    noteSaved = noteText == text
                    if noteSaved && !wasSaved {
                        noteSaveEventID += 1
                        YarmsAccessibility.announceSaveResult("Saved on this device")
                    }
                    onNotesSaved()
                } else {
                    message = "This workout changed while you were editing. Reopen it and try again."
                }
            } catch {
                message = "Your notes could not be saved. Try again."
            }
        }
    }
}

private enum PlaybackSkipInterval {
    static let preferenceKey = "yarms.playbackSkipInterval"
    static let defaultSeconds = 10
    static let choices = [5, 10, 15, 30]

    static func supportedSeconds(_ value: Int) -> Int {
        choices.contains(value) ? value : defaultSeconds
    }
}

struct YarmsPlaybackSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PlaybackSkipInterval.preferenceKey) private var storedSkipInterval = PlaybackSkipInterval.defaultSeconds

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    Picker("Skip interval", selection: Binding(
                        get: { PlaybackSkipInterval.supportedSeconds(storedSkipInterval) },
                        set: { storedSkipInterval = $0 }
                    )) {
                        ForEach(PlaybackSkipInterval.choices, id: \.self) { seconds in
                            Text("\(seconds) seconds").tag(seconds)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("playbackSkipIntervalPicker")
                }
            }
            .scrollContentBackground(.hidden)
            .background(YarmsTheme.canvas)
            .tint(YarmsTheme.accent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct CompactPlaybackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(YarmsTheme.accent)
            .frame(width: YarmsTheme.minimumTarget, height: YarmsTheme.minimumTarget)
            .background(YarmsTheme.soft, in: RoundedRectangle(cornerRadius: YarmsTheme.Radius.control))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .yarmsPressFeedback(isPressed: configuration.isPressed)
    }
}

private struct TikTokWebPlayer: UIViewRepresentable {
    let html: String
    let controller: TikTokPlayerController

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.add(controller, name: "yarmsPlayerEvents")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.accessibilityIdentifier = "tiktokPlayerViewport"
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        controller.connect(webView)
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        uiView.stopLoading()
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "yarmsPlayerEvents")
    }
}
