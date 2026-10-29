import SwiftUI
import AppKit
import Combine

// MARK: - Clipboard History Category Filter Model
private struct ClipboardCategoryFilterItem: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let type: ClipboardContentType?
}

public struct ClipboardHistoryView: View {
    @ObservedObject private var monitor = ClipboardMonitorService.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var discoveryService = AppDiscoveryService.shared
    private let storage = ClipboardStorageService.shared

    @State private var searchText: String = ""
    @State private var selectedCategory: String = "ALL" // "ALL", "PINNED", or ClipboardContentType.rawValue
    @State private var selectedItemId: UUID? = nil
    @State private var revealedConcealedIds: Set<UUID> = []
    @State private var toastMessage: String? = nil
    @State private var eventMonitor: Any? = nil

    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private var currentTheme: AppVisualTheme {
        themeManager.currentTheme
    }

    // MARK: - Category Filters
    private var availableCategoryFilters: [ClipboardCategoryFilterItem] {
        var filters: [ClipboardCategoryFilterItem] = [
            ClipboardCategoryFilterItem(id: "ALL", title: "All", icon: "doc.on.clipboard", type: nil)
        ]

        let pinnedCount = monitor.items.filter { $0.isPinned }.count
        if pinnedCount > 0 {
            filters.append(ClipboardCategoryFilterItem(id: "PINNED", title: "Pinned", icon: "pin.fill", type: nil))
        }

        for type in ClipboardContentType.allCases {
            let count = monitor.items.filter { $0.type == type }.count
            if count > 0 {
                filters.append(ClipboardCategoryFilterItem(id: type.rawValue, title: type.rawValue, icon: type.systemIcon, type: type))
            }
        }

        return filters
    }

