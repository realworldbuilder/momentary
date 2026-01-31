# wristassist

voice notes on your apple watch. transcribes on-device with [whisperkit](https://github.com/argmaxinc/WhisperKit). no cloud. no network. your words stay on your phone.

## how it works

```
watch                                    phone
┌────────────────────────────┐          ┌──────────────────────────────────┐
│                            │          │                                  │
│  RecordingView             │  .wav    │  ContentView                     │
│  AudioRecorderService ─────────────▶  PhoneConnectivityManager          │
│  ExtendedSessionManager    │          │    └─ TranscriptionService       │
│  WatchConnectivityManager ◀────────────       └─ WhisperKit (CoreML)    │
│                            │  text    │                                  │
└────────────────────────────┘          └──────────────────────────────────┘
```

record 16kHz mono pcm on watch → `WCSession.transferFile()` → whisper inference on phone → transcription back via `sendMessage()` or `transferUserInfo()` fallback

## structure

```
WristAssist/
├── Shared/
│   └── ConnectivityConstants.swift       # ipc message keys
├── WristAssist/                          # ios target
│   ├── WristAssistApp.swift
│   ├── ContentView.swift                 # transcription list ui
│   ├── TranscriptionService.swift        # whisperkit wrapper
│   ├── PhoneConnectivityManager.swift    # wcsession delegate, persistence
│   └── Models/openai_whisper-tiny/       # bundled coreml models
│       ├── AudioEncoder.mlmodelc
│       ├── MelSpectrogram.mlmodelc
│       └── TextDecoder.mlmodelc
└── WristAssist Watch App/                # watchos target
    ├── WristAssistWatchApp.swift
    ├── RecordingView.swift               # record button + status
    ├── AudioRecorderService.swift        # AVAudioRecorder 16kHz/16-bit/mono
    ├── WatchConnectivityManager.swift    # file transfer + messaging
    └── ExtendedSessionManager.swift      # WKExtendedRuntimeSession
```

## setup

```bash
git clone https://github.com/realworldbuilder/wristassist.git
open WristAssist/WristAssist.xcodeproj
```

spm pulls [whisperkit](https://github.com/argmaxinc/WhisperKit) `>=0.9.0` automatically. whisper tiny model is bundled — no download step.

ios 17+ / watchos 10+

## details

- **audio** — linear pcm, 16kHz, 16-bit, mono. optimized for whisper input
- **model** — loaded async from bundle on first launch. no network fetch (`download: false`)
- **storage** — `Documents/transcriptions.json`, codable
- **threading** — `@MainActor` everywhere, ml inference runs async
- **watch runtime** — `WKExtendedRuntimeSession` keeps watch awake during transfer
- **connectivity** — `sendMessage()` when reachable, `transferUserInfo()` fallback, 60s timeout

## license

[mit](LICENSE)
