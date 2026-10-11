import SwiftUI
import AppKit

public struct ClipboardHistoryView: View {
    @ObservedObject private var monitor = ClipboardMonitorService.shared
    private let storage = ClipboardStorageService.shared

    @State private var searchText: String = ""
    @State private var selectedCategory: String = "ALL" // "ALL", "Pinned", or ClipboardContentType.rawValue
    @State private var selectedItemId: UUID? = nil
    @State private var revealedConcealedIds: Set<UUID> = []
    @State private var showCopiedToast: Bool = false
    @State private var toastText: String = ""

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    // Filtered Items
    private var filteredItems: [ClipboardItem] {
        var list = monitor.items

        // Category Filter
        if selectedCategory == "Pinned" {
            list = list.filter { $0.isPinned }
        } else if selectedCategory != "ALL", let type = ClipboardContentType(rawValue: selectedCategory) {
            list = list.filter { $0.type == type }
        }

        // Search Filter
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter { item in
                (item.textContent?.localizedCaseInsensitiveContains(query) ?? false) ||
                item.previewText.localizedCaseInsensitiveContains(query) ||
                (item.sourceAppName?.localizedCaseInsensitiveContains(query) ?? false) ||
                (item.colorHex?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }

        return list
    }

    private var selectedItem: ClipboardItem? {
        if let id = selectedItemId, let item = monitor.items.first(where: { $0.id == id }) {
            return item
        }
        return filteredItems.first
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header: Search & Filter Pills
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .background(Color.white.opacity(0.08))

            // MARK: - Split Body: Items List & Inspector
            HStack(spacing: 0) {
                // Left Column: Items List
                itemsListSection
                    .frame(width: 330)

                Divider()
                    .background(Color.white.opacity(0.08))

                // Right Column: Preview & Inspector
                previewInspectorSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
                .background(Color.white.opacity(0.08))

            // MARK: - Footer Cheatsheet & Status
            footerSection
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 800, height: 530)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            if showCopiedToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 50)
            }
        }
        .onAppear {
            if selectedItemId == nil, let first = filteredItems.first {
                selectedItemId = first.id
            }
        }
        .background(
            KeyCatchingBackgroundView(
                onArrowUp: selectPreviousItem,
                onArrowDown: selectNextItem,
                onReturn: {
                    if let item = selectedItem {
                        pasteItem(item)
                    }
                },
                onCommandC: {
                    if let item = selectedItem {
                        copyItem(item)
                    }
                },
                onOptionP: {
                    if let item = selectedItem {
                        monitor.togglePin(item)
                    }
                },
                onDelete: {
                    if let item = selectedItem {
                        deleteSelectedItem(item)
                    }
                },
                onEscape: onClose
            )
        )
    }

    // MARK: - Header Bar
    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Search Input Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))

                    TextField("Search clipboard history, snippets, links...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )

                // Pause / Record Status Pill
                Button(action: {
                    monitor.isPaused.toggle()
                    SoundEffectsManager.shared.playAction()
                }) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(monitor.isPaused ? Color.orange : Color.green)
                            .frame(width: 7, height: 7)
                        Text(monitor.isPaused ? "Paused" : "Recording")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help(monitor.isPaused ? "Clipboard recording is paused. Click to resume." : "Clipboard is actively recording. Click to pause.")

                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(6)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }

            // Category Filter Pills Strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    CategoryPill(
                        title: "All",
                        count: monitor.items.count,
                        isSelected: selectedCategory == "ALL"
                    ) {
                        selectedCategory = "ALL"
                    }

                    let pinnedCount = monitor.items.filter { $0.isPinned }.count
                    if pinnedCount > 0 {
                        CategoryPill(
                            title: "Pinned",
                            count: pinnedCount,
                            isSelected: selectedCategory == "Pinned"
                        ) {
                            selectedCategory = "Pinned"
                        }
                    }

                    ForEach(ClipboardContentType.allCases) { type in
                        let count = monitor.items.filter { $0.type == type }.count
                        if count > 0 {
                            CategoryPill(
                                title: type.rawValue,
                                count: count,
                                isSelected: selectedCategory == type.rawValue
                            ) {
                                selectedCategory = type.rawValue
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Items List Column
    private var itemsListSection: some View {
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.2))
                    Text(searchText.isEmpty ? "No clipboard clippings yet" : "No results matching query")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 3) {
                            ForEach(filteredItems) { item in
                                let isSelected = (item.id == (selectedItem?.id ?? UUID()))
                                itemRow(item: item, isSelected: isSelected)
                                    .id(item.id)
                                    .onTapGesture {
                                        selectedItemId = item.id
                                    }
                                    .simultaneousGesture(
                                        TapGesture(count: 2).onEnded {
                                            pasteItem(item)
                                        }
                                    )
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: selectedItemId) { newId in
                        if let id = newId {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }

    private func itemRow(item: ClipboardItem, isSelected: Bool) -> some View {
        let isConcealed = item.isConcealed && !revealedConcealedIds.contains(item.id)

        return HStack(spacing: 10) {
            // Type Glyph Badge
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(item.type.accentColor.opacity(0.2))
                    .frame(width: 26, height: 26)
                Image(systemName: item.type.systemIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(item.type.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                // Text Preview or Masked
                HStack(spacing: 4) {
                    if item.isConcealed {
                        Image(systemName: isConcealed ? "lock.fill" : "lock.open.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }

                    Text(isConcealed ? "••••••••••••••••" : item.previewText)
                        .font(item.type == .code ? .system(size: 12, weight: .regular, design: .monospaced) : .system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.9))
                        .lineLimit(1)
                }

                // Sub-info: Source App + Relative Time + Pin
                HStack(spacing: 6) {
                    if let app = item.sourceAppName {
                        Text(app)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Text(timeAgo(from: item.copiedAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))

                    if item.isPinned {
                        Spacer()
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Preview & Inspector Column
    private var previewInspectorSection: some View {
        Group {
            if let item = selectedItem {
                let isConcealed = item.isConcealed && !revealedConcealedIds.contains(item.id)

                VStack(alignment: .leading, spacing: 0) {
                    // Top Inspector Toolbar
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text(item.type.rawValue.uppercased())
                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(item.type.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.type.accentColor.opacity(0.15), in: Capsule())

                            if let app = item.sourceAppName {
                                Text(app)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }

                        Spacer()

                        // Action Buttons: Pin, Copy, Paste, Delete, Reveal
                        HStack(spacing: 4) {
                            if item.isConcealed {
                                Button(action: {
                                    if revealedConcealedIds.contains(item.id) {
                                        revealedConcealedIds.remove(item.id)
                                    } else {
                                        revealedConcealedIds.insert(item.id)
                                    }
                                }) {
                                    Image(systemName: isConcealed ? "eye.fill" : "eye.slash.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.orange)
                                        .padding(6)
                                        .background(Color.orange.opacity(0.15), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .help(isConcealed ? "Reveal password / secret" : "Mask secret")
                            }

                            Button(action: { monitor.togglePin(item) }) {
                                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 11))
                                    .foregroundStyle(item.isPinned ? .yellow : .white.opacity(0.6))
                                    .padding(6)
                                    .background(Color.white.opacity(0.06), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Pin item (Option + P)")

                            Button(action: { copyItem(item) }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(6)
                                    .background(Color.white.opacity(0.06), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Copy to clipboard (Command + C)")

                            Button(action: { pasteItem(item) }) {
                                Image(systemName: "arrow.right.doc.on.clipboard")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(red: 0.1, green: 0.75, blue: 0.5))
                                    .padding(6)
                                    .background(Color(red: 0.1, green: 0.75, blue: 0.5).opacity(0.15), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Paste to active app (Return)")

                            Button(action: { deleteSelectedItem(item) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.red.opacity(0.8))
                                    .padding(6)
                                    .background(Color.red.opacity(0.12), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Delete item (Delete)")
                        }
                    }
                    .padding(14)

                    Divider().background(Color.white.opacity(0.06))

                    // Main Content Viewer
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            if isConcealed {
                                concealedSecretCard(item: item)
                            } else {
                                switch item.type {
                                case .image:
                                    imageViewerCard(item: item)
                                case .color:
                                    colorViewerCard(item: item)
                                case .link:
                                    linkViewerCard(item: item)
                                case .code:
                                    codeViewerCard(item: item)
                                default:
                                    textViewerCard(item: item)
                                }
                            }
                        }
                        .padding(16)
                    }

                    Spacer()

                    Divider().background(Color.white.opacity(0.06))

                    // Detail Inspector Metadata
                    HStack(spacing: 12) {
                        if item.characterCount > 0 {
                            metadataPill(label: "Characters", value: "\(item.characterCount)")
                            metadataPill(label: "Words", value: "\(item.wordCount)")
                            metadataPill(label: "Lines", value: "\(item.lineCount)")
                        }

                        Spacer()

                        Text("Copied \(formattedDate(item.copiedAt))")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Select a clipping to preview")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
            }
        }
    }

    // MARK: - Specialized Content Viewer Cards
    private func concealedSecretCard(item: ClipboardItem) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
            }

            Text("Sensitive Secret / Concealed Data")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            Text("This clipping was flagged as concealed by a password manager or secure field. Preview is masked for privacy.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button(action: {
                revealedConcealedIds.insert(item.id)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "eye.fill")
                    Text("Reveal Secret")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func imageViewerCard(item: ClipboardItem) -> some View {
        VStack(alignment: .center, spacing: 10) {
            if let filename = item.imageFilename, let image = storage.loadImage(filename: filename) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 8)

                Text("\(Int(image.size.width)) × \(Int(image.size.height)) pixels")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Text("Image data not available")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func colorViewerCard(item: ClipboardItem) -> some View {
        let hex = item.colorHex ?? item.textContent ?? "#FFFFFF"
        let nsColor = NSColor(hex: hex) ?? .white

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: nsColor))
                    .frame(width: 70, height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(hex)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("RGB: \(Int(nsColor.redComponent * 255)), \(Int(nsColor.greenComponent * 255)), \(Int(nsColor.blueComponent * 255))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            HStack(spacing: 8) {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hex, forType: .string)
                    showToast("Copied \(hex)")
                }) {
                    Text("Copy Hex")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                let rgbString = "rgb(\(Int(nsColor.redComponent * 255)), \(Int(nsColor.greenComponent * 255)), \(Int(nsColor.blueComponent * 255)))"
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(rgbString, forType: .string)
                    showToast("Copied RGB")
                }) {
                    Text("Copy RGB")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func linkViewerCard(item: ClipboardItem) -> some View {
        let urlString = item.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let validURL = URL(string: urlString)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 1.0))

                Text(validURL?.host ?? "Web Link")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                if let url = validURL {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        HStack(spacing: 4) {
                            Text("Open Link")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 1.0))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.15, green: 0.55, blue: 1.0).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(urlString)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .textSelection(.enabled)
        }
    }

    private func codeViewerCard(item: ClipboardItem) -> some View {
        Text(item.textContent ?? "")
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.white.opacity(0.95))
            .lineSpacing(3)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func textViewerCard(item: ClipboardItem) -> some View {
        Text(item.textContent ?? "")
            .font(.system(size: 12.5))
            .foregroundStyle(.white.opacity(0.95))
            .lineSpacing(3)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metadataPill(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        HStack {
            // Count & Disk usage
            HStack(spacing: 6) {
                Text("\(filteredItems.count) clippings")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))

                let diskBytes = storage.calculateDiskUsage()
                if diskBytes > 0 {
                    Text("•")
                        .foregroundStyle(.white.opacity(0.2))
                    Text(formatBytes(diskBytes))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer()

            // Cheatsheet
            HStack(spacing: 12) {
                cheatsheetItem(key: "⏎", label: "Paste")
                cheatsheetItem(key: "⌘C", label: "Copy")
                cheatsheetItem(key: "⌥P", label: "Pin")
                cheatsheetItem(key: "⌫", label: "Delete")
                cheatsheetItem(key: "Esc", label: "Close")
            }

            Spacer()

            // Clear button
            if !monitor.items.isEmpty {
                Button(action: {
                    monitor.clearAllHistory(preservePinned: true)
                }) {
                    Text("Clear Unpinned")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cheatsheetItem(key: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Helpers & Actions
    private func selectNextItem() {
        guard !filteredItems.isEmpty else { return }
        if let current = selectedItemId, let idx = filteredItems.firstIndex(where: { $0.id == current }) {
            let nextIdx = min(filteredItems.count - 1, idx + 1)
            selectedItemId = filteredItems[nextIdx].id
        } else {
            selectedItemId = filteredItems.first?.id
        }
    }

    private func selectPreviousItem() {
        guard !filteredItems.isEmpty else { return }
        if let current = selectedItemId, let idx = filteredItems.firstIndex(where: { $0.id == current }) {
            let prevIdx = max(0, idx - 1)
            selectedItemId = filteredItems[prevIdx].id
        } else {
            selectedItemId = filteredItems.first?.id
        }
    }

    private func pasteItem(_ item: ClipboardItem) {
        onClose()
        monitor.pasteToFrontmostApp(item)
    }

    private func copyItem(_ item: ClipboardItem) {
        monitor.copyToPasteboard(item)
        showToast("Copied to clipboard")
    }

    private func deleteSelectedItem(_ item: ClipboardItem) {
        selectNextItem()
        monitor.deleteItem(item)
    }

    private func showToast(_ message: String) {
        toastText = message
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedToast = false
            }
        }
    }

    private var toastView: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(toastText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.9), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(radius: 8)
    }

    private func timeAgo(from date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        return "\(diff / 86400)d ago"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Key Catching Background View
private struct KeyCatchingBackgroundView: NSViewRepresentable {
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void
    let onReturn: () -> Void
    let onCommandC: () -> Void
    let onOptionP: () -> Void
    let onDelete: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyCatchingNSView {
        let view = KeyCatchingNSView()
        view.onArrowUp = onArrowUp
        view.onArrowDown = onArrowDown
        view.onReturn = onReturn
        view.onCommandC = onCommandC
        view.onOptionP = onOptionP
        view.onDelete = onDelete
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyCatchingNSView, context: Context) {
        nsView.onArrowUp = onArrowUp
        nsView.onArrowDown = onArrowDown
        nsView.onReturn = onReturn
        nsView.onCommandC = onCommandC
        nsView.onOptionP = onOptionP
        nsView.onDelete = onDelete
        nsView.onEscape = onEscape
    }
}

private final class KeyCatchingNSView: NSView {
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var onReturn: (() -> Void)?
    var onCommandC: (() -> Void)?
    var onOptionP: (() -> Void)?
    var onDelete: (() -> Void)?
    var onEscape: (() -> Void)?

    private var localMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        stopMonitoring()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            if event.keyCode == 53 { // Esc
                self.onEscape?()
                return nil
            } else if event.keyCode == 126 { // Arrow Up
                self.onArrowUp?()
                return nil
            } else if event.keyCode == 125 { // Arrow Down
                self.onArrowDown?()
                return nil
            } else if event.keyCode == 36 { // Return
                self.onReturn?()
                return nil
            } else if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" {
                self.onCommandC?()
                return nil
            } else if event.modifierFlags.contains(.option) && event.charactersIgnoringModifiers == "p" {
                self.onOptionP?()
                return nil
            } else if event.keyCode == 51 { // Delete
                self.onDelete?()
                return nil
            }

            return event
        }
    }

    private func stopMonitoring() {
        if let mon = localMonitor {
            NSEvent.removeMonitor(mon)
            localMonitor = nil
        }
    }

    deinit {
        stopMonitoring()
    }
}

// MARK: - Hex Color Helper
private extension NSColor {
    convenience init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        guard cleanHex.count == 6 || cleanHex.count == 8 else { return nil }

        var rgbValue: UInt64 = 0
        guard Scanner(string: cleanHex).scanHexInt64(&rgbValue) else { return nil }

        if cleanHex.count == 6 {
            let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgbValue & 0x0000FF) / 255.0
            self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
        } else {
            let r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(rgbValue & 0x000000FF) / 255.0
            self.init(srgbRed: r, green: g, blue: b, alpha: a)
        }
    }
}
