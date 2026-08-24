# EEG Seizure Detection

A multi-platform Apple ecosystem app that predicts seizure risk from EEG-derived and biometric signals, with real-time detection on the wrist, monitoring on the phone, and spatial visualization on Vision Pro.

## Targets

| Target | Platform | Role |
|---|---|---|
| `EEG-Seizure-Detection` | iOS | Dashboard, event history, journal, emergency contact alerts, settings |
| `SeizureDetection-Watch Watch App` | watchOS | **Primary sensor** — runs the on-wrist CoreML prediction, streams live data to iPhone |
| `EEG-Dashboard-visionOS` | visionOS | Spatial 3-D electrode map, probability timeline, HealthKit-backed vitals |

## Architecture

The Apple Watch is the authoritative sensor. It has the best hardware for this task — optical heart rate, accelerometer, gyroscope, and continuous skin contact — so seizure prediction runs there, not on the phone.

```
Watch sensors (HR, HRV, motion)
        │
        ▼
CoreML model (SeizureDetector.mlpackage) → pIctal probability
        │
        ├─ WatchConnectivity → iPhone (live gauge, event log, alerts)
        │
        ▼
HealthKit (shared store, synced via iCloud)
        │
        ▼
visionOS reads HR/HRV passively for spatial dashboard display
```

`HKWorkoutSession` keeps the Watch app alive in the background so monitoring doesn't stop when the wrist drops or the screen locks — without it, watchOS suspends the app within seconds.

### Cross-target file sharing

The project uses Xcode's `PBXFileSystemSynchronizedRootGroup`, so folders auto-join their primary target. Several files intentionally compile into **multiple** targets via membership exceptions in `project.pbxproj` (e.g. `DetectionEvent.swift`, `DetectionState.swift`, `WatchContentView.swift`). Any platform-specific API in those shared files must be guarded with `#if os(iOS)` / `#if os(watchOS)` / `#if os(visionOS)`.

## Features

**watchOS**
- Real-time pIctal ring + HR/HRV vitals
- Background monitoring via `HKWorkoutSession`
- Demo mode with four scripted risk scenarios (Low / Elevated / High / Escalating)
- Local notifications at 50% / 70% / 90% probability thresholds

**iOS**
- Tab bar: Dashboard, History, Journal, Settings
- Live Watch pIctal card with "Live" / "Last known" connectivity state
- Event detail view (timestamp, probability, heart rate, Watch battery)
- Emergency contact alert — pre-filled SMS prompt on high-risk detection
- Connectivity status distinguishing "paired" from "momentarily unreachable"
- Seizure journal with mood tagging

**visionOS**
- Interactive 3-D brain map — 22 tappable electrode orbs over an anatomical lobe reference, colour-coded by activity
- Spike arcs animate between co-firing electrodes; pulses when risk exceeds 70%
- Floating glass detail panel with per-channel waveform
- Probability timeline window (120 s rolling chart)
- Spatial event log and 22-channel spike-train raster, each in its own window
- HealthKit integration reads real HR/HRV from the shared store (synced from Watch via iCloud), badged "Live" vs. simulated

## Building

Open `EEG-Seizure-Detection.xcodeproj` in Xcode. Schemes:

```
EEG-Seizure-Detection              → iOS
SeizureDetection-Watch Watch App   → watchOS
EEG-Dashboard-visionOS             → visionOS
```

Command-line build example:

```bash
xcodebuild -project EEG-Seizure-Detection.xcodeproj \
  -scheme "EEG-Seizure-Detection" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  build
```

All three targets require HealthKit entitlements (already configured) and will prompt for HR/HRV read access on first launch.

## Model

`SeizureDetector.mlpackage` — CoreML model taking heart rate, HRV, and motion activity, producing a seizure probability (pIctal score). Loaded via `PredictionManager` / `SeizureDetectionModel` on both iOS and watchOS.
