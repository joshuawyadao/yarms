import SwiftUI

struct ShortcutsSetupView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Set this up once on each iPhone. Afterward, a TikTok link can be saved from its Share button without copying or typing.")
                }
                Section("In the Shortcuts app") {
                    step(1, "Create a shortcut named Save to Yarms.")
                    step(2, "In the shortcut’s Details, turn on Show in Share Sheet and allow URLs and Text.")
                    step(3, "Add the Yarms action Save TikTok Workout. Set Shared TikTok Link to Shortcut Input.")
                }
                Section("From TikTok") {
                    step(4, "Tap Share, then choose Save to Yarms from the share sheet. You may need to tap More to find it the first time.")
                    Text("The link is saved on this iPhone. Open Yarms later to see it in your library.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("TikTok sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }

    private func step(_ number: Int, _ instruction: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .fontWeight(.semibold)
            Text(instruction)
        }
        .padding(.vertical, 4)
    }
}
