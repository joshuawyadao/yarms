import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = view.tintColor
        spinner.startAnimating()
        spinner.isAccessibilityElement = false

        let label = UILabel()
        label.text = "Saving to yarms…"
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.numberOfLines = 0

        let content = UIStackView(arrangedSubviews: [spinner, label])
        content.axis = .vertical
        content.alignment = .center
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
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
                let inbox = KeychainInbox.live()
                do {
                    try inbox.save(link)
                    extensionContext?.completeRequest(returningItems: nil)
                } catch {
                    finish(error: "yarms could not save the link.")
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
