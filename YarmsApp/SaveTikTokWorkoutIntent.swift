import AppIntents
import Foundation

enum WorkoutCaptureError: LocalizedError, Equatable {
    case invalidLink
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "No TikTok video link was found. Share a TikTok video and try again."
        case .storageUnavailable:
            return "Yarms could not access its saved links. Open Yarms and try again."
        }
    }
}

enum WorkoutCapture {
    @discardableResult
    static func save(_ sharedText: String, to inbox: SharedInbox) throws -> PendingLink {
        guard let link = TikTokLink(text: sharedText) else {
            throw WorkoutCaptureError.invalidLink
        }
        return try inbox.save(link)
    }

    @discardableResult
    static func save(_ sharedText: String) throws -> PendingLink {
        guard let inbox = SharedInbox.live() else {
            throw WorkoutCaptureError.storageUnavailable
        }
        return try save(sharedText, to: inbox)
    }
}

struct SaveTikTokWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Save TikTok Workout"
    static var description = IntentDescription("Save a shared TikTok video link in Yarms.")

    @Parameter(title: "Shared TikTok Link") var sharedText: String

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$sharedText) to Yarms")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try WorkoutCapture.save(sharedText)
        return .result(dialog: "Saved to Yarms")
    }
}
