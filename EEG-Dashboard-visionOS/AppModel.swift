// EEG-Dashboard-visionOS/AppModel.swift — visionOS only

import SwiftUI
import Combine

// MARK: - Shared channel types (visionOS copy; iOS defines these in AppModel.swift)
struct ChannelData: Identifiable {
    let id:      Int
    let name:    String
    let power:   Double
    let samples: [Double]
}

struct SpikeTrainData: Identifiable {
    let id           = UUID()
    let channelIndex: Int
    let spikeTimes:  [Double]
}

enum ImmersiveSpaceState {
    case closed
    case inTransition
    case open
}

@MainActor
@Observable
class AppModel {

    var seizureProbability:   Double = 0
    var detectionState:       DetectionState = .normal
    var isMonitoring          = false
    var immersiveSpaceOpen    = false
    var heartRate:            Double? = nil
    var eventLog:             [DetectionEvent] = []
    var probabilityHistory:   [Double] = []      // one sample per second, up to 120
    var heartRateHistory:     [Double] = []      // parallel heart-rate samples

    /// The pIctal score actually shown throughout the app — the Watch is the
    /// authoritative sensor, so its live score (surfaced in WatchCloudCard)
    /// wins whenever it's connected. Falls back to the local EEG simulation
    /// so the dashboard still animates when no Watch bridge is reachable.
    var displayProbability: Double {
        watchLiveProbability ?? seizureProbability
    }

    /// Same precedence as `displayProbability`: Watch first, then the
    /// phone/visionOS's own HealthKit read, then the local EEG-derived
    /// simulation already folded into `heartRate`.
    var displayHeartRate: Double? {
        watchLiveHeartRate.map(Double.init) ?? hkManager.heartRate ?? heartRate
    }

    /// Watch first, then HealthKit — there's no local HRV simulation fallback.
    var displayHRV: Double? {
        watchLiveHRV ?? hkManager.hrv
    }

    /// Which tier `displayHeartRate`/`displayHRV` are currently sourced from,
    /// for the "Watch" / "Live" / "Sim" badges on the dashboard vital cards.
    enum VitalSource { case watch, healthKit, simulated, unavailable }

    var heartRateSource: VitalSource {
        if watchLiveHeartRate != nil   { return .watch }
        if hkManager.heartRate != nil  { return .healthKit }
        if heartRate != nil            { return .simulated }
        return .unavailable
    }

    var hrvSource: VitalSource {
        if watchLiveHRV != nil  { return .watch }
        if hkManager.hrv != nil { return .healthKit }
        return .unavailable
    }

    // MARK: - Immersive space
    let immersiveSpaceID = "ImmersiveSpace"
    var immersiveSpaceState = ImmersiveSpaceState.closed
    var isImmersiveSpaceActive: Bool { immersiveSpaceState == .open }

    // MARK: - Interactivity
    /// Currently selected electrode index (nil = none)
    var selectedChannel: Int? = nil

    // MARK: - EEG live data
    /// 22-channel RMS activity levels [0…1]
    var channelActivity:   [Float]  = Array(repeating: 0,     count: 22)
    /// 22-channel delta spike trains (256 bool samples each)
    var spikeTrain:        [[Bool]] = Array(
        repeating: Array(repeating: false, count: 256), count: 22)
    /// Last 128 samples of raw waveform per channel (for detail panel)
    var channelWaveforms:  [[Float]] = Array(repeating: [], count: 22)

    // MARK: - Computed live-data views

    /// Channels currently spiking (based on last 16 samples)
    var liveSpikes: Set<Int> {
        Set(spikeTrain.enumerated().compactMap { i, spikes in
            spikes.suffix(16).contains(true) ? i : nil
        })
    }

    /// Fraction of spike-train samples that are active, per channel
    var spikeRates: [Float] {
        spikeTrain.map { spikes in
            Float(spikes.filter { $0 }.count) / Float(max(spikes.count, 1))
        }
    }

