import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private let policy = Bundle.main.url(forResource: "PRIVACY", withExtension: "md")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: YarmsTheme.Spacing.lg) {
                    if let policy {
                        Text(LocalizedStringKey(policy))
                            .textSelection(.enabled)
                            .accessibilityIdentifier("privacyPolicyText")
                    } else {
                        Text("The included privacy policy could not be opened. Read the online policy below.")
                    }
                    Link("Read the online privacy policy",
                         destination: URL(string: "https://github.com/joshuawyadao/yarms/blob/main/PRIVACY.md")!)
                        .accessibilityIdentifier("onlinePrivacyPolicyLink")
                }
                .padding(YarmsTheme.Spacing.lg)
                .frame(maxWidth: YarmsTheme.maximumContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(YarmsTheme.canvas)
            .navigationTitle("Privacy policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("closePrivacyPolicyButton")
                }
            }
        }
    }
}
