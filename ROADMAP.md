# AppsChannel Roadmap

Welcome to the **AppsChannel** product roadmap. This document outlines our past milestones, active developments, and future plans for the community.

---

## 🎯 Completed Milestones

### Phase 1: Release Engineering & Security
- [x] Apple Developer ID Application code signing and Hardened Runtime entitlements.
- [x] Automated Apple Notarization with `xcrun notarytool` and ticket stapling in GitHub Actions.
- [x] Polished drag-and-drop `.dmg` installer with `/Applications` drop target and custom volume icon.
- [x] Sparkle 2 Ed25519 feed automation (`appcast.xml`).
- [x] Automated Homebrew Cask checksum updates on release tags.

### Phase 2: macOS System Citizenship & Ergonomics
- [x] Multi-display pointer detection (`targetScreenForPointer`) to present HUDs on the user's active cursor screen.
- [x] Display parameters change observer (`didChangeScreenParametersNotification`) for seamless monitor reconnects.
- [x] macOS Accessibility `Reduce Motion` support (suppresses high-angle 3D transforms, uses gentle fades).
- [x] Complete VoiceOver accessibility hierarchy (`accessibilityElement`, labels, hints, and traits).
- [x] String Catalog (`Localizable.xcstrings`) for multi-language community translations.

### Phase 3: Core Launcher Features
- [x] Active process detection via `NSWorkspace` notifications with ambient glowing green indicators.
- [x] Unified Quick Actions context menu across Cover Flow, Wall Grid, and 3DS Grid.
- [x] Process control actions: Quit Application (`⌘Q`) and Force Quit.
- [x] Power user keyboard shortcuts: Reveal in Finder (`⌘⇧R`), Get Info (`⌘I`).
- [x] Swift unit test suite covering usage analytics, middle-out center-fan sorting, and shortcut presets.

### Phase 4: Retro Identity & Community Foundation
- [x] Sound themes: *Subtle Classic*, *Playful Pop*, *Mechanical Click*, and *Mute*.
- [x] Force Touch trackpad haptics on carousel snap and app launch.
- [x] GitHub Issue Forms (`bug_report.yml`, `feature_request.yml`), and PR template.
- [x] Security Policy with responsible disclosure guidelines and zero-telemetry commitments.

---

## 🚀 Future Vision & Upcoming Features

### Near-Term (v1.1 – v1.2)
* **Custom Channels (Web & Shortcuts)**:
  * Create custom channel tiles for web URLs (auto-fetching high-resolution favicons) or macOS Shortcuts (`shortcuts run ...`).
  * Custom icon uploads and custom channel accent colors.
* **Themes & Visual Presets**:
  * *Wii Channel Pure White* (glossy Wii-style matte white with channel borders)
  * *GameCube Indigo* (deep purple matte geometry)
  * *Cyberpunk Dark* (neon cyan / magenta illumination)
* **Recent Documents Sub-Deck**:
  * Press Down Arrow (`↓`) on focused apps to expand their recent files and workspaces.

### Long-Term (v2.0)
* **Extension & Script API**:
  * Lightweight CLI companion (`appschannel launch <query>`).
  * Support custom shell scripts or Python utilities as dedicated channel cards.
* **Spotlight / Raycast Fallback**:
  * Seamless delegation to system search or calculators when no local application matches.
