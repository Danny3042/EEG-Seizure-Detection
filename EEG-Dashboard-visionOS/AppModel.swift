// EEG-Dashboard-visionOS/AppModel.swift — visionOS only

import SwiftUI
import Combine

enum ImmersiveSpaceState {
    case closed
    case inTransition
    case open
}

@MainActor
@Observable
class AppModel {

    var seizureProbability: Float  = 0
    var detectionState:     DetectionState = .normal
    var isMonitoring        = false
    var immersiveSpaceOpen  = false
    var heartRate:          Double? = nil
    var eventLog:           [DetectionEvent] = []

    // Immersive space properties
    let immersiveSpaceID = "ImmersiveSpace"
    var immersiveSpaceState = ImmersiveSpaceState.closed
    var isImmersiveSpaceActive: Bool {
        immersiveSpaceState == .open
    }
    
    // Computed property for DashboardView compatibility
    var detectionEvents: [DetectionEvent] {
        eventLog
    }

    // 22-channel live buffers
    var channelActivity: [Float] = Array(repeating: 0, count: 22)
    var spikeTrain: [[Bool]]   = Array(
        repeating: Array(repeating: false, count: 256), count: 22)

    private var model      = SeizureDetectionModel()
    private var eegSource  = EEGSimulator()
    private var preprocessor = EEGPreprocessor()
    private var timer:       AnyCancellable?

    func startMonitoring() {
        isMonitoring = true
        eegSource.startSimulation()
        
        // Poll the simulator's currentData periodically
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let window = self.eegSource.currentData
                guard !window.isEmpty, window[0].count >= 256 else { return }
                
                // Convert to [[Float]] for compatibility with existing methods
                let floatWindow = window.map { $0.map { Float($0) } }
                self.updateActivity(floatWindow)
                self.updateSpikeTrain(floatWindow)
                
                // Preprocess and predict
                do {
                    let processed = try self.preprocessor.preprocess(rawData: window)
                    let result = try self.model.predict(input: processed)
                    self.seizureProbability = Float(result.probability)
                    self.detectionState     = result.state
                    if result.state == .seizure {
                        self.eventLog.insert(
                            DetectionEvent(probability: Double(result.probability),
                                            heartRate: self.heartRate ?? 0,
                                            type: .alert), at: 0)
                    }
                } catch {
                    print("Preprocessing or prediction error: \(error)")
                }
            }
    }
    
    func startSimulation() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
        eegSource.stopSimulation()
        isMonitoring = false
        seizureProbability = 0
        channelActivity    = Array(repeating: 0, count: 22)
    }

    private func updateActivity(_ data: [[Float]]) {
        channelActivity = data.map { ch in
            let rms = sqrt(ch.map { $0*$0 }.reduce(0,+) / Float(ch.count))
            return min(rms * 1000, 1.0)
        }
    }

    private func updateSpikeTrain(_ data: [[Float]]) {
        spikeTrain = data.map { ch in
            var spikes = [Bool](repeating: false, count: 256)
            var last: Float = 0
            let step = ch.count / 256
            for i in 0..<256 {
                let v = ch[i * step]
                spikes[i] = abs(v - last) > 50e-6
                last = v
            }
            return spikes
        }
    }
}