    // MARK: - Filtered Items
    private var filteredItems: [ClipboardItem] {
        var list = monitor.items

        // Category Filter
        if selectedCategory == "PINNED" {
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
        if let id = selectedItemId, let item = filteredItems.first(where: { $0.id == id }) {
            return item
        }
        return filteredItems.first
    }

    // MARK: - Body View
    public var body: some View {
        ZStack {
            // Liquid Glass Translucent Window Frame
            VStack(spacing: 0) {
                // Top Search Bar & Category Strip
                headerSection

                Divider()
                    .background(Color.white.opacity(0.08))

                // Split Body: Items List & Preview Inspector
                HStack(spacing: 0) {
                    itemsListSection
                        .frame(width: 330)

                    Divider()
                        .background(Color.white.opacity(0.08))

                    previewInspectorSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()
                    .background(Color.white.opacity(0.08))

                // Bottom Footer Cheatsheet & Status
                footerSection
            }
            .frame(width: 780, height: 510)
            .background(
                ZStack {
                    VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)

                    // Theme-Adaptive Tint & Reflection
                    currentTheme.canvasBackgroundGradient
                        .opacity(0.92)

                    // Top Glass Specular Reflection
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(currentTheme.canvasBorderGradient, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 36, x: 0, y: 18)
            .shadow(color: currentTheme.selectionGlowColor.opacity(0.15), radius: 16, x: 0, y: 4)

            // Floating Toast Overlay
            if let toast = toastMessage {
                toastView(message: toast)
                    .offset(y: 200)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupEventMonitor()
            isSearchFieldFocused = true
            if selectedItemId == nil, let first = filteredItems.first {
                selectedItemId = first.id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isSearchFieldFocused = true
            }
        }
        .onChange(of: isSearchFieldFocused) { _, newValue in
            if !newValue {
                DispatchQueue.main.async {
                    isSearchFieldFocused = true
                }
            }
        }
        .onDisappear {
            removeEventMonitor()
        }
    }

    // MARK: - Header Bar Section
    private var headerSection: some View {
        VStack(spacing: 10) {
            // Main Search Row
            HStack(spacing: 12) {
                // Magnifying Glass Badge
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 28, height: 28)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }

                // Search Text Input
                TextField("Search clipboard history, snippets, colors, links...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(currentTheme.titleTextColor)
                    .focused($isSearchFieldFocused)
                    .onChange(of: searchText) { _, _ in
                        if let first = filteredItems.first {
                            selectedItemId = first.id
                        }
                    }
                    .onSubmit {
                        if let item = selectedItem {
                            pasteItem(item)
                        }
                    }

                // Active Category Filter Tag Pill
                if selectedCategory != "ALL" {
                    HStack(spacing: 5) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 9))
                        Text(selectedCategory == "PINNED" ? "Pinned" : selectedCategory)
                            .font(.system(size: 11, weight: .bold, design: .rounded))

                        Button(action: {
                            selectedCategory = "ALL"
                            SoundEffectsManager.shared.playAction()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15), in: Capsule())
                    .foregroundStyle(.white)
                }

                // Clear Search Query Button
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        SoundEffectsManager.shared.playAction()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }

                // Pause / Recording Status Pill
                Button(action: {
                    monitor.isPaused.toggle()
                    SoundEffectsManager.shared.playAction()
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(monitor.isPaused ? Color.orange : Color(red: 0.2, green: 0.85, blue: 0.45))
                            .frame(width: 6, height: 6)
                            .shadow(color: monitor.isPaused ? Color.orange.opacity(0.6) : Color.green.opacity(0.6), radius: 2)
                        Text(monitor.isPaused ? "Paused" : "Recording")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(monitor.isPaused ? "Clipboard recording is paused. Click to resume." : "Clipboard is actively recording. Click to pause.")

                // Dismiss Button (⎋)
                Button(action: closeAndDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close (⎋)")
            }

            // Category Filter Pills Strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(availableCategoryFilters) { filter in
                        let isSelected = (selectedCategory == filter.id)
                        let count = countForFilter(filter)

                        Button(action: {
                            SoundEffectsManager.shared.playNavigation()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                selectedCategory = filter.id
                                if let first = filteredItems.first {
                                    selectedItemId = first.id
                                }
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: filter.icon)
                                    .font(.system(size: 10, weight: .bold))

                                Text(filter.title)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))

                                Text("\(count)")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1)
                                    .background(
                                        isSelected ? Color.black.opacity(0.18) : Color.white.opacity(0.12),
                                        in: Capsule()
                                    )
                            }
                            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.8))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white : Color.white.opacity(0.08))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func countForFilter(_ filter: ClipboardCategoryFilterItem) -> Int {
        if filter.id == "ALL" {
            return monitor.items.count
        } else if filter.id == "PINNED" {
            return monitor.items.filter { $0.isPinned }.count
        } else if let type = filter.type {
            return monitor.items.filter { $0.type == type }.count
        }
        return 0
    }

    // MARK: - Left Column: Items List Section
    private var itemsListSection: some View {
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.white.opacity(0.25))

                    Text(searchText.isEmpty ? "No clipboard clippings yet" : "No results for \"\(searchText)\"")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.65))

                    Text("Copy text, images, links, or colors to see them here.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredItems) { item in
                                let isSelected = (item.id == (selectedItem?.id ?? UUID()))
                                itemRow(item: item, isSelected: isSelected)
                                    .id(item.id)
                                    .onTapGesture {
                                        selectedItemId = item.id
                                        SoundEffectsManager.shared.playNavigation()
                                        isSearchFieldFocused = true
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
                    .onChange(of: selectedItemId) { _, newId in
                        if let id = newId {
                            withAnimation(.easeInOut(duration: 0.12)) {
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
        let resolvedIcon = appIcon(for: item.sourceAppBundleId)

        return HStack(spacing: 10) {
            // Source App or Type Glyph Icon
            ZStack(alignment: .bottomLeading) {
                if let icon = resolvedIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(item.type.accentColor.opacity(0.2))
                            .frame(width: 24, height: 24)
                        Image(systemName: item.type.systemIcon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(item.type.accentColor)
                    }
                }

                // Type Accent Dot
                Circle()
                    .fill(item.type.accentColor)
                    .frame(width: 5, height: 5)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.6), lineWidth: 1))
                    .offset(x: -2, y: 2)
            }
            .frame(width: 26, height: 26)

            // Content Preview & Metadata
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if item.isConcealed {
                        Image(systemName: isConcealed ? "lock.fill" : "lock.open.fill")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.orange)
                    }

                    if item.type == .color, let hex = item.colorHex {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(NSColor(hex: hex) ?? .white))
                            .frame(width: 10, height: 10)
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
                    }

                    Text(isConcealed ? "••••••••••••••••" : item.previewText)
                        .font(item.type == .code ? .system(size: 12, weight: .regular, design: .monospaced) : .system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.92))
                        .lineLimit(1)
                }

                // Sub-info: Source App + Relative Time + Pin
                HStack(spacing: 5) {
                    if let app = item.sourceAppName {
                        Text(app)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.white.opacity(0.45))
                            .lineLimit(1)

                        Text("•")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }

                    Text(timeAgo(from: item.copiedAt))
                        .font(.system(size: 9.5))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.65) : Color.white.opacity(0.35))

                    if item.isPinned {
                        Spacer()
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.yellow)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                        )
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
    }

    // MARK: - Right Column: Preview & Inspector Section
    private var previewInspectorSection: some View {
        Group {
            if let item = selectedItem {
                let isConcealed = item.isConcealed && !revealedConcealedIds.contains(item.id)
                let resolvedIcon = appIcon(for: item.sourceAppBundleId)

                VStack(alignment: .leading, spacing: 0) {
                    // Top Inspector Toolbar
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text(item.type.rawValue.uppercased())
                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(item.type.accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(item.type.accentColor.opacity(0.16), in: Capsule())
                                .overlay(Capsule().strokeBorder(item.type.accentColor.opacity(0.3), lineWidth: 1))

                            if let icon = resolvedIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                            }

                            if let app = item.sourceAppName {
                                Text(app)
                                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }

                        Spacer()

                        // Action Buttons Deck: Reveal, Pin, Copy, Paste, Delete
                        HStack(spacing: 5) {
                            if item.isConcealed {
                                Button(action: {
                                    if revealedConcealedIds.contains(item.id) {
                                        revealedConcealedIds.remove(item.id)
                                    } else {
                                        revealedConcealedIds.insert(item.id)
                                    }
                                    SoundEffectsManager.shared.playAction()
                                }) {
                                    Image(systemName: isConcealed ? "eye.fill" : "eye.slash.fill")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.orange)
                                        .frame(width: 24, height: 24)
                                        .background(Color.orange.opacity(0.15), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .help(isConcealed ? "Reveal password / secret" : "Mask secret")
                            }

                            Button(action: {
                                monitor.togglePin(item)
                                showToast(item.isPinned ? "Unpinned clipping" : "Pinned clipping")
                            }) {
                                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(item.isPinned ? .yellow : .white.opacity(0.65))
                                    .frame(width: 24, height: 24)
                                    .background(Color.white.opacity(0.08), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Pin item (⌥P)")

                            Button(action: { copyItem(item) }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .frame(width: 24, height: 24)
                                    .background(Color.white.opacity(0.08), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Copy to clipboard (⌘C)")

                            Button(action: { pasteItem(item) }) {
                                Image(systemName: "arrow.right.doc.on.clipboard")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Color(red: 0.1, green: 0.85, blue: 0.55))
                                    .frame(width: 24, height: 24)
                                    .background(Color(red: 0.1, green: 0.85, blue: 0.55).opacity(0.16), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Paste to frontmost app (↵)")

                            Button(action: { deleteSelectedItem(item) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.red.opacity(0.85))
                                    .frame(width: 24, height: 24)
                                    .background(Color.red.opacity(0.14), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Delete item (⌫)")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider().background(Color.white.opacity(0.06))

                    // Main Content Viewer Glass Card
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
                        .padding(14)
                    }
                    .background(Color.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .padding(12)

                    Spacer(minLength: 0)

                    Divider().background(Color.white.opacity(0.06))

                    // Detail Inspector Metadata
                    HStack(spacing: 12) {
                        if item.characterCount > 0 {
                            metadataPill(label: "Chars", value: "\(item.characterCount)")
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
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
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
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("This clipping was flagged as concealed by a password manager or secure field. Preview is masked for privacy.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button(action: {
                revealedConcealedIds.insert(item.id)
                SoundEffectsManager.shared.playAction()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "eye.fill")
                    Text("Reveal Secret")
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func imageViewerCard(item: ClipboardItem) -> some View {
        VStack(alignment: .center, spacing: 10) {
            if let filename = item.imageFilename, let image = storage.loadImage(filename: filename) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 8)

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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: nsColor))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color(nsColor: nsColor).opacity(0.3), radius: 8)

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
                    SoundEffectsManager.shared.playAction()
                }) {
                    Text("Copy Hex")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)

                let rgbString = "rgb(\(Int(nsColor.redComponent * 255)), \(Int(nsColor.greenComponent * 255)), \(Int(nsColor.blueComponent * 255)))"
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(rgbString, forType: .string)
                    showToast("Copied RGB")
                    SoundEffectsManager.shared.playAction()
                }) {
                    Text("Copy RGB")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
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
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if let url = validURL {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                        SoundEffectsManager.shared.playAction()
                    }) {
                        HStack(spacing: 4) {
                            Text("Open in Browser")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 1.0))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(Color(red: 0.15, green: 0.55, blue: 1.0).opacity(0.15), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color(red: 0.15, green: 0.55, blue: 1.0).opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(urlString)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
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
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        HStack {
            // Count & Disk usage
            HStack(spacing: 6) {
                Text("\(filteredItems.count) clippings")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

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

            // Primary Paste Action Button Pill
            Button(action: {
                if let item = selectedItem {
                    pasteItem(item)
                }
            }) {
                HStack(spacing: 5) {
                    Text("Paste")
                        .font(.system(size: 11, weight: .bold, design: .rounded))

                    Text("↵")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Cheatsheet Badges
            HStack(spacing: 10) {
                cheatsheetItem(key: "⌘C", label: "Copy")
                cheatsheetItem(key: "⌥P", label: "Pin")
                cheatsheetItem(key: "⌘⌫", label: "Delete")
                cheatsheetItem(key: "⎋", label: "Close")
            }

            Spacer()

            // Clear Unpinned Button
            if !monitor.items.isEmpty {
                Button(action: {
                    monitor.clearAllHistory(preservePinned: true)
                    showToast("Cleared unpinned history")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text("Clear Unpinned")
                    }
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.orange.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.25))
    }

    private func cheatsheetItem(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Direct Key Handling Event Monitor
    private func setupEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard PanelController.shared.isClipboardVisible else { return event }
            if let eventWindow = event.window, let clipboardWindow = PanelController.shared.clipboardPanel, eventWindow != clipboardWindow {
                return event
            }

            let isCmd = event.modifierFlags.contains(.command)
            let isOpt = event.modifierFlags.contains(.option)

            switch event.keyCode {
            case 53: // Escape
                if !searchText.isEmpty {
                    searchText = ""
                    SoundEffectsManager.shared.playAction()
                    return nil
                }
                if selectedCategory != "ALL" {
                    selectedCategory = "ALL"
                    SoundEffectsManager.shared.playAction()
                    return nil
                }
                closeAndDismiss()
                return nil

            case 126: // Arrow Up
                selectPreviousItem()
                SoundEffectsManager.shared.playNavigation()
                return nil

            case 125: // Arrow Down
                selectNextItem()
                SoundEffectsManager.shared.playNavigation()
                return nil

            case 36, 76: // Return
                if let item = selectedItem {
                    if isCmd {
                        copyItem(item)
                    } else {
                        pasteItem(item)
                    }
                }
                return nil

            default:
                // Command + C: Copy selected item
                if isCmd && (event.keyCode == 8 || event.charactersIgnoringModifiers?.lowercased() == "c") {
                    if let item = selectedItem {
                        copyItem(item)
                        return nil
                    }
                }

                // Option + P: Toggle Pin
                if isOpt && (event.keyCode == 35 || event.charactersIgnoringModifiers?.lowercased() == "p") {
                    if let item = selectedItem {
                        monitor.togglePin(item)
                        showToast(item.isPinned ? "Pinned clipping" : "Unpinned clipping")
                        return nil
                    }
                }

                // Command + Delete / Backspace (or Delete when not focused): Delete selected item
                if (event.keyCode == 51 || event.keyCode == 117) && (isCmd || !isSearchFieldFocused) {
                    if let item = selectedItem {
                        deleteSelectedItem(item)
                        return nil
                    }
                }

                // Command + 1..8: Category quick jump
                if isCmd, let chars = event.charactersIgnoringModifiers, let num = Int(chars), num >= 1, num <= availableCategoryFilters.count {
                    let target = availableCategoryFilters[num - 1]
                    SoundEffectsManager.shared.playNavigation()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedCategory = target.id
                        if let first = filteredItems.first {
                            selectedItemId = first.id
                        }
                    }
                    return nil
                }

                // Fallback character routing to search field
                if let characters = event.characters,
                   !characters.isEmpty,
                   characters != "\r" && characters != "\n",
                   !isCmd && !event.modifierFlags.contains(.control) && !isOpt {
                    let allowed = CharacterSet.alphanumerics.union(.punctuationCharacters).union(.whitespaces)
                    if characters.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
                        if !isSearchFieldFocused {
                            isSearchFieldFocused = true
                            searchText.append(characters)
                            SoundEffectsManager.shared.playNavigation()
                            return nil
                        }
                    }
                }

                return event
            }
        }
    }

    private func removeEventMonitor() {
        if let mon = eventMonitor {
            NSEvent.removeMonitor(mon)
            eventMonitor = nil
        }
    }

    // MARK: - Actions & Helpers
    private func selectNextItem() {
        guard !filteredItems.isEmpty else { return }
        if let current = selectedItemId, let idx = filteredItems.firstIndex(where: { $0.id == current }) {
            let nextIdx = min(filteredItems.count - 1, idx + 1)
            selectedItemId = filteredItems[nextIdx].id
        } else {
            selectedItemId = filteredItems.first?.id
        }
        isSearchFieldFocused = true
    }

    private func selectPreviousItem() {
        guard !filteredItems.isEmpty else { return }
        if let current = selectedItemId, let idx = filteredItems.firstIndex(where: { $0.id == current }) {
            let prevIdx = max(0, idx - 1)
            selectedItemId = filteredItems[prevIdx].id
        } else {
            selectedItemId = filteredItems.first?.id
        }
        isSearchFieldFocused = true
    }

    private func closeAndDismiss() {
        removeEventMonitor()
        onClose()
    }

    private func pasteItem(_ item: ClipboardItem) {
        SoundEffectsManager.shared.playLaunch()
        closeAndDismiss()
        monitor.pasteToFrontmostApp(item)
    }

    private func copyItem(_ item: ClipboardItem) {
        SoundEffectsManager.shared.playAction()
        monitor.copyToPasteboard(item)
        showToast("Copied to clipboard")
    }

    private func deleteSelectedItem(_ item: ClipboardItem) {
        SoundEffectsManager.shared.playAction()
        selectNextItem()
        monitor.deleteItem(item)
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                if self.toastMessage == message {
                    self.toastMessage = nil
                }
            }
        }
    }

    private func toastView(message: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.green)
            Text(message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(white: 0.08).opacity(0.94), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }

    private func appIcon(for bundleId: String?) -> NSImage? {
        guard let bundleId = bundleId, !bundleId.isEmpty else { return nil }
        if let app = discoveryService.apps.first(where: { $0.bundleIdentifier == bundleId }) {
            return app.icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
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
