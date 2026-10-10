# AppsChannel

<p align="center">
  <img src="AppsChannel/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="AppsChannel Icon" />
</p>

<p align="center">
  <strong>The classic magic of 3D Cover Flow meets the Channel Grid — reimagined as a modern, ultra-responsive macOS launcher with Apple Liquid Glass aesthetics.</strong>
</p>

<p align="center">
  <a href="https://github.com/micah1crandell/AppsChannel/releases/latest"><img src="https://img.shields.io/github/v/release/micah1crandell/AppsChannel?color=blue&label=version&logo=apple" alt="GitHub Release" /></a>
  <a href="https://github.com/micah1crandell/AppsChannel/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/micah1crandell/AppsChannel/ci.yml?branch=main&label=CI&logo=github" alt="CI Status" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B%20(Sonoma%20%7C%20Sequoia)-black?logo=apple" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white" alt="Swift 5.9+" />
  <img src="https://img.shields.io/badge/arch-Universal%20(Apple%20Silicon%20%26%20Intel)-purple" alt="Universal Binary" />
  <img src="https://img.shields.io/badge/telemetry-0%25%20(Local%20Only)-success" alt="Zero Telemetry" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" /></a>
</p>

---

AppsChannel is a lightweight, hardware-accelerated macOS application launcher built entirely with SwiftUI and AppKit. It combines the tactile nostalgia of mid-2000s Cover Flow and classic channel interfaces with modern macOS design: native behind-window desktop blur, smooth spring physics, usage-based smart ranking, and customizable global shortcuts.

---

## Features

### 1. Four Visual Layout Modes (`⌘V`)
- **Minimalist 3D App Icon Flow**: Pure macOS application icons in a classic 3D Cover Flow carousel with perspective tilt, vibrant dynamic accent lighting, and specular mirror floor reflections.
- **3D Channel Cards Flow**: macOS Channel cards with category tags, status badges, and specular reflections.
- **Curved Cylindrical Wall Grid**: 3-row curved interactive wall with cylindrical perspective math and dynamic slot badges.
- **Flat Grid**: Flat paginated channel grid (configurable from 1 to 5 horizontal rows) with turquoise reticle cursor and dynamic title banner.

### 2. Dual Launcher Experiences
- **Quick Launcher (`⌥L`)**: A floating, spotlight-like liquid glass HUD that blends seamlessly into your desktop with a soft feathered blur. Appears instantly, dismisses on click-out or `Esc`.
- **Main App Window**: A full frameless macOS liquid glass window with native traffic lights, resizability, and drag-anywhere background support.

### 3. Retro Sound Themes & Force Touch Haptics
- **Tactile Audio Themes**: Choose between *Subtle Classic*, *Playful Pop*, and *Mechanical Click* for card selection, navigation, and launch feedback.
- **Instant Audio Preview**: Audition themes directly in Preferences with live auditory feedback.
- **Force Touch Trackpad Haptics**: Subtle physical alignment pulses on Apple trackpads synchronized with card navigation.

### 4. Menu Bar & Dock Integration
- **Flexible System Presence**: Choose between running unobtrusively in the Menu Bar (`LSUIElement`), visible in the macOS Dock, or both simultaneously via Preferences.
- **Fail-Safe Visibility Guard**: Intelligent safeguarding ensures you can never accidentally disable both Dock and Menu Bar access simultaneously.
- **Single-Click / Right-Click Controls**: Single click toggles the main window; right-click opens quick controls, settings, and cache management.
- **Quick Launcher Bridge**: Quick Launcher includes a dedicated button pinned at the far right to transition seamlessly into the main window.

### 5. Spotlight & Deep Application Discovery
- **Live Spotlight Indexing**: Leverages `NSMetadataQuery` for `com.apple.application-bundle` to instantly discover apps across all system volumes and reactively respond when apps are installed or uninstalled.
- **Deep Hierarchy Fallback**: Intelligently traverses nested directories in `/Applications`, `~/Applications`, `/System/Applications`, `/Applications/Utilities`, Setapp, and multi-app suites (up to 1 level deep).
- **Asynchronous Warm Cache**: Immediately hydrates the UI from local cache upon launch, then seamlessly refreshes in the background without UI stutter.

