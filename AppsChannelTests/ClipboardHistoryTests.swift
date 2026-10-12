import XCTest
@testable import AppsChannel

final class ClipboardHistoryTests: XCTestCase {

    func testClipboardItemTypeInference() {
        // 1. URL detection
        let urlResult = ClipboardItem.detectType(text: "https://github.com/micah1crandell/AppsChannel")
        XCTAssertEqual(urlResult.type, .link)

        let domainResult = ClipboardItem.detectType(text: "apple.com")
        XCTAssertEqual(domainResult.type, .link)

        // 2. Color detection
        let hexResult = ClipboardItem.detectType(text: "#FF5733")
        XCTAssertEqual(hexResult.type, .color)
        XCTAssertEqual(hexResult.colorHex, "#FF5733")

        let rawHexResult = ClipboardItem.detectType(text: "0A84FF")
        XCTAssertEqual(rawHexResult.type, .color)
        XCTAssertEqual(rawHexResult.colorHex, "#0A84FF")

        // 3. Code detection
        let codeSnippet = """
        import SwiftUI
        struct MyView: View {
            var body: some View {
                Text("Hello")
            }
        }
        """
        let codeResult = ClipboardItem.detectType(text: codeSnippet)
        XCTAssertEqual(codeResult.type, .code)

        // 4. Plain text fallback
        let textResult = ClipboardItem.detectType(text: "This is just a regular sentence about things.")
        XCTAssertEqual(textResult.type, .text)
    }

    func testClipboardItemCharacterAndWordCounts() {
        let text = "Hello world\nThis is a test line."
        let item = ClipboardItem(type: .text, textContent: text)

        XCTAssertEqual(item.characterCount, text.count)
        XCTAssertEqual(item.wordCount, 7)
        XCTAssertEqual(item.lineCount, 2)
    }

    func testClipboardItemConcealedMasking() {
        let secretItem = ClipboardItem(
            type: .text,
            textContent: "super-secret-master-password-123!",
            isConcealed: true
        )

        XCTAssertTrue(secretItem.isConcealed)
        XCTAssertEqual(secretItem.textContent, "super-secret-master-password-123!")
    }

    func testStoragePruningRetention() {
        let storage = ClipboardStorageService.shared

        let oldDate = Date().addingTimeInterval(-100_000) // Older than 24 hours (86,400s)
        let freshDate = Date().addingTimeInterval(-1_000)

        let oldUnpinned = ClipboardItem(id: UUID(), type: .text, textContent: "old unpinned", copiedAt: oldDate, isPinned: false)
        let oldPinned = ClipboardItem(id: UUID(), type: .text, textContent: "old pinned", copiedAt: oldDate, isPinned: true)
        let freshUnpinned = ClipboardItem(id: UUID(), type: .text, textContent: "fresh unpinned", copiedAt: freshDate, isPinned: false)

        let items = [freshUnpinned, oldPinned, oldUnpinned]
        let pruned = storage.pruneItems(items, retention: .day, maxItems: 100)

        // Old unpinned should be pruned; old pinned and fresh unpinned must remain
        XCTAssertTrue(pruned.contains(where: { $0.id == oldPinned.id }))
        XCTAssertTrue(pruned.contains(where: { $0.id == freshUnpinned.id }))
        XCTAssertFalse(pruned.contains(where: { $0.id == oldUnpinned.id }))
    }

    func testStoragePruningMaxItems() {
        let storage = ClipboardStorageService.shared

        var items: [ClipboardItem] = []
        for i in 0..<10 {
            let isPinned = (i == 9) // Oldest item is pinned
            let item = ClipboardItem(id: UUID(), type: .text, textContent: "Item \(i)", copiedAt: Date().addingTimeInterval(Double(-i * 10)), isPinned: isPinned)
            items.append(item)
        }

        // Cap at 4 items
        let pruned = storage.pruneItems(items, retention: .unlimited, maxItems: 4)

        XCTAssertEqual(pruned.count, 4)
        // Pinned item (i == 9) must be preserved despite being oldest
        XCTAssertTrue(pruned.contains(where: { $0.textContent == "Item 9" }))
    }

    func testClearAllHistoryPreservingPinned() {
        let storage = ClipboardStorageService.shared

        let item1 = ClipboardItem(id: UUID(), type: .text, textContent: "Normal 1", isPinned: false)
        let item2 = ClipboardItem(id: UUID(), type: .text, textContent: "Pinned 1", isPinned: true)
        let item3 = ClipboardItem(id: UUID(), type: .text, textContent: "Normal 2", isPinned: false)

        let items = [item1, item2, item3]
        let cleared = storage.clearAllHistory(items: items, preservePinned: true)

        XCTAssertEqual(cleared.count, 1)
        XCTAssertEqual(cleared.first?.id, item2.id)

        let clearedAll = storage.clearAllHistory(items: items, preservePinned: false)
        XCTAssertTrue(clearedAll.isEmpty)
    }

    @MainActor
    func testClipboardMonitorServiceTogglePinAndDelete() {
        let monitor = ClipboardMonitorService.shared

        let testItem = ClipboardItem(id: UUID(), type: .text, textContent: "Unit test item", isPinned: false)
        monitor.items.insert(testItem, at: 0)

        // Toggle pin
        monitor.togglePin(testItem)
        XCTAssertTrue(monitor.items.first(where: { $0.id == testItem.id })?.isPinned == true)

        // Delete item
        monitor.deleteItem(testItem)
        XCTAssertFalse(monitor.items.contains(where: { $0.id == testItem.id }))
    }
}
