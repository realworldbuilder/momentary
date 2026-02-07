<p align="center">
  <img src="assets/logo.png" width="140" alt="WristAssist logo">
</p>

<h1 align="center">WristAssist</h1>

<p align="center">
  <strong>Voice notes from your wrist. Transcribed on-device. Never leaves your phone.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS_17+_|_watchOS_10+-black?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
  <a href="https://apps.apple.com/us/app/wristassist/id6758561450"><img src="https://img.shields.io/badge/App_Store-Available-0D96F6?style=flat-square&logo=apple&logoColor=white" alt="App Store"></a>
</p>

<p align="center">
  <a href="https://apps.apple.com/us/app/wristassist/id6758561450">Download</a> ·
  <a href="https://realworldbuilder.github.io/wristassist/">Website</a> ·
  <a href="https://realworldbuilder.github.io/wristassist/privacy.html">Privacy</a> ·
  <a href="https://realworldbuilder.github.io/wristassist/support.html">Support</a>
</p>

---

Record a voice note on your Apple Watch or iPhone and get an instant transcription — powered by [WhisperKit](https://github.com/argmaxinc/WhisperKit), running entirely on-device. No cloud. No accounts. No data ever leaves your phone.

## How It Works

```
  Apple Watch                                iPhone
┌──────────────────────────┐           ┌─────────────────────────────────┐
│                          │   .wav    │                                 │
│  Tap → Record → Transfer ────────▶  │  Receive → Transcribe → Store  │
│                          │           │      WhisperKit (CoreML)        │
│  ◀──────────────────────────────────  │                                 │
│       transcription text │           │  Also records directly on       │
│                          │           │  iPhone with one tap             │
└──────────────────────────┘           └─────────────────────────────────┘
```

16kHz mono PCM on watch → `WCSession.transferFile()` → Whisper inference on phone → text sent back via `sendMessage()`

## Features

| | Feature | Detail |
|---|---|---|
| 🎙 | **One-Tap Recording** | Start from Apple Watch — no phone needed |
| 📱 | **iPhone Recording** | Record directly with the floating mic button |
| 🧠 | **On-Device Transcription** | WhisperKit runs locally — no internet required |
| 🔒 | **100% Private** | No accounts, no cloud, no analytics |
| 📡 | **Seamless Transfer** | Watch → iPhone over Bluetooth / Wi-Fi |
| 📋 | **Manage Notes** | Copy, share, multi-select, delete |
| ⌚ | **Always-On Display** | Recording status visible at a glance |

## Architecture

```
WristAssist/
├── Shared/
│   └── ConnectivityConstants.swift       # IPC message keys
├── WristAssist/                          # iOS target
│   ├── WristAssistApp.swift
│   ├── ContentView.swift                 # Transcription list UI
│   ├── TranscriptionService.swift        # WhisperKit wrapper
│   ├── PhoneAudioRecorderService.swift   # iPhone recording
│   ├── PhoneConnectivityManager.swift    # WCSession delegate + persistence
│   └── Models/openai_whisper-tiny/       # Bundled CoreML models
│       ├── AudioEncoder.mlmodelc
│       ├── MelSpectrogram.mlmodelc
│       └── TextDecoder.mlmodelc
└── WristAssist Watch App/                # watchOS target
    ├── WristAssistWatchApp.swift
    ├── RecordingView.swift               # Record button + status
    ├── AudioRecorderService.swift        # AVAudioRecorder 16kHz/16-bit/mono
    ├── WatchConnectivityManager.swift    # File transfer + messaging
    └── ExtendedSessionManager.swift      # WKExtendedRuntimeSession
```

## Quick Start

```bash
git clone https://github.com/realworldbuilder/wristassist.git
open WristAssist/WristAssist.xcodeproj
```

SPM pulls [WhisperKit](https://github.com/argmaxinc/WhisperKit) `>=0.9.0` automatically. The Whisper Tiny model is bundled — no download step.

## Forking & Setup

**No API keys needed** — the app runs entirely on-device with no external services.

If you fork this repo, you'll need to update Apple-specific signing to use your own team:

1. **Change your Apple team ID** — replace the team ID in `ExportOptions.plist` and your Xcode project signing settings with your own Apple Developer team ID
2. **TestFlight deployment** — run `Scripts/setup_testflight.sh` to configure your App Store Connect API credentials. They're stored locally at `~/.wristassist_env` and never committed to the repo
3. **Build & run** — open the Xcode project, select your signing team, and build to your devices

## Technical Details

| Area | Implementation |
|------|---------------|
| **Audio** | Linear PCM, 16kHz, 16-bit, mono — optimized for Whisper |
| **Model** | Loaded async from bundle on first launch (`download: false`) |
| **Storage** | `Documents/transcriptions.json`, Codable |
| **Threading** | `@MainActor`, ML inference runs async |
| **Watch Runtime** | `WKExtendedRuntimeSession` keeps watch awake during transfer |
| **Connectivity** | `sendMessage()` when reachable, `transferUserInfo()` fallback, 60s timeout |

## Privacy

WristAssist collects **zero data**. No analytics, no tracking, no network calls. Microphone access is the only permission requested. Audio is processed locally and transcriptions are stored on your device.

Read the full [privacy policy](https://realworldbuilder.github.io/wristassist/privacy.html).

## License

[MIT](LICENSE)
