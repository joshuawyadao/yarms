import SwiftUI

@main
struct YarmsApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if SharedInbox.isUITestStoreRequested,
               ProcessInfo.processInfo.arguments.contains("-YarmsUITestReduceMotion") {
                LibraryShellView().environment(\.yarmsReduceMotion, true)
            } else {
                LibraryShellView()
            }
            #else
            LibraryShellView()
            #endif
        }
    }
}
