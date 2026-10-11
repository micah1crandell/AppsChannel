import Foundation
import AppKit
import SwiftUI

// MARK: - Clipboard Content Type
public enum ClipboardContentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case text = "Text"
    case link = "Link"
    case code = "Code"
    case color = "Color"
    case image = "Image"
    case file = "File"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette.fill"
        case .image: return "photo.fill"
        case .file: return "doc.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .text: return Color(white: 0.7)
        case .link: return Color(red: 0.15, green: 0.55, blue: 1.0)
        case .code: return Color(red: 0.65, green: 0.35, blue: 1.0)
        case .color: return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .image: return Color(red: 1.0, green: 0.35, blue: 0.65)
        case .file: return Color(red: 0.2, green: 0.8, blue: 0.5)
        }
    }
}

// MARK: - Clipboard Retention Duration
public enum ClipboardRetentionDuration: String, Codable, CaseIterable, Identifiable, Sendable {
    case day = "24 Hours"
    case week = "7 Days"
    case month = "30 Days"
    case unlimited = "Unlimited"

    public var id: String { rawValue }

    public var timeInterval: TimeInterval? {
        switch self {
        case .day: return 86400
        case .week: return 86400 * 7
        case .month: return 86400 * 30
        case .unlimited: return nil
        }
    }
}

// MARK: - Clipboard Item Model
public struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var type: ClipboardContentType
    public var textContent: String?
    public var previewText: String
    public var colorHex: String?
    public var imageFilename: String?
    public var filePaths: [String]?
    public var copiedAt: Date
    public var sourceAppName: String?
    public var sourceAppBundleId: String?
    public var isPinned: Bool
    public var isConcealed: Bool
    public var characterCount: Int
    public var wordCount: Int
    public var lineCount: Int

    public init(
        id: UUID = UUID(),
        type: ClipboardContentType,
        textContent: String? = nil,
        previewText: String? = nil,
        colorHex: String? = nil,
        imageFilename: String? = nil,
        filePaths: [String]? = nil,
        copiedAt: Date = Date(),
        sourceAppName: String? = nil,
        sourceAppBundleId: String? = nil,
        isPinned: Bool = false,
        isConcealed: Bool = false
    ) {
        self.id = id
        self.type = type
        self.textContent = textContent
        self.colorHex = colorHex
        self.imageFilename = imageFilename
        self.filePaths = filePaths
        self.copiedAt = copiedAt
        self.sourceAppName = sourceAppName
        self.sourceAppBundleId = sourceAppBundleId
        self.isPinned = isPinned
        self.isConcealed = isConcealed

        let text = textContent ?? ""
        self.characterCount = text.count
        self.wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
        self.lineCount = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count

        if let preview = previewText {
            self.previewText = preview
        } else {
            switch type {
            case .text, .code, .link:
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let firstLines = trimmed.components(separatedBy: .newlines).prefix(3).joined(separator: " ")
                self.previewText = String(firstLines.prefix(160))
            case .color:
                self.previewText = colorHex ?? text
            case .image:
                self.previewText = "Image Clipping"
            case .file:
                if let files = filePaths, !files.isEmpty {
                    let filenames = files.map { URL(fileURLWithPath: $0).lastPathComponent }
                    self.previewText = filenames.joined(separator: ", ")
                } else {
                    self.previewText = "File reference"
                }
            }
        }
    }

    public var formattedRelativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: copiedAt, relativeTo: Date())
    }

    // MARK: - Classification Helpers
    public static func detectType(text: String) -> (type: ClipboardContentType, colorHex: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Color detection (Hex, RGB, HSL)
        if let hex = extractHexColor(from: trimmed) {
            return (.color, hex)
        }

        // 2. URL detection
        if isLikelyURL(trimmed) {
            return (.link, nil)
        }

        // 3. Code detection
        if isLikelyCode(text) {
            return (.code, nil)
        }

        // 4. Default to plain text
        return (.text, nil)
    }

    private static func extractHexColor(from string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        // Match #RGB, #RGBA, #RRGGBB, #RRGGBBAA or pure 6-char hex
        let hexPattern = #"^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"#
        if trimmed.range(of: hexPattern, options: .regularExpression) != nil {
            let clean = trimmed.hasPrefix("#") ? trimmed : "#" + trimmed
            return clean.uppercased()
        }
        return nil
    }

    private static func isLikelyURL(_ string: String) -> Bool {
        if string.hasPrefix("http://") || string.hasPrefix("https://") || string.hasPrefix("ftp://") {
            return URL(string: string) != nil
        }
        // Match standard domain.tld without whitespace
        if !string.contains(" ") && string.contains(".") && string.count <= 256 {
            let domainPattern = #"^[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}(/.*)?$"#
            return string.range(of: domainPattern, options: .regularExpression) != nil
        }
        return false
    }

    private static func isLikelyCode(_ text: String) -> Bool {
        // High confidence code indicators:
        // Programming constructs: func, def, class, import, return, const, let, var, if, else, struct, public, private
        let codeKeywords = [
            "func ", "def ", "class ", "import ", "return ", "const ", "let ", "var ",
            "struct ", "interface ", "function ", "public ", "private ", "export ",
            "package ", "namespace ", "#include", "<!DOCTYPE", "<html>", "SELECT ",
            "console.log", "print(", "printf", "=>", "->", "/*", "*/", "///",
            "{\n", "}\n", "();", ");"
        ]

        var matchCount = 0
        for keyword in codeKeywords {
            if text.contains(keyword) {
                matchCount += 1
                if matchCount >= 2 { return true }
            }
        }

        // Check for indentation patterns (multiple lines starting with 2+ spaces or tabs with braces)
        let lines = text.components(separatedBy: .newlines)
        if lines.count >= 3 {
            var indentedLines = 0
            for line in lines {
                if line.hasPrefix("  ") || line.hasPrefix("\t") {
                    indentedLines += 1
                }
            }
            if indentedLines >= 2 && (text.contains("{") || text.contains("}") || text.contains("(") || text.contains("=")) {
                return true
            }
        }

        return false
    }
}
