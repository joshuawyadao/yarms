import SwiftUI
import UIKit

struct LibraryShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var entries: [PendingLink] = []
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Share a TikTok workout to Yarms or paste its link here.")
                    )
                } else {
                    List(entries) { entry in
                        NavigationLink {
                            EmbeddedPlayerView(link: entry.link)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.link.videoID.map { "TikTok workout \($0)" } ?? "TikTok workout")
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(entry.link.url.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Yarms")
            .toolbar {
                Button("Paste link", systemImage: "doc.on.clipboard") {
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
            }
            .alert("Could not add workout", isPresented: Binding(
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

    private func refresh() {
        guard let inbox = SharedInbox.live() else { return }
        do {
            entries = try inbox.load()
        } catch {
            message = "Yarms could not read its saved links."
        }
    }
}
