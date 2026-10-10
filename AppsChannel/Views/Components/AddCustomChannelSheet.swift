import SwiftUI
import AppKit

struct AddCustomChannelSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var channelManager = CustomChannelManager.shared

    @State private var channelKind: CustomChannelKind = .web
    @State private var name: String = ""
    @State private var target: String = ""
    @State private var selectedColorHex: String = "#0A84FF"

    private let colorPalette: [(name: String, hex: String)] = [
        ("Blue", "#0A84FF"),
        ("Purple", "#BF5AF2"),
        ("Pink", "#FF375F"),
        ("Orange", "#FF9F0A"),
        ("Green", "#30D158"),
        ("Teal", "#64D2FF"),
        ("Yellow", "#FFD60A")
    ]

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !trimmedTarget.isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Add Custom Channel")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Pin websites, web apps, Siri Shortcuts, or shell scripts to your channel grid.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            // Mode Picker
            Picker("Channel Type", selection: $channelKind) {
                Label("Web Bookmark", systemImage: "globe").tag(CustomChannelKind.web)
                Label("Siri Shortcut", systemImage: "bolt.fill").tag(CustomChannelKind.shortcut)
                Label("Shell Script", systemImage: "terminal.fill").tag(CustomChannelKind.script)
            }
            .pickerStyle(.segmented)
            .onChange(of: channelKind) { _, newKind in
                if newKind == .shortcut && !channelManager.availableShortcuts.isEmpty && target.isEmpty {
                    target = channelManager.availableShortcuts.first ?? ""
                    if name.isEmpty {
                        name = target
                    }
                } else if newKind == .script && selectedColorHex == "#0A84FF" {
                    selectedColorHex = "#30D158"
                }
            }

            // Form Inputs
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Channel Name")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    TextField(channelKind == .web ? "e.g. GitHub" : (channelKind == .shortcut ? "e.g. Daily Standup" : "e.g. Clean DerivedData"), text: $name)
                        .textFieldStyle(.plain)
                        .padding(9)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                }

                if channelKind == .web {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Website URL")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        TextField("e.g. https://github.com or figma.com", text: $target)
                            .textFieldStyle(.plain)
                            .padding(9)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                    }
                } else if channelKind == .shortcut {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Shortcut Name")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))

                        if !channelManager.availableShortcuts.isEmpty {
                            Picker("", selection: $target) {
                                ForEach(channelManager.availableShortcuts, id: \.self) { sc in
                                    Text(sc).tag(sc)
                                }
                            }
                            .onChange(of: target) { _, newTarget in
                                if name.isEmpty || channelManager.availableShortcuts.contains(name) {
                                    name = newTarget
                                }
                            }
                        } else {
                            TextField("Exact shortcut name as shown in Shortcuts app", text: $target)
                                .textFieldStyle(.plain)
                                .padding(9)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Shell Command or Script Path")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        TextField("e.g. git status, rm -rf ~/Library/Developer/Xcode/DerivedData/*, or ~/bin/script.sh", text: $target)
                            .textFieldStyle(.plain)
                            .padding(9)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                    }
                }

                // Accent Color Palette
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accent Color")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 12) {
                        ForEach(colorPalette, id: \.hex) { item in
                            Button {
                                selectedColorHex = item.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: item.hex) ?? .blue)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: selectedColorHex == item.hex ? 2.5 : 0)
                                    )
                                    .shadow(color: (Color(hex: item.hex) ?? .blue).opacity(selectedColorHex == item.hex ? 0.6 : 0), radius: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer().frame(height: 4)

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    saveChannel()
                } label: {
                    Text("Create Channel")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(
            VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
                .overlay(Color.black.opacity(0.65))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func saveChannel() {
        guard isValid else { return }
        switch channelKind {
        case .web:
            channelManager.addWebChannel(name: name, urlString: target, accentHex: selectedColorHex)
        case .shortcut:
            channelManager.addShortcutChannel(name: name, shortcutName: target, accentHex: selectedColorHex)
        case .script:
            channelManager.addScriptChannel(name: name, command: target, accentHex: selectedColorHex)
        }
        SoundEffectsManager.shared.playAction()
        dismiss()
    }
}