    /// Spike-train converted to time-stamped objects for SpikeTrainView
    var spikeTrains: [SpikeTrainData] {
        spikeTrain.enumerated().map { idx, spikes in
            let times = spikes.enumerated().compactMap { i, active in
                active ? Double(i) / 256.0 * 5.0 : nil   // 5-second window
            }
            return SpikeTrainData(channelIndex: idx, spikeTimes: times)
        }
    }

    // MARK: - DashboardView compatibility

    var detectionEvents: [DetectionEvent] { eventLog }

    var channelActivityData: [ChannelData] {
        channelActivity.enumerated().map { idx, power in
            ChannelData(id: idx,
                        name: "Ch\(idx + 1)",
                        power: Double(power) * 100,
                        samples: [])
        }
    }

    // MARK: - HealthKit (real data from paired iPhone / Apple Watch)
    let hkManager = VisionOSHealthKitManager()

    // MARK: - Watch bridge
    // Two independent paths relay the Watch's data, relayed through the
    // iPhone (WatchConnectivity itself can't reach visionOS): CloudKit works
    // on real devices and Simulator alike but needs a paid dev team + iCloud
    // sign-in; the localhost bridge needs neither but only connects when
    // both apps are Simulator processes on the same Mac. Whichever is
    // reachable drives these published properties.
    private let watchPuller = CloudKitWatchPuller()
    private let bridgeClient = WatchBridgeClient()
    private var isCloudBridgeConnected = false
    private var isLocalBridgeConnected = false
    var isWatchCloudConnected = false
    var watchLiveProbability:  Double? = nil
    var watchLiveHeartRate:    Int?    = nil
    var watchLiveHRV:          Double? = nil

    // Auto-activates monitoring the moment the Watch starts streaming, and
    // auto-stops it again once the stream goes quiet — but only if this app
    // was the one that started it; a user-initiated "Start EEG" is left alone.
    private var lastWatchLiveUpdateAt: Date? = nil
    private var monitoringAutoStartedByWatch = false
    private var watchWatchdogTask: Task<Void, Never>?
    private let watchIdleTimeout: TimeInterval = 6

    // MARK: - Internals
    private var model        = SeizureDetectionModel()
    private var eegSource    = EEGSimulator()
    private var preprocessor = EEGPreprocessor()
    private var timer:       AnyCancellable?

    // MARK: - Control

    func requestHealthKitAuthorization() {
        Task { await hkManager.requestAuthorization() }
    }

    func startWatchBridgeSync() {
        // CloudKit path
        watchPuller.onConnectionChange = { [weak self] connected in
            guard let self else { return }
            self.isCloudBridgeConnected = connected
            self.refreshBridgeConnectionState()
        }
        watchPuller.onLiveUpdate = { [weak self] probability, heartRate, hrv, _ in
            guard let self else { return }
            self.watchLiveProbability = probability
            self.watchLiveHeartRate   = heartRate
            self.watchLiveHRV         = hrv
            self.recordWatchLiveUpdate()
        }
        watchPuller.onNewEvent = { [weak self] event in
            self?.mergeWatchEvent(event)
        }
        watchPuller.start()
        startWatchWatchdog()

        // Localhost path (Simulator only — see WatchBridgeClient.swift)
        bridgeClient.onConnectionChange = { [weak self] connected in
            Task { @MainActor in
                guard let self else { return }
                self.isLocalBridgeConnected = connected
                self.refreshBridgeConnectionState()
            }
        }
        bridgeClient.onMessage = { [weak self] message in
            Task { @MainActor in
                guard let self else { return }
                switch message.kind {
                case .live:
                    self.watchLiveProbability = message.probability
                    self.watchLiveHeartRate   = message.heartRate
                    self.watchLiveHRV         = message.hrv
                    self.recordWatchLiveUpdate()
                case .event:
                    if let event = message.event { self.mergeWatchEvent(event) }
                }
            }
        }
        bridgeClient.start()
    }

    private func refreshBridgeConnectionState() {
        isWatchCloudConnected = isCloudBridgeConnected || isLocalBridgeConnected
    }

    private func mergeWatchEvent(_ event: DetectionEvent) {
        guard !eventLog.contains(where: { $0.id == event.id }) else { return }
        eventLog.insert(event, at: 0)
        eventLog.sort { $0.timestamp > $1.timestamp }
    }

