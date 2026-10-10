import XCTest
import AppKit
@testable import AppsChannel

final class RecentDocumentsServiceTests: XCTestCase {

    func testExtractDocumentTypesFromSystemApp() {
        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        if FileManager.default.fileExists(atPath: textEditURL.path) {
            let (types, exts) = RecentDocumentsService.extractDocumentTypes(forAppAt: textEditURL)
            // TextEdit registers document types or extensions (like txt, rtf)
            XCTAssertTrue(!types.isEmpty || !exts.isEmpty)
        }
    }

    func testRecentDocumentItemProperties() {
        let url = URL(fileURLWithPath: "/Users/test/document.txt")
        let item = RecentDocumentItem(
            id: UUID(),
            name: "document.txt",
            url: url,
            icon: NSImage(),
            lastUsedDate: Date()
        )

        XCTAssertEqual(item.name, "document.txt")
        XCTAssertEqual(item.url, url)
        XCTAssertFalse(item.formattedRelativeDate.isEmpty)
    }

    func testRecentDocumentItemEquality() {
        let url1 = URL(fileURLWithPath: "/Users/test/doc1.txt")
        let url2 = URL(fileURLWithPath: "/Users/test/doc2.txt")

        let item1 = RecentDocumentItem(id: UUID(), name: "doc1.txt", url: url1, icon: NSImage(), lastUsedDate: nil)
        let item1Copy = RecentDocumentItem(id: UUID(), name: "doc1.txt", url: url1, icon: NSImage(), lastUsedDate: nil)
        let item2 = RecentDocumentItem(id: UUID(), name: "doc2.txt", url: url2, icon: NSImage(), lastUsedDate: nil)

        XCTAssertEqual(item1, item1Copy)
        XCTAssertNotEqual(item1, item2)
    }
}
