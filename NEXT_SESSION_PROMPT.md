# Next Session: Fix Watch ↔ Phone Workout Sync

## The Problem
Active workouts don't stay in sync between the Apple Watch and iPhone. Starting a workout on one device doesn't reliably reflect on the other, and moments recorded on the watch may not land in the phone's workout session.

## Root Causes (in priority order)

### 1. Workout ID Mismatch
When the watch starts a workout, `WatchWorkoutManager.startWorkout()` generates a new UUID and sends a `.start` command to the phone. The phone's callback creates a `WorkoutSession` using the watch's `message.workoutID` — that part is fine. But when the **phone** starts first, the watch receives the `.start` command yet doesn't fully enter active workout state. The watch's `WatchWorkoutManager` doesn't adopt the phone's workout ID or show an active workout UI.

### 2. Fire-and-Forget Messaging
All messages use `sendMessage()` with `replyHandler: nil` and fall back to `transferUserInfo()`. No acknowledgment, no retry, no way to know if the other device received the command.

### 3. No State Reconciliation
If connectivity drops mid-workout and comes back, neither device checks whether they agree on workout state. The watch could show "active" while the phone thinks it's idle, or vice versa.

### 4. Stop Race Condition
`WorkoutManager.endWorkout()` sets `activeSession = nil` immediately, then sends the stop message. If a watch moment arrives between those two lines (or is already in flight), the phone drops it because `activeSession` is nil in `addMoment()`.

## Architecture Overview

```
┌─────────────────────────┐         ┌──────────────────────────┐
│     iPhone (iOS)        │         │    Apple Watch (watchOS)  │
│                         │         │                           │
│  WorkoutManager         │◄──WC──►│  WatchWorkoutManager      │
│    ├─ activeSession     │         │    ├─ isWorkoutActive     │
│    ├─ workoutStore      │         │    ├─ currentWorkoutID    │
│    ├─ transcriptionSvc  │         │    ├─ recorder            │
│    └─ connectivityMgr   │         │    └─ connectivity        │
│                         │         │                           │
│  PhoneConnectivityMgr   │         │  WatchConnectivityMgr     │
│    WCSessionDelegate    │         │    WCSessionDelegate      │
└─────────────────────────┘         └──────────────────────────┘
```

**Key files:**
- `Momentary/Momentary/WorkoutManager.swift` — phone-side workout state & moment handling
- `Momentary/Momentary/PhoneConnectivityManager.swift` — phone WCSession delegate
- `Momentary/Momentary Watch App/WatchWorkoutManager.swift` — watch-side workout state
- `Momentary/Momentary Watch App/WatchConnectivityManager.swift` — watch WCSession delegate
- `Shared/ConnectivityConstants.swift` — message keys
- `Shared/Models.swift` — `WorkoutMessage`, `WorkoutCommand`, `WorkoutSession`, `Moment`

**Message protocol:** `WorkoutMessage` with commands `.start`, `.stop`, `.momentRecorded`, `.momentTranscribed`. Serialized to dictionary via `toDictionary()` / `from(dictionary:)`.

**Audio flow:** Watch records → `WCSession.transferFile()` with metadata (momentID, workoutID) → Phone receives in `didReceive file:` → transcribes via OpenAI Whisper API → sends `.momentTranscribed` back to watch.

## Suggested Fix Approach

1. **Use a single workout ID**: Whichever device starts first generates the UUID. The other device adopts it when it receives the `.start` command. Both sides should fully enter active workout state upon receiving a remote `.start`.

2. **Add applicationContext sync**: Use `WCSession.updateApplicationContext()` to broadcast current workout state (`{workoutID: UUID?, isActive: bool}`). This survives app restarts and connectivity drops. Check it in `activationDidCompleteWith` and `didReceiveApplicationContext`.

3. **Don't nil out activeSession on stop until moments drain**: Either queue the stop or keep the session around briefly to catch in-flight moments.

4. **Add replyHandler to critical messages**: At minimum for `.start` and `.stop` so the sender knows the other side received it.

## Project Details
- iOS: `com.whussey.momentary` / watchOS: `com.whussey.momentary.watchkitapp`
- Xcode project: `Momentary/Momentary.xcodeproj`
- Current build number: 7
- Transcription: OpenAI Whisper API (no local model)
- AI processing: OpenAI GPT-4o
- API key: built-in via `APIKeyProvider.swift` (XOR-obfuscated)
- To rebuild for TestFlight: `xcodebuild archive -scheme Momentary -destination 'generic/platform=iOS' -archivePath build/Momentary.xcarchive` then export with `-allowProvisioningUpdates`
