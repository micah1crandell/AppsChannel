# Contributing to AppsChannel

Thank you for your interest in contributing to **AppsChannel**! We welcome all contributions including bug fixes, new features, performance optimizations, and documentation improvements.

---

## Getting Started

### Prerequisites
- macOS 14.0 (Sonoma) or newer
- Xcode 15.0 or newer
- Swift 5.9+

### Local Setup
1. **Fork the repository** on GitHub.
2. **Clone your fork**:
   ```bash
   git clone https://github.com/<your-username>/AppsChannel.git
   cd AppsChannel
   ```
3. **Open the project in Xcode**:
   ```bash
   open AppsChannel.xcodeproj
   ```
4. **Or build via Terminal**:
   ```bash
   xcodebuild -scheme AppsChannel -destination 'platform=macOS' -derivedDataPath ./build build
   ```

---

## Development Guidelines

1. **Architecture & Frameworks**:
   - AppsChannel is built with **SwiftUI** and native **AppKit**.
   - Use AppKit where window-level control is required (e.g. `NSPanel`, `NSStatusItem`, behind-window blur).
   - Use SwiftUI for view composition, reactive data flow, and 3D transforms.
2. **Performance & Memory**:
   - The launcher is designed to cold-boot in < 10ms. Avoid blocking operations on the main thread.
   - Heavy operations (e.g. filesystem indexing, icons lookup) should use background actors/queues with disk caching.
3. **Privacy**:
   - Zero telemetry, zero analytics tracking, and zero network calls without user consent (except checking for software updates via Sparkle).

---

## Submitting Pull Requests

1. Create a branch for your changes (`git checkout -b feature/my-feature`).
2. Test your changes locally to ensure a clean build.
3. Commit your changes with clear commit messages (`git commit -m 'feat: add custom theme support'`).
4. Push to your branch (`git push origin feature/my-feature`).
5. Open a Pull Request referencing any related issues.

---

## Releasing & Distribution

For details on Apple Developer ID code signing, Hardened Runtime, Apple Notarization, Sparkle feeds, and Homebrew cask updates, please see the [Distribution & Notarization Guide](docs/DISTRIBUTION_AND_SIGNING.md).