    /// Called on every live push/poll from either bridge path. Auto-starts
    /// local monitoring the moment the Watch is heard from, so the dashboard
    /// comes alive without the user tapping "Start EEG" themselves.
    private func recordWatchLiveUpdate() {
        lastWatchLiveUpdateAt = Date()
        guard !isMonitoring else { return }
        monitoringAutoStartedByWatch = true
        startMonitoring()
    }

    /// Polls for the Watch stream going quiet and auto-stops monitoring —
    /// but only when this app is what auto-started it, so a manual
    /// "Start EEG" press is never overridden by the watchdog.
    private func startWatchWatchdog() {
        guard watchWatchdogTask == nil else { return }
        watchWatchdogTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard self.monitoringAutoStartedByWatch,
                      self.isMonitoring,
                      let last = self.lastWatchLiveUpdateAt,
                      Date().timeIntervalSince(last) > self.watchIdleTimeout
                else { continue }
                self.monitoringAutoStartedByWatch = false
                self.stopMonitoring()
            }
        }
    }

    func startMonitoring() {
        isMonitoring = true
        eegSource.startSimulation()

        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let window = self.eegSource.currentData
                guard !window.isEmpty, window[0].count >= 256 else { return }

                let floatWindow = window.map { $0.map { Float($0) } }
                self.updateActivity(floatWindow)
                self.updateSpikeTrain(floatWindow)

                // Store last 128 samples per channel for the waveform display
                self.channelWaveforms = floatWindow.map { Array($0.suffix(128)) }

                // Preprocess and predict
                do {
                    let processed = try self.preprocessor.preprocess(rawData: window)
                    let result    = try self.model.predict(input: processed)
                    self.seizureProbability = result.probability
                    self.detectionState     = result.state

                    // Prefer real HealthKit data; fall back to EEG-derived simulation
                    let avgActivity = self.channelActivity.reduce(0, +) / Float(max(self.channelActivity.count, 1))
                    let simHR = 62.0 + Double(avgActivity) * 55.0 + Double.random(in: -2...2)
                    let simHRV = max(5.0, 55.0 - Double(avgActivity) * 35.0 + Double.random(in: -2...2))
                    let realHR = self.hkManager.heartRate
                    self.heartRate = realHR ?? simHR

                    // Accumulate history (120-second window)
                    self.probabilityHistory.append(result.probability)
                    self.heartRateHistory.append(realHR ?? simHR)
                    _ = simHRV // available if needed for future HRV display
                    if self.probabilityHistory.count > 120 { self.probabilityHistory.removeFirst() }
                    if self.heartRateHistory.count > 120   { self.heartRateHistory.removeFirst() }

                    if result.state == .seizure {
                        self.eventLog.insert(
                            DetectionEvent(probability: result.probability,
                                           heartRate:  simHR,
                                           type: .alert,
                                           batteryLevel: nil), at: 0)
                    }
                } catch {
                    print("Preprocessing or prediction error: \(error)")
                }
            }
    }

    func startSimulation() {
        isMonitoring ? stopMonitoring() : startMonitoring()
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
        eegSource.stopSimulation()
        isMonitoring        = false
        seizureProbability  = 0
        heartRate           = nil
        channelActivity     = Array(repeating: 0,  count: 22)
        channelWaveforms    = Array(repeating: [], count: 22)
        selectedChannel     = nil
        probabilityHistory  = []
        heartRateHistory    = []
    }

    // MARK: - Private helpers

    private func updateActivity(_ data: [[Float]]) {
        channelActivity = data.map { ch in
            let rms = sqrt(ch.map { $0 * $0 }.reduce(0, +) / Float(ch.count))
            return min(rms * 1000, 1.0)
        }
    }

    private func updateSpikeTrain(_ data: [[Float]]) {
        spikeTrain = data.map { ch in
            var spikes = [Bool](repeating: false, count: 256)
            var last: Float = 0
            let step = max(ch.count / 256, 1)
            for i in 0..<256 {
                let v = ch[min(i * step, ch.count - 1)]
                spikes[i] = abs(v - last) > 50e-6
                last = v
            }
            return spikes
        }
    }
}
