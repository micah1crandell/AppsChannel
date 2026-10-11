import SwiftUI
import AppKit
import HotKey

struct WindowManagementSettingsView: View {
    @ObservedObject private var service = WindowManagementService.shared
    @State private var searchText: String = ""
    @State private var selectedCategory: WindowActionCategory? = nil

    // Hotkey recording state
    @State private var recordingAction: WindowSnappingAction? = nil
    @State private var localKeyMonitor: Any? = nil

    // Alias editing state
    @State private var editingAliasAction: WindowSnappingAction? = nil
    @State private var editingAliasText: String = ""

    init() {}

    private var filteredActions: [WindowSnappingAction] {
        WindowSnappingAction.allCases.filter { action in
            if let cat = selectedCategory, action.category != cat {
                return false
            }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let titleMatch = action.title.lowercased().contains(query)
                let keywordMatch = action.keywords.contains { $0.contains(query) }
                let aliasMatch = service.config(for: action).alias.lowercased().contains(query)
                return titleMatch || keywordMatch || aliasMatch
            }
            return true
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // MARK: - Section Header (Matching Raycast Screenshots)
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.05, green: 0.52, blue: 1.0))

                    Text("Window Management")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                // Master Toggle Checkbox
                Button(action: {
                    service.isMasterEnabled.toggle()
                }) {
                    RaycastCheckbox(isChecked: service.isMasterEnabled)
                }
                .buttonStyle(.plain)
                .help("Enable or disable all window management actions and hotkeys")
            }
            .padding(.horizontal, 4)

            // MARK: - Accessibility Warning Banner
            if !service.isAccessibilityGranted {
                accessibilityBanner
            }

            // MARK: - Search & Category Filter Pills
            HStack(spacing: 8) {
                // Search Bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))

                    TextField("Search commands or aliases...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )

                // Category Filter Pills ScrollView
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        CategoryPill(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }

                        ForEach(WindowActionCategory.allCases) { cat in
                            CategoryPill(title: cat.rawValue, isSelected: selectedCategory == cat) {
                                selectedCategory = (selectedCategory == cat) ? nil : cat
                            }
                        }
                    }
                }
            }

            // MARK: - Action Rows Table
            VStack(spacing: 1) {
                ForEach(filteredActions) { action in
                    actionRow(for: action)
                    if action != filteredActions.last {
                        Divider()
                            .background(Color.white.opacity(0.05))
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )

            // MARK: - Bottom Footer
            HStack {
                Text("\(filteredActions.count) snapping actions available")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer()

                Button("Reset to Defaults") {
                    service.resetToDefaults()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 0.05, green: 0.52, blue: 1.0))
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Accessibility Banner
    private var accessibilityBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Permission Required")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)

                Text("AppsChannel needs Accessibility privileges to resize and position windows.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Button("Grant Permission") {
                service.requestAccessibilityPermission()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(red: 0.05, green: 0.52, blue: 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.yellow.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Action Row
    private func actionRow(for action: WindowSnappingAction) -> some View {
        let conf = service.config(for: action)
        let isRecording = (recordingAction == action)
        let isEditingAlias = (editingAliasAction == action)

        return HStack(spacing: 12) {
            // Icon Glyph
            WindowActionGlyphView(action: action, size: 24)

            // Title
            Text(action.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(conf.isEnabled ? .white : .white.opacity(0.35))
                .lineLimit(1)

            Spacer()

            // MARK: Add Alias / Alias Badge
            if isEditingAlias {
                HStack(spacing: 4) {
                    TextField("Alias", text: $editingAliasText, onCommit: {
                        service.setAlias(editingAliasText, for: action)
                        editingAliasAction = nil
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 80)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color(red: 0.05, green: 0.52, blue: 1.0), lineWidth: 1)
                    )

                    Button(action: {
                        service.setAlias(editingAliasText, for: action)
                        editingAliasAction = nil
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            } else if !conf.alias.isEmpty {
                Button(action: {
                    editingAliasText = conf.alias
                    editingAliasAction = action
                }) {
                    HStack(spacing: 4) {
                        Text(conf.alias)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))

                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .onTapGesture {
                                service.setAlias("", for: action)
                            }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    editingAliasText = ""
                    editingAliasAction = action
                }) {
                    Text("Add Alias")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.001))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // MARK: Record Hotkey / Shortcut Badge
            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.05, green: 0.52, blue: 1.0))
                        .frame(width: 6, height: 6)

                    Text("Press keys...")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Button(action: {
                        stopRecording()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.05, green: 0.52, blue: 1.0).opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(red: 0.05, green: 0.52, blue: 1.0), lineWidth: 1)
                )
            } else if let label = conf.hotkeyLabel, !label.isEmpty {
                HStack(spacing: 5) {
                    Button(action: {
                        startRecording(for: action)
                    }) {
                        Text(label)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        service.clearHotkey(for: action)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .help("Clear hotkey")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
            } else {
                Button(action: {
                    startRecording(for: action)
                }) {
                    Text("Record Hotkey")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.001))
                }
                .buttonStyle(.plain)
            }

            // MARK: Enabled Checkbox
            Button(action: {
                service.setEnabled(!conf.isEnabled, for: action)
            }) {
                RaycastCheckbox(isChecked: conf.isEnabled)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    // MARK: - Hotkey Recording Logic
    private func startRecording(for action: WindowSnappingAction) {
        stopRecording()
        recordingAction = action

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            handleRecordedEvent(event)
            return nil // Consume event
        }
    }

    private func stopRecording() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        recordingAction = nil
    }

    private func handleRecordedEvent(_ event: NSEvent) {
        guard let action = recordingAction else { return }

        // Press Escape to cancel recording
        if event.keyCode == 53 {
            stopRecording()
            return
        }

        // Press Backspace or Delete to clear hotkey
        if (event.keyCode == 51 || event.keyCode == 117) && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            service.clearHotkey(for: action)
            stopRecording()
            return
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // Require at least one modifier key or an arrow / function key
        let isArrowOrFn = (event.keyCode >= 122 && event.keyCode <= 126)
        if flags.isEmpty && !isArrowOrFn {
            return
        }

        let carbonMods = flags.carbonFlags
        let keyCode = UInt32(event.keyCode)
        let label = formatKeyLabel(keyCode: keyCode, modifiers: flags)

        service.setHotkey(keyCode: keyCode, carbonModifiers: carbonMods, label: label, for: action)
        stopRecording()
    }

    private func formatKeyLabel(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []

        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        let keyString = stringForKeyCode(keyCode)
        parts.append(keyString)

        return parts.joined(separator: " ")
    }

    private func stringForKeyCode(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "⏎"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "⌫"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key \(keyCode)"
        }
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    init(title: String, count: Int? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))

                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            isSelected ? Color.black.opacity(0.2) : Color.white.opacity(0.15),
                            in: Capsule()
                        )
                }
            }
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.7))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Raycast Style Checkbox
struct RaycastCheckbox: View {
    let isChecked: Bool

    init(isChecked: Bool) {
        self.isChecked = isChecked
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isChecked ? Color.white.opacity(0.18) : Color.white.opacity(0.05))
                .frame(width: 17, height: 17)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(isChecked ? Color.white.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: 17, height: 17)

            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
