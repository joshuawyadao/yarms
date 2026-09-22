import Combine
import Foundation
import WebKit

enum TikTokPlayerEvent: Equatable {
    case ready(duration: Double?)
    case state(Int)
    case time(current: Double, duration: Double?)
    case error

    static func parse(_ body: Any, fromMainFrame: Bool) -> TikTokPlayerEvent? {
        guard fromMainFrame,
              let envelope = body as? [String: Any],
              envelope["origin"] as? String == "https://www.tiktok.com",
              let message = envelope["message"] as? [String: Any],
              message["x-tiktok-player"] as? Bool == true,
              let type = message["type"] as? String else { return nil }

        switch type {
        case "onPlayerReady":
            let value = message["value"] as? [String: Any]
            return .ready(duration: validSeconds(value?["duration"]))
        case "onStateChange":
            guard let state = message["value"] as? Int, (-1...3).contains(state) else { return nil }
            return .state(state)
        case "onCurrentTime":
            guard let value = message["value"] as? [String: Any],
                  let current = validSeconds(value["currentTime"]) else { return nil }
            return .time(current: current, duration: validSeconds(value["duration"]))
        case "onPlayerError", "onError":
            return .error
        default:
            return nil
        }
    }

    private static func validSeconds(_ value: Any?) -> Double? {
        guard let seconds = (value as? NSNumber)?.doubleValue,
              seconds.isFinite, seconds >= 0 else { return nil }
        return seconds
    }
}

enum TikTokPlayerCommand: Equatable {
    case play
    case pause
    case seekTo(Double)

    var javaScript: String {
        let type: String
        let value: String
        switch self {
        case .play:
            type = "play"
            value = "null"
        case .pause:
            type = "pause"
            value = "null"
        case .seekTo(let seconds):
            type = "seekTo"
            value = String(seconds.isFinite ? max(0, seconds) : 0)
        }
        return "window.yarmsPlayerCommand({type:'\(type)',value:\(value),'x-tiktok-player':true});"
    }
}

enum TikTokPlayerHTML {
    static func document(for playerURL: URL) -> String? {
        let path = playerURL.path.split(separator: "/")
        guard playerURL.scheme == "https",
              playerURL.host == "www.tiktok.com",
              path.count == 3, path[0] == "player", path[1] == "v1",
              !path[2].isEmpty, path[2].allSatisfy(\.isNumber) else { return nil }
        let safePlayerURL = "https://www.tiktok.com/player/v1/\(path[2])?controls=1"

        return """
        <!doctype html>
        <html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>
        html,body { margin:0; width:100%; height:100%; overflow:hidden; background:#000; }
        iframe { display:block; width:100%; height:100%; border:0; }
        </style></head><body>
        <iframe id="player" title="TikTok workout" src="\(safePlayerURL)" allow="autoplay; fullscreen" allowfullscreen></iframe>
        <script>
        window.addEventListener('message', function(event) {
          if (event.origin !== 'https://www.tiktok.com') return;
          const message = event.data;
          if (!message || message['x-tiktok-player'] !== true || typeof message.type !== 'string') return;
          window.webkit.messageHandlers.yarmsPlayerEvents.postMessage({origin:event.origin,message:message});
        });
        window.yarmsPlayerCommand = function(message) {
          const frame = document.getElementById('player');
          if (frame && frame.contentWindow) frame.contentWindow.postMessage(message, 'https://www.tiktok.com');
        };
        </script></body></html>
        """
    }
}

final class TikTokPlayerController: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published private(set) var isReady = false
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var hasError = false

    private weak var webView: WKWebView?

    func connect(_ webView: WKWebView) {
        self.webView = webView
    }

    func send(_ command: TikTokPlayerCommand) {
        guard isReady else { return }
        webView?.evaluateJavaScript(command.javaScript)
    }

    func seek(by seconds: Double) {
        let target = max(0, duration > 0 ? min(currentTime + seconds, duration) : currentTime + seconds)
        send(.seekTo(target))
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let event = TikTokPlayerEvent.parse(message.body,
                                                  fromMainFrame: message.frameInfo.isMainFrame) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch event {
            case .ready(let duration):
                self.isReady = true
                if let duration { self.duration = duration }
            case .state(let state):
                self.isPlaying = state == 1
                if state == 0 { self.currentTime = self.duration }
            case .time(let current, let duration):
                if let duration { self.duration = duration }
                self.currentTime = self.duration > 0 ? min(current, self.duration) : current
            case .error:
                self.hasError = true
                self.isPlaying = false
            }
        }
    }
}
