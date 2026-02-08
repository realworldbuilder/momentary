<p align="center">
  <img src="assets/logo.png" width="140" alt="Momentary logo">
</p>

<h1 align="center">Momentary</h1>

<p align="center">
  <strong>Start a workout on your watch. Log moments by voice. Turn training into insights and content.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS_18+_|_watchOS_11+-black?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
</p>

---

Momentary is a wrist-first workout notebook. Start a strength training session on your Apple Watch, record short voice "Moments" during the workout, and get AI-generated structured logs, social content, and training insights when the workout ends.

## How It Works

```
  Apple Watch                                iPhone
┌──────────────────────────┐           ┌─────────────────────────────────┐
│                          │  moments  │                                 │
│  Start → Record → Send  ────────▶  │  Receive → Transcribe → Store  │
│  workout   moments       │           │      WhisperKit (on-device)     │
│                          │           │                                 │
│  ◀──────────────────────────────────  │  End workout → AI processing   │
│       transcription text │           │      OpenAI API → structured    │
│       + haptic feedback  │           │      log + content + insights   │
└──────────────────────────┘           └─────────────────────────────────┘
```

## Features

| | Feature | Detail |
|---|---|---|
| 💪 | **Workout Sessions** | Start/end strength training sessions with elapsed timer |
| 🎙 | **Voice Moments** | Record short voice notes during your workout |
| 🧠 | **On-Device Transcription** | WhisperKit runs locally — no internet required for recording |
| 🤖 | **AI Workout Log** | OpenAI generates structured exercise logs from voice transcripts |
| 📱 | **Social Content** | Auto-generate Instagram captions, tweet threads, reel scripts |
| 💡 | **Training Insights** | Progress notes, form reminders, motivational stories |
| ❤️ | **HealthKit** | Workouts sync to Apple Health as strength training |
| ⌚ | **Watch-First UX** | Full workout lifecycle on Apple Watch with haptic feedback |
| 🔒 | **Privacy** | Audio transcribed on-device; only workout text sent to OpenAI |

## Architecture

```
Momentary/
├── Shared/
│   ├── ConnectivityConstants.swift       # IPC message keys
│   ├── Models.swift                      # All Codable data models
│   ├── WorkoutStore.swift                # Directory-based JSON persistence
│   └── HealthKitService.swift            # HKWorkoutSession lifecycle
├── Momentary/                            # iOS target
│   ├── MomentaryApp.swift
│   ├── WorkoutManager.swift              # Central orchestrator
│   ├── TranscriptionService.swift        # WhisperKit wrapper
│   ├── PhoneConnectivityManager.swift    # WCSession delegate
│   ├── PhoneAudioRecorderService.swift   # iPhone recording
│   ├── AIProcessingService.swift         # OpenAI API + Keychain
│   ├── AIPromptBuilder.swift             # Prompt construction
│   ├── AIProcessingPipeline.swift        # Orchestrator with offline queue
│   ├── Views/
│   │   ├── MainTabView.swift             # Tab-based root
│   │   ├── HomeView.swift                # Start + history
│   │   ├── ActiveWorkoutTab.swift        # Live workout mirror
│   │   ├── WorkoutDetailView.swift       # Post-workout detail
│   │   ├── InsightsTab.swift             # Cross-workout insights
│   │   └── SettingsView.swift            # OpenAI API key config
│   └── Models/openai_whisper-tiny/       # Bundled CoreML models
└── Momentary Watch App/                  # watchOS target
    ├── MomentaryWatchApp.swift
    ├── WatchWorkoutManager.swift         # Watch-side orchestrator
    ├── AudioRecorderService.swift        # Per-moment AVAudioRecorder
    ├── WatchConnectivityManager.swift    # File transfer + messaging
    ├── ExtendedSessionManager.swift      # WKExtendedRuntimeSession
    └── Views/
        ├── WatchRootView.swift           # NavigationStack root
        ├── WatchHomeView.swift           # Start workout + history
        ├── ActiveWorkoutView.swift       # Record moments + timer
        └── WorkoutSummaryView.swift      # Post-workout summary
```

## Quick Start

```bash
git clone https://github.com/your-username/momentary.git
open Momentary/Momentary.xcodeproj
```

### Requirements
- Xcode 16+
- iOS 18.0+ / watchOS 11.0+
- Apple Developer account (for device deployment)

### Setup
1. Open the project in Xcode
2. Select your signing team
3. Build and run on your devices
4. **OpenAI API Key**: Go to Settings (gear icon) in the app and enter your OpenAI API key
   - Required for AI-generated workout logs, content, and insights
   - Key is stored securely in the iOS Keychain
   - Without a key, workouts still record and transcribe — AI processing is skipped

SPM pulls [WhisperKit](https://github.com/argmaxinc/WhisperKit) `>=0.9.0` automatically. The Whisper Tiny model is bundled — no download step.

## Technical Details

| Area | Implementation |
|------|---------------|
| **Audio** | Linear PCM, 16kHz, 16-bit, mono — optimized for Whisper |
| **Transcription** | WhisperKit loaded async from bundle (`download: false`) |
| **AI** | OpenAI GPT-4o with JSON response format |
| **Storage** | Directory-per-workout: `Documents/workouts/<UUID>/session.json` |
| **Offline** | AI processing queued to `pending_ai_queue.json`, processed when online |
| **HealthKit** | `HKWorkoutSession` + `HKLiveWorkoutBuilder` on watchOS |
| **Connectivity** | `WCSession` file transfer with moment metadata |

## Privacy

Audio is transcribed on-device using WhisperKit. Only workout transcript text is sent to OpenAI for AI processing (when you provide an API key). No analytics, no tracking. Microphone and HealthKit are the only permissions requested.

## License

[MIT](LICENSE)
