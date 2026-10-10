# Distribution, Code Signing & Apple Notarization Guide

This guide explains how **AppsChannel** builds, signs, notarizes, and distributes releases automatically via GitHub Actions, Homebrew, and Sparkle.

---

## Overview of the Release Pipeline

When a version tag is pushed (e.g. `git tag v1.0.1 && git push origin v1.0.1`), the GitHub Actions workflow [`.github/workflows/release.yml`](../.github/workflows/release.yml) executes:

1. **Compiles Release Build** with Hardened Runtime enabled.
2. **Codesigns with Developer ID**: Signs all embedded frameworks (`Sparkle.framework`, `HotKey`) and the main app bundle with Apple Developer ID Application certificates.
3. **Apple Notarization**: Submits the app archive to Apple's `notarytool` service and staples the notarization ticket to the app bundle.
4. **Drag-and-Drop DMG Creation**: Generates a styled `.dmg` installer with an `/Applications` drag-and-drop target via [`scripts/create_dmg.sh`](../scripts/create_dmg.sh).
5. **DMG Stapling**: Notarizes and staples the `.dmg` so offline users can open it without Gatekeeper warnings.
6. **Sparkle Auto-Update**: Signs the update with your Ed25519 key, generates the feed entry in `appcast.xml`, and commits it back to `main`.
7. **Homebrew Cask Bump**: Computes the SHA256 checksum of the DMG and updates `Casks/appschannel.rb` automatically.
8. **GitHub Release Publication**: Creates a GitHub release attaching `AppsChannel.dmg`, `AppsChannel.zip`, and `appcast.xml`.

---

## Required GitHub Repository Secrets

Configure the following secrets in **GitHub > Your Repository > Settings > Secrets and variables > Actions**:

| Secret Name | Description | Example / Format |
| :--- | :--- | :--- |
| `MACOS_CERTIFICATE` | Base64-encoded Apple Developer ID Application `.p12` certificate | `MIIKqQIBAzCCCgcGCSqGSIb3DQE...` |
| `MACOS_CERTIFICATE_PWD` | Password used when exporting the `.p12` certificate | `MySecretPass123` |
| `APPLE_ID` | Apple Developer account email address | `developer@example.com` |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password generated from Apple ID portal | `xxxx-xxxx-xxxx-xxxx` |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID | `6Q9B7S8YDR` |
| `SPARKLE_PRIVATE_KEY` | Sparkle Ed25519 base64 private key | `+abcdEFGH123...` |

> [!NOTE]
> If these secrets are not yet configured, the release workflow automatically falls back to **ad-hoc signing (`-`)**, allowing test builds to complete without errors while printing helpful setup reminders in the CI logs.

---

## Step-by-Step Secrets Setup

### 1. Export Developer ID Certificate (`MACOS_CERTIFICATE`)
1. Open **Keychain Access** on your Mac.
2. Locate your **Developer ID Application: <Your Name> (<Team ID>)** certificate under *login* or *System*.
3. Right-click the certificate (including its private key) and select **Export "Developer ID Application..."**.
4. Choose `.p12` format and set a strong password. Save it as `developer_id.p12`.
5. Encode the file to base64 and copy it to your clipboard:
   ```bash
   base64 -i developer_id.p12 | pbcopy
   ```
6. Add the copied string as `MACOS_CERTIFICATE` in GitHub Secrets.
7. Add the export password as `MACOS_CERTIFICATE_PWD`.

### 2. Apple Notarization Credentials (`APPLE_ID` & `APPLE_APP_SPECIFIC_PASSWORD`)
1. Go to [appleid.apple.com](https://appleid.apple.com) and sign in.
2. Under **Sign-In and Security**, select **App-Specific Passwords**.
3. Generate a password named `AppsChannel Notarization`.
4. Add your Apple ID email as `APPLE_ID` and the generated password as `APPLE_APP_SPECIFIC_PASSWORD` in GitHub Secrets.
5. Add your 10-character Team ID as `APPLE_TEAM_ID`.

### 3. Sparkle Ed25519 Keypair (`SPARKLE_PRIVATE_KEY`)
Sparkle 2 uses Ed25519 cryptography to securely sign updates:
1. Download or compile Sparkle CLI tools, or run:
   ```bash
   # Download Sparkle CLI
   curl -sL https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz | tar -xJ
   ./bin/generate_keys
   ```
2. The tool outputs a **Public Key** and saves a **Private Key**:
   * Add the **Public Key** to your `Info.plist`:
     ```xml
     <key>SUPublicEDKey</key>
     <string>YOUR_PUBLIC_KEY_STRING</string>
     ```
   * Add the **Private Key** as `SPARKLE_PRIVATE_KEY` in GitHub Secrets.

---

## Triggering a Release

Whenever you are ready to ship an update:

```bash
# 1. Ensure working directory is clean and pushed
git checkout main
git pull

# 2. Tag the release
git tag v1.0.1

# 3. Push the tag to GitHub
git push origin v1.0.1
```

You can also trigger releases manually from the **Actions** tab in GitHub by running the **Release** workflow with any tag name.
