import XCTest
@testable import Yarms

final class KeychainInboxTests: XCTestCase {
    func testSignedDeviceCanSaveLoadAndRemoveSharedLink() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("The CI simulator build is unsigned; run this Keychain entitlement test on a signed iPhone.")
        #else
        let inbox = KeychainInbox(service: "com.joshuawyadao.yarms.tests.\(UUID().uuidString)")
        let link = try XCTUnwrap(TikTokLink(text: "https://www.tiktok.com/@coach/video/123"))
        let saved = try inbox.save(link)
        defer { try? inbox.remove(saved.id) }

        XCTAssertEqual(try inbox.load().map(\.id), [saved.id])
        try inbox.remove(saved.id)
        XCTAssertTrue(try inbox.load().isEmpty)
        #endif
    }
}
