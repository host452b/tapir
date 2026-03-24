# Tapir — Build & Release Guide

## Prerequisites

- macOS 14.0+ (Sonoma)
- Rust toolchain (`rustup`, latest stable)
- Node.js 18+ & npm
- Xcode Command Line Tools (`xcode-select --install`)
- Apple Developer ID certificate (for signing)
- App Store Connect account (for MAS distribution)

---

## 1. Development (Hot Reload)

Frontend Vite dev server + Rust backend with hot reload:

```bash
npm run tauri dev
```

- Frontend: `http://localhost:1420` with HMR
- Rust: recompiles on `src-tauri/src/` changes
- **No sandbox** — runs as debug binary, Accessibility permission applies to the terminal/IDE
- Use this for daily development and UI iteration

---

## 2. Debug Build

Full debug build (no optimization, with debug symbols):

```bash
npm run build:debug
```

Or manually:

```bash
# Frontend
npm run build

# Rust debug
cd src-tauri && cargo build
```

Output: `src-tauri/target/debug/tapir`

- Includes debug symbols and assertions
- No code signing, no sandbox
- Use for debugging Rust panics, testing FFI bindings

---

## 3. Release Build (Developer ID)

Optimized release build for direct distribution (outside App Store):

```bash
npm run build:release
```

Or manually:

```bash
npm run tauri build
```

Output:
- `src-tauri/target/release/bundle/macos/Tapir.app`
- `src-tauri/target/release/bundle/dmg/Tapir_2.0.0_aarch64.dmg`

### Signing for distribution

```bash
# Sign with Developer ID
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: YOUR NAME (TEAM_ID)" \
  --options runtime \
  --entitlements src-tauri/Tapir.entitlements \
  src-tauri/target/release/bundle/macos/Tapir.app

# Notarize
xcrun notarytool submit \
  src-tauri/target/release/bundle/dmg/Tapir_2.0.0_aarch64.dmg \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

# Staple
xcrun stapler staple src-tauri/target/release/bundle/dmg/Tapir_2.0.0_aarch64.dmg
```

### Verify

```bash
# Check entitlements
codesign -d --entitlements - src-tauri/target/release/bundle/macos/Tapir.app

# Check notarization
spctl -a -vvv src-tauri/target/release/bundle/macos/Tapir.app
```

---

## 4. Mac App Store (MAS) Build

App Store builds require additional entitlements and provisioning.

### 4a. Entitlements

Create `src-tauri/Tapir.mas.entitlements` for App Store submission:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.application-identifier</key>
    <string>TEAM_ID.com.tapir.app</string>
    <key>com.apple.developer.team-identifier</key>
    <string>TEAM_ID</string>
</dict>
</plist>
```

### 4b. Build

```bash
npm run build:mas
```

Or manually:

```bash
# Build release
npm run tauri build

# Re-sign with App Store certificate
codesign --deep --force --verify --verbose \
  --sign "3rd Party Mac Developer Application: YOUR NAME (TEAM_ID)" \
  --entitlements src-tauri/Tapir.mas.entitlements \
  src-tauri/target/release/bundle/macos/Tapir.app

# Package as .pkg for App Store
productbuild \
  --component src-tauri/target/release/bundle/macos/Tapir.app /Applications \
  --sign "3rd Party Mac Developer Installer: YOUR NAME (TEAM_ID)" \
  Tapir_2.0.0.pkg
```

### 4c. Upload to App Store Connect

```bash
xcrun altool --upload-app \
  --type osx \
  --file Tapir_2.0.0.pkg \
  --apiKey "YOUR_API_KEY" \
  --apiIssuer "YOUR_ISSUER_ID"
```

Or use **Transporter.app** (drag & drop the `.pkg`).

### 4d. App Store Review Checklist

| Item | Status |
|------|--------|
| Sandbox enabled | `com.apple.security.app-sandbox = true` |
| NSAccessibilityUsageDescription | In Info.plist |
| Minimum OS | macOS 14.0 |
| No private APIs | CGEvent/AX are public frameworks |
| App category | Utilities / Productivity |
| Screenshots | 1280x800 or 1440x900 (already in `app_store_assets/`) |

---

## 5. Clean Build

Remove all build artifacts and caches:

```bash
npm run clean
```

This runs `scripts/clean.sh` which removes:
- `node_modules/`
- `dist/`
- `src-tauri/target/`
- npm/Vite cache files
- Rust incremental compilation cache

### Partial cleans

```bash
# Frontend only
npm run clean:frontend

# Rust only
npm run clean:rust

# Just Rust release artifacts
npm run clean:release
```

---

## npm Scripts Reference

| Script | Description |
|--------|-------------|
| `npm run tauri dev` | Hot-reload dev mode |
| `npm run build:debug` | Debug build (no optimization) |
| `npm run build:release` | Release build → .app + .dmg |
| `npm run build:mas` | Mac App Store build → .app (re-sign needed) |
| `npm run clean` | Remove ALL build artifacts |
| `npm run clean:frontend` | Remove node_modules/ + dist/ |
| `npm run clean:rust` | Remove src-tauri/target/ |
| `npm run clean:release` | Remove only release artifacts |

---

## Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `APPLE_SIGNING_IDENTITY` | Code signing certificate name | `Developer ID Application: ...` |
| `APPLE_ID` | Apple ID for notarization | `your@email.com` |
| `APPLE_TEAM_ID` | Developer team ID | `ABC123DEF4` |
| `APPLE_API_KEY` | App Store Connect API key | `AuthKey_XXXXX.p8` |
| `APPLE_API_ISSUER` | API key issuer ID | `xxxxxxxx-xxxx-...` |

Store these in `.env` (git-ignored) or use keychain references.