### 6. Custom Channels (Web URLs, Siri Shortcuts & Shell Scripts)
- **Pin Any Website or Web App**: Add URLs (e.g., GitHub, Figma, Linear) as native channel cards. AppsChannel automatically downloads and caches high-resolution favicons asynchronously.
- **Siri Shortcuts Integration**: Execute any macOS Shortcut directly with one click or keyboard shortcut.
- **Custom Shell Script Channels**: Pin terminal commands, build tasks, or bash/zsh scripts (e.g., `git status`, `docker compose up`, or cleanup utilities) as dedicated interactive tiles.
- **Dedicated Channel Management**: Add, organize, color-code, and delete custom channels via Preferences or in Organize Mode.

### 7. CLI Companion & Custom URL Scheme (v2.0)
- **Command-Line Interface (`appschannel`)**: Fast, zero-dependency CLI companion tool for Terminal, Raycast, Alfred, and developer scripts:
  - `appschannel toggle`: Toggle launcher window
  - `appschannel launch <query>`: Instantly fuzzy-search and launch any app, web channel, or script
  - `appschannel theme <theme>`: Switch visual themes on the fly (`liquid-glass`, `matte-white`, `indigo`, `cyberpunk`)
  - `appschannel list`: Inspect indexed applications and channels
  - `appschannel status`: Inspect running process status and configuration
- **1-Click Installation**: Install directly into `~/.local/bin` or `/usr/local/bin` with one click from Preferences (`⌘,` -> Channels).
- **Custom URL Scheme**: Full deep-linking IPC via `appschannel://launch?query=...`, `appschannel://theme?name=...`, `appschannel://close`, `appschannel://toggle`, and `appschannel://preferences`.

### 8. Visual Themes
- **Four Distinct Retro & Modern Presets**:
  - *Liquid Glass (Default)*: Translucent frosted glass with dynamic monochrome reflections.
  - *Matte White*: Crisp, clean matte white channel aesthetic with clean cyan borders.
  - *Indigo Purple*: Deep indigo purple shell with vibrant accent lighting.
  - *Cyberpunk Dark*: High-contrast slate black with vivid neon cyan and magenta edge glow.
- **Instant Audition**: Switch visual themes in Preferences with instant reactive rendering across all cards and backdrops.

### 9. Recent Documents Sub-Deck (`↓`)
- **Spotlight Document Indexing**: Press Down Arrow (`↓`) in Cover Flow or select *Recent Documents* in the context menu to expand a tactile sub-deck showing recent files and workspaces opened by that application.
- **TCC Compliant**: Powered natively by macOS Spotlight metadata querying without requiring invasive Full Disk Access permissions.
- **One-Click Opening**: Click or hit Return to open any recent document directly into its parent application.

