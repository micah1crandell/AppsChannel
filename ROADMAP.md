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
- [x] Unified Quick Actions context menu across Cover Flow, Wall Grid, and Flat Grid.
- [x] Process control actions: Quit Application (`⌘Q`) and Force Quit.
- [x] Power user keyboard shortcuts: Reveal in Finder (`⌘⇧R`), Get Info (`⌘I`).
- [x] Swift unit test suite covering usage analytics, middle-out center-fan sorting, and shortcut presets.

### Phase 4: Retro Identity & Community Foundation
- [x] Sound themes: *Subtle Classic*, *Playful Pop*, *Mechanical Click*, and *Mute*.
- [x] Force Touch trackpad haptics on carousel snap and app launch.
- [x] GitHub Issue Forms (`bug_report.yml`, `feature_request.yml`), and PR template.
- [x] Security Policy with responsible disclosure guidelines and zero-telemetry commitments.

### Phase 5: Public Open-Source Launch Integrity
- [x] Standardized `MACOSX_DEPLOYMENT_TARGET = 14.0` for full Sonoma & Sequoia compatibility.
- [x] Embedded Sparkle 2 Ed25519 public key (`SUPublicEDKey`) in `Info.plist`.
- [x] Integrated `AppsChannelTests` test target into `AppsChannel.xcodeproj` and scheme test action.
- [x] Automated unit test suite execution in GitHub Actions CI workflow.
- [x] Seamless search input: clipboard paste (`⌘V`), layout cycle (`⌘⇧V`), and caret navigation (`←`/`→`).
- [x] Dynamic app version and build number resolution in Preferences.

### Phase 6: Spotlight Discovery & Dynamic System Presence
- [x] High-performance Spotlight application discovery via `NSMetadataQuery` for real-time app installs/uninstalls.
- [x] Deep nested directory scanning fallback for `/Applications/Utilities`, Setapp, and multi-app suites.
- [x] Dynamic System Presence settings: runtime toggle between Menu Bar extra, macOS Dock icon, or both (`NSApp.setActivationPolicy`).
- [x] Mutual exclusion safety safeguard ensuring at least one entry point (Dock or Menu Bar) remains active.
- [x] Dedicated unit tests in `AppDiscoveryServiceTests.swift` covering Spotlight queries, URL scanners, and app bundling.

### Phase 7: Custom Channels, Visual Themes & Recent Documents Sub-Deck
- [x] Custom Web Bookmarks and Siri Shortcut channels with persistent storage and asynchronous favicon caching.
- [x] Dedicated "Channels" Preferences manager and in-app "+ Add Channel" sheet in Organize Mode.
- [x] Full Visual Themes engine with 4 aesthetic presets (*Liquid Glass*, *Matte White*, *Indigo Purple*, *Cyberpunk Dark*).
- [x] Recent Documents Sub-Deck (`↓`) indexing recent files per application via Spotlight without requiring Full Disk Access.
- [x] Comprehensive unit tests in `CustomChannelTests.swift`, `ThemeManagerTests.swift`, and `RecentDocumentsServiceTests.swift`.

### Phase 8: Developer Ecosystem, CLI Companion & Script Channels
- [x] Lightweight CLI Companion executable (`bin/appschannel`) supporting `toggle`, `open`, `close`, `launch <query>`, `theme <theme>`, `list`, `status`, and `install`.
- [x] Custom Shell Script Channels: pin shell commands, terminal tools, and scripts as first-class interactive channel cards.
- [x] Expanded Custom URL Scheme handler (`appschannel://launch?query=`, `appschannel://theme?name=`, `appschannel://close`, `appschannel://preferences`).
- [x] CLI Companion management card in Settings with 1-click install into `~/.local/bin` or `/usr/local/bin` and sample command quick-copy.
- [x] Comprehensive unit tests in `CustomChannelTests.swift` and `AppDiscoveryServiceTests.swift`.

### Phase 9: Quick System Actions & Reactive Keyboard Modifiers
- [x] Native Quick System Actions (`SystemActionService`): instant execution for *Lock Screen*, *Sleep*, *Restart*, *Shut Down*, *Empty Trash*, *Toggle Dark/Light Mode*, *Toggle Mute*, *Toggle Wi-Fi*, and *Bluetooth Settings*.
- [x] Fuzzy search relevance and alias scoring for all system actions (e.g. `lock`, `sleep`, `restart`, `trash`, `dark`, `mute`, `wifi`).
- [x] Safeguard confirmation alerts for destructive actions (*Restart* and *Shut Down*) with user toggle in Settings.
- [x] Real-time reactive keyboard modifier listener (`KeyboardModifierManager`): tracks `⌘`, `⌥`, `⇧`, `⌃` on `flagsChanged` and updates HUD hints dynamically in real time.
- [x] Contextual Return key actions: `Return` (Launch), `⌘Return` (Reveal in Finder), `⌥Return` (Recent Documents), `⇧Return` (Copy Path / URL with toast feedback).
- [x] Full URL scheme support for system actions (`appschannel://system?action=<action>`).
- [x] Dedicated unit test suites in `SystemActionServiceTests.swift` and `KeyboardModifierManagerTests.swift` (50 total unit tests passing).

---

## 🚀 Future Vision & Upcoming Milestones

### Near-Term (v1.1 – v1.2)
* **Raycast & Alfred Extensions**:
  * Official extension packages for Raycast and Alfred to toggle AppsChannel and pipe external search queries into the channel grid.
* **Custom Channel Sound Effects & Jingles**:
  * Optional retro audio jingles and custom sound clips per custom channel tile.
* **Spotlight / Raycast Calculator Fallback**:
  * Instant math evaluation and currency conversions directly in the search bar.
* **Smart App Stacks & Custom Category Folders**:
  * Group related applications into collapsible stacks within the Channel Grid.
* **Stream Deck & Touch Bar Integration**:
  * Direct tactile macro triggers for cycling views and selecting channel slots.
