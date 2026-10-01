import SwiftUI
import WebKit

struct EmbeddedPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
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
    @FocusState private var notesFocused: Bool

    let workout: Workout
    let folders: [WorkoutFolder]
    let onNotesSaved: () -> Void
    let onFolderChanged: (UUID?) -> Bool
    let onDeleteWorkout: () -> Bool

    init(workout: Workout, folders: [WorkoutFolder], onNotesSaved: @escaping () -> Void,
         onFolderChanged: @escaping (UUID?) -> Bool, onDeleteWorkout: @escaping () -> Bool) {
        self.workout = workout
        self.folders = folders
        self.onNotesSaved = onNotesSaved
        self.onFolderChanged = onFolderChanged
        self.onDeleteWorkout = onDeleteWorkout
        _notesOpen = State(initialValue: workout.notes != nil)
        _noteText = State(initialValue: workout.notes ?? "")
        _selectedFolderID = State(initialValue: workout.folderID)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: YarmsTheme.Spacing.xl) {
                    workoutHeading

                    if let playerURL = workout.playbackLink.playerURL,
                       let html = TikTokPlayerHTML.document(for: playerURL) {
                        let playerWidth = max(0, min(geometry.size.width, YarmsTheme.maximumContentWidth) - 2 * YarmsTheme.Spacing.lg)
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

                    Button {
                        notesFocused = false
                        player.send(.pause)
                        showingWorkoutCompletion = true
                    } label: {
                        Label("Finish workout", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(YarmsSecondaryButtonStyle())
                    .accessibilityIdentifier("finishWorkoutButton")

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
        .sheet(isPresented: $showingWorkoutCompletion) {
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
                if onDeleteWorkout() {
                    dismiss()
                } else {
                    messageTitle = "Could not delete workout"
                    message = "The saved workout could not be removed. Return to the library, select it again, and retry."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The saved link and its notes will be removed from this iPhone. The TikTok post will not be affected.")
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
        YarmsSaveConfirmation(message: noteSaved ? "Saved on this iPhone" : nil,
                              eventID: noteSaveEventID, placeholder: "Saved on this iPhone")
            .accessibilityIdentifier("noteSaveConfirmation")
    }

    private var workoutHeading: some View {
        VStack(alignment: .leading, spacing: YarmsTheme.Spacing.sm) {
            Text(workout.title ?? "TikTok workout")
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
        if onFolderChanged(id) { selectedFolderID = id }
    }

    private var playbackControls: some View {
        VStack(spacing: YarmsTheme.Spacing.sm) {
            HStack(spacing: YarmsTheme.Spacing.md) {
                Button { player.seek(by: -10) } label: {
                    Image(systemName: "gobackward.10")
                }
                .accessibilityLabel("Back 10 seconds")

                Button {
                    player.send(player.isPlaying ? .pause : .play)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button { player.seek(by: 10) } label: {
                    Image(systemName: "goforward.10")
                }
                .accessibilityLabel("Forward 10 seconds")

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

    private func saveNotes() {
        let wasSaved = noteSaved
        noteSaved = false
        messageTitle = "Could not save notes"
        guard let store = WorkoutStore.live() else {
            message = "yarms could not access its saved workouts."
            return
        }
        do {
            if try store.updateNotes(noteText, for: workout.id) {
                noteSaved = true
                if !wasSaved { noteSaveEventID += 1 }
                onNotesSaved()
            } else {
                message = "This workout changed while you were editing. Reopen it and try again."
            }
        } catch {
            message = "Your notes could not be saved. Try again."
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
