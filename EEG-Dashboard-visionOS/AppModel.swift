//
//  AppModel.swift
//  EEG-Seizure-Detection
//
//  Created by Daniel Ramzani on 21/04/2026.
//


// EEG-Dashboard-visionOS/AppModel.swift — visionOS only

import SwiftUI
import Combine

@MainActor
class AppModel: ObservableObject {

    @Published var seizureProbability: Float  = 0
    @Published var detectionState:     DetectionState = .idle
    @Published var isMonitoring        = false
    @Published var immersiveSpaceOpen  = false
    @Published var heartRate:          Double? = nil
    @Published var eventLog:           [DetectionEvent] = []

    // 22-channel live buffers
    @Published var channelActivity: [Float] = Array(repeating: 0, count: 22)
    @Published var spikeTrain: [[Bool]]   = Array(
        repeating: Array(repeating: false, count: 256), count: 22)

    private var model      = SeizureDetectionModel()
    private var eegSource  = EEGSimulator()
    private var timer:       AnyCancellable?

    func startMonitoring() {
        isMonitoring = true
        eegSource.start { [weak self] window in
            guard let self, let processed = EEGPreprocessor.process(window)
            else { return }
            self.updateActivity(processed)
            self.updateSpikeTrain(processed)
            if let result = self.model.predict(eegWindow: processed) {
                self.seizureProbability = result.probability
                self.detectionState     = result.state
                if result.state == .alert {
                    self.eventLog.insert(
                        DetectionEvent(probability: Double(result.probability),
                                        heartRate: self.heartRate ?? 0,
                                        type: .alert), at: 0)
                }
            }
        }
    }

    func stopMonitoring() {
        eegSource.stop(); isMonitoring = false
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