### 10. Smart Usage-Based "Middle-Out" Ranking
- **Center-Fan Architecture**: Your most-used application is automatically placed at the center (Rank #1). Ranks radiate outward (#2 right, #3 left, #4 right, #5 left), so your favorites are immediately in focus on launch.
- **Associative Search Memory**: Remembers what apps you open for specific queries (e.g. searching `"code"` and launching *Visual Studio Code* will prioritize it over alphabetical matches).
- **Persistent Analytics**: Tracks launch frequency and recency locally with zero telemetry or network calls.

### 11. Channel Arranger
- Enter **Organize Mode** to freely rearrange channels.
- Move cards left, right, or pin to the front with custom order persistence (`UserDefaults`).
- Reset anytime to usage-based smart order or alphabetical order in Settings.

### 12. Running Indicators & Quick Actions
- **Active Process Dots**: Glowing ambient green indicators reactively surface applications currently executing in system memory.
- **Context Actions (Right-Click / Keyboard)**:
  - *Reveal in Finder* (`⌘⇧R` or `⌘R`)
  - *Get Info* (`⌘I`)
  - *Copy Path & Bundle ID*
  - *Quit / Force Quit Application* for active processes
  - *Hide Application* from the grid

### 13. Multi-Display & Accessibility Ergonomics
- **Pointer-Targeted Display Spawning**: Automatically detects which monitor contains your mouse cursor to present the HUD on your active screen without jumping to primary displays.
- **Reduce Motion Compliant**: Automatically adapts 3D transforms, perspective spins, and spring physics when *Reduce Motion* is enabled in macOS Accessibility.
- **VoiceOver Ready**: Comprehensive accessibility labels, traits, and hints for all cards and actions.

### 14. Power-User Keyboard & Gesture Shortcuts
| Shortcut | Action |
| :--- | :--- |
| `⌥L` | Toggle Quick Launcher from anywhere in macOS (customizable) |
| `⌘⇧V` / `⌘V` | Cycle between Cover Flow, Wall Grid, and Flat Grid (or paste into search) |
| `⌘⇧R` | Reveal currently focused application in Finder |
| `⌘I` | Open macOS Finder Get Info window for focused app |
| `⌥1` – `⌥9` | Direct Launch Channel Slots 1 through 9 |
| `⌘1` – `⌘8` | Instant Category Group Switching (Dev, Productivity, Design, etc.) |
| `⌘O` | Switch from Quick Launcher to Main App Window |
| `⌘,` | Open Settings & Analytics Modal |
| `⌘W` | Close current window |
| `←` / `→` / Trackpad Scroll | Smooth carousel navigation |
| `Return` / Click | Launch selected application |

---

## Architecture & Tech Stack

- **Platform**: macOS 14.0+ (Sonoma, Sequoia)
- **Frameworks**: SwiftUI, AppKit, SceneKit, Combine
- **Dependencies**: 
  - [HotKey](https://github.com/soffes/HotKey) (SPM package for global keyboard event registration)
  - [Sparkle](https://github.com/sparkle-project/Sparkle) (SPM package for secure GitHub Releases auto-updating)
- **Rendering**: SwiftUI hardware-accelerated 3D transforms (`rotation3DEffect`, `scaleEffect`, `VisualEffectBackground`)
- **Data & Caching**: Multi-tier local disk persistence (`apps_cache.json`, `usage_analytics.json`)

---

## Installation

### Via Homebrew (Recommended)
```bash
brew tap micah1crandell/appschannel https://github.com/micah1crandell/AppsChannel
brew install --cask appschannel
```

### Direct Download
Download the latest `.dmg` or `.zip` directly from [GitHub Releases](https://github.com/micah1crandell/AppsChannel/releases). Once installed, AppsChannel updates itself automatically via built-in Sparkle updates.

---

## Getting Started

### Prerequisites
- macOS 14.0 or newer
- Xcode 15.0 or newer
- Swift 5.9+

### Building from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/micah1crandell/AppsChannel.git
   cd AppsChannel
   ```

2. **Open in Xcode:**
   ```bash
   open AppsChannel.xcodeproj
   ```

3. **Or build via Terminal:**
   ```bash
   xcodebuild -scheme AppsChannel -destination 'platform=macOS' -derivedDataPath ./build build
   ```

4. **Run the built application:**
   ```bash
   open ./build/Build/Products/Debug/AppsChannel.app
   ```

---

## Configuration & Permissions

- **Accessibility**: When configuring custom global hotkeys, macOS may request Accessibility permissions under *System Settings > Privacy & Security > Accessibility*.
- **Menu Bar**: The app runs as an accessory status item. Click the menu bar icon or press `⌥L` to activate the launcher.

---

## Contributing & Community

Contributions, bug reports, and feature suggestions are welcome!
- 🗺️ Read our [Product Roadmap](ROADMAP.md) to see active and planned initiatives.
- 🛠️ Follow the [Contributing Guide](CONTRIBUTING.md) to get set up locally.
- 🔒 For security disclosures, refer to our [Security Policy](SECURITY.md).

---

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
