import SwiftUI
import WebKit

struct EmbeddedPlayerView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var player = TikTokPlayerController()
    @State private var notesOpen: Bool
    @State private var noteText: String
    @State private var noteSaved = false
    @State private var message: String?

    let workout: Workout

    init(workout: Workout) {
        self.workout = workout
        _notesOpen = State(initialValue: workout.notes != nil)
        _noteText = State(initialValue: workout.notes ?? "")
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let playerURL = workout.playbackLink.playerURL,
                       let html = TikTokPlayerHTML.document(for: playerURL) {
                        let playerHeight = min((geometry.size.width - 32) * 16 / 9,
                                               geometry.size.height * 0.62)
                        TikTokWebPlayer(html: html, controller: player)
                            .frame(width: playerHeight * 9 / 16, height: playerHeight)
                            .frame(maxWidth: .infinity)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        if player.hasError {
                            Label("This post could not play here. Try TikTok.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if !player.isReady {
                            Text("Player controls activate when TikTok is ready.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        playbackControls
                    } else {
                        ContentUnavailableView(
                            "Player unavailable",
                            systemImage: "play.slash",
                            description: Text("Open this workout in TikTok to watch it.")
                        )
                        .frame(maxWidth: .infinity)
                    }

                    Button("Open in TikTok", systemImage: "arrow.up.right.square") {
                        openURL(workout.playbackLink.url)
                    }
                    .buttonStyle(.borderedProminent)

                    DisclosureGroup(isExpanded: $notesOpen) {
                        TextEditor(text: $noteText)
                            .frame(minHeight: 110)
                            .accessibilityLabel("Workout notes")
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.quaternary)
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
                        Text("Notes (optional)")
                            .font(.headline)
                    }
                }
                .padding()
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(workout.title ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Could not save notes", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var playbackControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 28) {
                Button { player.seek(by: -10) } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                }
                .accessibilityLabel("Back 10 seconds")

                Button {
                    player.send(player.isPlaying ? .pause : .play)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button { player.seek(by: 10) } label: {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                }
                .accessibilityLabel("Forward 10 seconds")

                Button { player.send(.seekTo(0)) } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                }
                .accessibilityLabel("Replay from start")
            }
            .buttonStyle(.bordered)
            .disabled(!player.isReady || player.hasError)
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
        guard let store = WorkoutStore.live() else {
            message = "Yarms could not access its saved workouts."
            return
        }
        do {
            if try store.updateNotes(noteText, for: workout.id) {
                noteSaved = true
            } else {
                message = "This workout changed while you were editing. Reopen it and try again."
            }
        } catch {
            message = "Your notes could not be saved. Try again."
        }
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
