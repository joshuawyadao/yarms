import SwiftUI
import WebKit

struct EmbeddedPlayerView: View {
    @Environment(\.openURL) private var openURL
    let link: TikTokLink

    var body: some View {
        VStack(spacing: 16) {
            if let playerURL = link.playerURL {
                TikTokWebPlayer(url: playerURL)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .aspectRatio(9 / 16, contentMode: .fit)
            } else {
                ContentUnavailableView("Player unavailable", systemImage: "play.slash",
                                       description: Text("Open this link in TikTok to watch it."))
            }
            Button("Open in TikTok", systemImage: "arrow.up.right.square") {
                openURL(link.url)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TikTokWebPlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
