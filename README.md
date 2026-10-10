# AppsChannel

> **The classic magic of 3D Cover Flow meets the Nintendo Wii Channel Grid — reimagined as a modern, ultra-responsive macOS launcher with Apple Liquid Glass aesthetics.**

AppsChannel is a lightweight, hardware-accelerated macOS application launcher built entirely with SwiftUI and AppKit. It combines the tactile nostalgia of mid-2000s Cover Flow and gaming consoles with modern macOS design: native behind-window desktop blur, smooth spring physics, usage-based smart ranking, and customizable global shortcuts.

---

## Features

### 1. Dual Visual Display Modes (`⌘V`)
- **3D Cover Flow Carousel**: Hardware-accelerated 3D carousel with perspective tilt, mirror specular floor reflections, and smooth drag or scroll-wheel navigation.
- **Curved Cylindrical Wall Grid**: 3-row curved interactive wall inspired by classic channel grids, featuring cylindrical perspective math and dynamic slot badges.

### 2. Dual Launcher Experiences
- **Quick Launcher (`⌥L`)**: A floating, spotlight-like liquid glass HUD that blends seamlessly into your desktop with a soft feathered blur. Appears instantly, dismisses on click-out or `Esc`.
- **Main App Window**: A full frameless macOS liquid glass window with native traffic lights, resizability, and drag-anywhere background support.

### 3. Menu Bar Integration
- Runs unobtrusively in your macOS menu bar without cluttering the Dock (`LSUIElement`).
- Single click toggles the main window; right-click opens quick controls, settings, and cache management.
- Quick Launcher includes a dedicated button pinned at the far right to transition seamlessly into the main window.

### 4. Smart Usage-Based "Middle-Out" Ranking
- **Center-Fan Architecture**: Your most-used application is automatically placed at the center (Rank #1). Ranks radiate outward (#2 right, #3 left, #4 right, #5 left), so your favorites are immediately in focus on launch.
- **Associative Search Memory**: Remembers what apps you open for specific queries (e.g. searching `"code"` and launching *Visual Studio Code* will prioritize it over alphabetical matches).
- **Persistent Analytics**: Tracks launch frequency and recency locally (`~/.gemini` / application support) with zero telemetry or network calls.

### 5. Nintendo Wii / 3DS Channel Arranger
- Enter **Organize Mode** to freely rearrange channels.
- Move cards left, right, or pin to the front with custom order persistence (`UserDefaults`).
- Reset anytime to usage-based smart order or alphabetical order in Settings.

### 6. Power-User Keyboard & Gesture Shortcuts
| Shortcut | Action |
| :--- | :--- |
| `⌥L` | Toggle Quick Launcher from anywhere in macOS (customizable) |
| `⌘V` | Toggle between 3D Cover Flow and 3-Row Curved Wall Grid |
| `⌥1` – `⌥9` | Direct Launch Channel Slots 1 through 9 |
| `⌘1` – `⌘8` | Instant Category Group Switching (Dev, Productivity, Design, etc.) |
| `⌘O` | Switch from Quick Launcher to Main App Window |
| `⌘,` | Open Settings & Analytics Modal |
| `⌘W` | Close current window |
| `←` / `→` / Trackpad Scroll | Smooth carousel navigation |
| `Return` / Click | Launch selected application |

### 7. Blazing Fast Performance
- **Instant Cold Start (< 10ms)**: Multi-tier local disk caching with asynchronous delta scanning.
- **Dynamic Accent Glow**: Extracts each application's dominant palette to cast subtle ambient illumination across the glass backdrop.

---

## Architecture & Tech Stack

- **Platform**: macOS 14.0+ (Sonoma, Sequoia)
- **Frameworks**: SwiftUI, AppKit, Combine
- **Dependencies**: [HotKey](https://github.com/soffes/HotKey) (SPM package for global keyboard event registration)
- **Rendering**: SwiftUI hardware-accelerated 3D transforms (`rotation3DEffect`, `scaleEffect`, `VisualEffectBackground`)
- **Data & Caching**: Local JSON persistence (`apps_cache.json`, `usage_analytics.json`)

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

## Contributing

Contributions, bug reports, and feature suggestions are welcome!
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
