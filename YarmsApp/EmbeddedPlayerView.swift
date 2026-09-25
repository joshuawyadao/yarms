import SwiftUI
import WebKit

struct EmbeddedPlayerView: View {
    private static let maximumContentWidth: CGFloat = 600

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var player = TikTokPlayerController()
    @State private var notesOpen: Bool
    @State private var noteText: String
    @State private var selectedFolderID: UUID?
    @State private var noteSaved = false
    @State private var message: String?
    @State private var messageTitle = "Could not save notes"
    @State private var showingDeleteWorkout = false
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
                VStack(alignment: .leading, spacing: 20) {
                    workoutHeading

                    if let playerURL = workout.playbackLink.playerURL,
                       let html = TikTokPlayerHTML.document(for: playerURL) {
                        let playerWidth = max(0, min(geometry.size.width, Self.maximumContentWidth) - 32)
                        TikTokWebPlayer(html: html, controller: player)
                            .frame(width: playerWidth, height: playerWidth * 16 / 9)
                            .frame(maxWidth: .infinity)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(Color.white.opacity(0.12))
                            }

                        if player.hasError {
                            Label("This post could not play here. Try TikTok.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if !player.isReady {
                            Text("Player controls activate when TikTok is ready.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                    } else {
                        ContentUnavailableView(
                            "Player unavailable",
                            systemImage: "play.slash",
                            description: Text("Open this workout in TikTok to watch it.")
                        )
                        .frame(maxWidth: .infinity)
                    }

                    DisclosureGroup(isExpanded: $notesOpen) {
                        TextEditor(text: $noteText)
                            .frame(minHeight: 110)
                            .accessibilityLabel("Workout notes")
                            .focused($notesFocused)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color("YarmsCanvas"), in: RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color("YarmsSoft"), lineWidth: 1)
                            }
                            .onChange(of: noteText) { _, _ in noteSaved = false }
                        HStack {
                            Button("Save notes", action: saveNotes)
                                .buttonStyle(.bordered)
                            if noteSaved {
                                Text("Saved on this iPhone")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } label: {
                        Label("Notes (optional)", systemImage: "square.and.pencil")
                            .font(.headline.weight(.semibold))
                    }
                    .tint(Color.accentColor)
                    .padding(16)
                    .background(Color("YarmsSurface"), in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 24)
                .frame(maxWidth: Self.maximumContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color("YarmsCanvas"))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if workout.playbackLink.playerURL != nil {
                    playbackControls
                }
                Button {
                    openURL(workout.playbackLink.url)
                } label: {
                    Label("Open in TikTok", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("YarmsAction"))
                .accessibilityIdentifier("openInTikTokButton")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: Self.maximumContentWidth)
            .frame(maxWidth: .infinity)
            .background(Color("YarmsSurface"))
            .overlay(alignment: .top) { Rectangle().fill(Color("YarmsSoft")).frame(height: 1) }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
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
                    message = "The saved workout could not be removed. Try again."
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

    private var workoutHeading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WORKOUT")
                .font(.caption.weight(.bold))
                .tracking(1.7)
                .foregroundStyle(Color.accentColor)

            Text(workout.title ?? "TikTok workout")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let creator = workout.creator {
                    Text(creator)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Label(selectedFolderName, systemImage: "folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color("YarmsSoft"), in: Capsule())
                    .accessibilityLabel("Folder: \(selectedFolderName)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedFolderName: String {
        folders.first(where: { $0.id == selectedFolderID })?.name ?? "Unfiled"
    }

    private func selectFolder(_ id: UUID?) {
        if onFolderChanged(id) { selectedFolderID = id }
    }

    private var playbackControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
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
        messageTitle = "Could not save notes"
        guard let store = WorkoutStore.live() else {
            message = "Yarms could not access its saved workouts."
            return
        }
        do {
            if try store.updateNotes(noteText, for: workout.id) {
                noteSaved = true
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
            .foregroundStyle(Color.accentColor)
            .frame(width: 44, height: 44)
            .background(Color("YarmsSoft"), in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
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
