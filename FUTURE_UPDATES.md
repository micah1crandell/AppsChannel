# AppsChannel - Future Updates Plan

This document outlines the strategic roadmap and future feature specifications designed to position **AppsChannel** as a joyful, high-performance, open-source macOS launcher and desktop companion.

---

## 📋 Feature Roadmap

### 1. Local Clipboard History
* **Description**: A 100% on-device, encrypted clipboard history manager accessible via a dedicated shortcut (e.g. `⌥C`) or an expandable sub-deck.
* **Key Details**: 
  * Zero-telemetry, private SQLite storage for copied text, URLs, code snippets, and image clippings.
  * Searchable through the unified search bar with live preview cards.
  * Configurable history retention rules and automatic exclusion of sensitive data from password managers (via `org.nspasteboard.ConcealedType`).

---

### 2. Quick System Actions ✅ *(Completed in v1.1 / Phase 9)*
* **Description**: Instant execution of macOS system commands and hardware toggles directly from the search bar or dedicated grid cards.
* **Key Details**:
  * Actions include: *Lock Screen*, *Sleep*, *Restart*, *Shut Down*, *Empty Trash*, *Toggle Dark/Light Mode*, *Toggle Mute*, and *Toggle Wi-Fi/Bluetooth*.
  * Accessible via fuzzy search (e.g., typing `"lock"` or `"trash"`) with optional confirmation safeguards for destructive actions like restart and shut down.

---

### 3. Comprehensive Window Snapping ✅ *(Completed in v1.1 / Phase 9)*
* **Description**: Built-in, high-performance native macOS window management and snapping engine with 52 snapping modes, Raycast-style settings UI, and global hotkey recording.
* **Key Details**:
  * 52 snapping modes across 9 categories: Halves, Thirds, Two-Thirds, Fourths, Three-Fourths, Corners/Quarters, Sixths, Maximize/Almost Maximize, Center, Nudge/Resize, Multi-Display Transfer, and 10-level Undo/Restore.
  * Raycast-style settings modal tab with vector glyph icons, inline alias editing, and interactive global keyboard shortcut recording.
  * Seamless multi-monitor support and quick launcher search integration.

---

### 4. Keyboard Modifiers ✅ *(Completed in v1.1 / Phase 9)*
* **Description**: Contextual action modifiers using modifier keys (`⌥`, `⌘`, `⇧`, `⌃`) when interacting with channel cards or search results.
* **Key Details**:
  * Pressing `Return` launches the app; holding `⌘Return` reveals it in Finder; holding `⌥Return` opens its recent documents sub-deck; holding `⇧Return` copies its bundle path or URL.
  * Dynamic on-screen HUD hints update reactively in real time when modifier keys are depressed.

---

### 5. Live Widget Channels
* **Description**: Interactive, glanceable channel cards that display dynamic, real-time system and application states directly in the grid.
* **Key Details**:
  * **Now Playing Card**: Real-time album artwork, track title, and playback controls for Apple Music and Spotify.
  * **Next Meeting Card**: Calendar integration showing countdown to upcoming events with one-click video conference join links.
  * **System Glance Card**: Live mini sparklines and meters for CPU, memory, and battery status.

---

### 6. Workspaces & Contexts Channels
* **Description**: Multi-action workflow channels that launch a curated group of apps, documents, and system settings simultaneously with one click.
* **Key Details**:
  * Define contextual profiles (e.g., *"Dev Work"*, *"Design Sprint"*, *"Focus Writing"*).
  * A single channel trigger opens the required apps, launches specific project folders in IDEs/terminals, sets macOS Focus modes, and arranges browser tabs.

---

