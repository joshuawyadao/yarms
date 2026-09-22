import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Saving to Yarms…"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        Task { @MainActor in
            await captureLink()
        }
    }

    @MainActor
    private func captureLink() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        for provider in providers {
            for type in [UTType.url.identifier, UTType.plainText.identifier] {
                guard provider.hasItemConformingToTypeIdentifier(type) else { continue }
                guard let text = await loadText(from: provider, type: type),
                      let link = TikTokLink(text: text) else { continue }
                guard let inbox = SharedInbox.live() else {
                    finish(error: "Yarms storage is unavailable.")
                    return
                }
                do {
                    try inbox.save(link)
                    extensionContext?.completeRequest(returningItems: nil)
                } catch {
                    finish(error: "Yarms could not save the link.")
                }
                return
            }
        }
        finish(error: "Share a TikTok video link to save it.")
    }

    private func loadText(from provider: NSItemProvider, type: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url.absoluteString)
                } else if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func finish(error: String) {
        let alert = UIAlertController(title: "Could not save workout", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "YarmsShare", code: 1,
                                                                     userInfo: [NSLocalizedDescriptionKey: error]))
        })
        present(alert, animated: true)
    }
}