### 7. Super Customizable Home Screen & Community Theme Engine (Wii & Retro Console Aesthetics)
* **Description**: A comprehensive, modular theming framework enabling radical visual overhauls of the main app—including an authentic 2006 Wii Home Screen homage—and empowering the community to build, share, and hot-reload custom skins.
* **Key Details & Aesthetic Architecture**:
  * **Wii Home Screen Mode Anatomy**:
    * **4×3 Paged Channel Grid**: 12 slots per page with beveled glossy frames, glass highlights, and animated empty channel filler textures when fewer apps are present.
    * **Interactive Sprite Hand Pointer**: Replaces standard cursor with the iconic white cartoon hand pointer (`cursor_pointer.png`, `cursor_hover.png`, and a clenched `cursor_grab.png` for drag-to-reorder organize mode) featuring a blue P1 badge.
    * **Retro Console Bottom Deck & Real-time Clock**: Curved lower dashboard featuring a prominent digital clock and date pill (`h:mm a`), circular options button (settings), and envelope button (recent documents / quick actions).
    * **Side Paging Chevrons**: Large side navigation arrows (`<` and `>`) supporting keyboard (`A`/`D` or arrow keys) and click transitions with paper-swoosh animations.
  * **Asset Requirements**:
    * **Visual Sprites**: High-DPI Retina assets for pointing/hover/grab hand cursors with hotspot coordinates, 9-slice beveled channel frames, empty slot scanlines, and subtle background dot-matrix/scanline overlays.
    * **Audio & Ambience**: Low-latency 44.1kHz sound effects for cursor tick, channel select chime, app launch whoosh, and page turns, paired with an optional seamless ambient background music loop (`ambient_loop.m4a`) with volume controls.
    * **Distribution Strategy**: Ships with a legally clean, built-in "Console 2006" homage pack, while providing an open pipeline for user-imported 1:1 replica packs.
  * **Community Theme Engine Architecture**:
    * **`.appschanneltheme` Bundle Format**: Self-contained packages (or `.zip` bundles) housing a declarative `theme.json` manifest, `assets/` directory, `sounds/` directory, and a `preview.png` card.
    * **Declarative `theme.json`**: Exposes customizable window background gradients/patterns, grid dimensions (columns, rows, aspect ratio, border radius), HUD and clock formats, cursor sprite offsets, and audio mappings.
    * **Themes Storage & Drag-and-Drop**: Resides at `~/Library/Application Support/AppsChannel/Themes/`; users can drag-and-drop themes directly into Settings or click an "Open Themes Folder in Finder" button.
    * **Live FSEvents Hot-Reloading**: Real-time file system watcher allowing creators to tweak `theme.json` or swap assets in an external editor and observe instantaneous live updates in the running app.
    * **Cross-Component Future Proofing**: Unified theme schema ready to skin both the Main Home Screen and future customizable Quick Launcher HUDs.
  * **Implementation Phases**:
    * *Phase 1*: Decouple static `AppVisualTheme` enum into a dynamic `ThemeConfiguration` model and JSON bundle loader.
    * *Phase 2*: Implement 4×3 paged console grid mode, empty slot fillers, and side paging arrows.
    * *Phase 3*: Implement sprite-based cursor tracker, retro bottom deck with live clock, and ambient loop audio player.
    * *Phase 4*: Build the Settings theme gallery, drag-and-drop installer, and `FSEvents` directory watcher.

---

### 8. Script Channel Evolution
* **Description**: Upgraded developer execution engine for Custom Shell Script Channels supporting dynamic input arguments and reactive output cards.
* **Key Details**:
  * Scripts written in any language (Bash, Zsh, Python, Swift, Go, Rust) that output standard JSON schemas can render custom cards, badges, and interactive action lists.
  * Inline argument prompt modals for parameterized commands (e.g., passing a commit message to a `git push` channel).

---

### 9. Decentralized GitHub Extension Registry
* **Description**: A lightweight, community-driven extension discovery and installation mechanism powered entirely by open GitHub repositories.
* **Key Details**:
  * Install curated custom channels, script tools, themes, and shortcuts with a single click or CLI command (`appschannel install <github-repo>`).
  * No closed-door app store approval process, telemetry, or proprietary walled gardens—completely open source and transparent.

---

### 10. Official Raycast Extension
* **Description**: A companion extension published to the Raycast store to provide seamless coexistence and bridge Raycast users to AppsChannel.
* **Key Details**:
  * Quick commands inside Raycast to trigger AppsChannel view layouts, pipe search queries directly into Cover Flow, and switch active visual themes.
  * Allows users to transition gradually to AppsChannel without abandoning their existing Raycast setup on day one.
