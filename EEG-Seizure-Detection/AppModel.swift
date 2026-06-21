//
//  AppModel.swift
//  EEG-Dashboard-visionOS
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import Foundation
import Combine

/// @Observable shared state — probability, channel activity, spike trains
@Observable
class AppModel {
    var seizureProbability: Double = 0.0
    var channelActivity: [ChannelData] = []
    var spikeTrains: [SpikeTrainData] = []
    var detectionEvents: [DetectionEvent] = []
    var isImmersiveSpaceActive = false
    
    // Immersive space management
    enum ImmersiveSpaceState {
        case closed
        case open
    }
    
    let immersiveSpaceID = "ImmersiveSpace"
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    // EEG simulation
    private let simulator = EEGSimulator()
    private let preprocessor = EEGPreprocessor()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSimulation()
        generateInitialData()
    }
    
    private func setupSimulation() {
        // Observe simulator updates
        simulator.$currentData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.processEEGData(data)
            }
            .store(in: &cancellables)
    }
    
    func startSimulation() {
        simulator.startSimulation()
    }
    
    func stopSimulation() {
        simulator.stopSimulation()
    }
    
    private func processEEGData(_ data: [[Double]]) {
        guard !data.isEmpty else { return }
        
        // Update channel activity
        updateChannelActivity(from: data)
        
        // Generate spike trains
        updateSpikeTrains(from: data)
        
        // Run prediction
        updatePrediction(from: data)
    }
    
    private func updateChannelActivity(from data: [[Double]]) {
        channelActivity = data.enumerated().map { index, samples in
            let power = calculatePower(samples: samples)
            return ChannelData(
                id: index,
                name: "Ch\(index + 1)",
                power: power,
                samples: samples
            )
        }
    }
    
    private func updateSpikeTrains(from data: [[Double]]) {
        // Detect spikes in each channel
        var trains: [SpikeTrainData] = []
        
        for (channelIdx, samples) in data.enumerated() {
            let spikes = detectSpikes(in: samples)
            if !spikes.isEmpty {
                trains.append(SpikeTrainData(
                    channelIndex: channelIdx,
                    spikeTimes: spikes
                ))
            }
        }
        
        spikeTrains = trains
    }
    
    private func updatePrediction(from data: [[Double]]) {
        do {
            let preprocessed = try preprocessor.preprocess(rawData: data)
            let model = SeizureDetectionModel()
            let result = try model.predict(input: preprocessed)
            
            seizureProbability = result.probability
            
            // Add to event log if significant
            if result.state != .normal {
                let eventType: DetectionEvent.EventType
                switch result.state {
                case .normal:
                    return // Skip normal states
                case .warning:
                    eventType = .elevated
                case .seizure:
                    eventType = result.probability > 0.85 ? .emergency : .alert
                }
                
                let event = DetectionEvent(
                    probability: result.probability,
                    heartRate: 0.0,
                    type: eventType,
                    batteryLevel: nil
                )
                detectionEvents.insert(event, at: 0)
            }
        } catch {
            print("Prediction error: \(error)")
        }
    }
    
    private func calculatePower(samples: [Double]) -> Double {
        let sumSquared = samples.reduce(0.0) { $0 + $1 * $1 }
        return sqrt(sumSquared / Double(samples.count))
    }
    
    private func detectSpikes(in samples: [Double]) -> [Double] {
        var spikes: [Double] = []
        let threshold = 100.0 // Adjust based on data
        
        for (index, sample) in samples.enumerated() {
            if abs(sample) > threshold {
                spikes.append(Double(index) / 256.0) // Convert to seconds
            }
        }
        
        return spikes
    }
    
    private func generateInitialData() {
        // Generate 22 channels
        channelActivity = (0..<22).map { index in
            ChannelData(
                id: index,
                name: "Ch\(index + 1)",
                power: 0.0,
                samples: []
            )
        }
    }
}

// MARK: - Supporting Types

struct ChannelData: Identifiable {
    let id: Int
    let name: String
    let power: Double
    let samples: [Double]
}

struct SpikeTrainData: Identifiable {
    let id = UUID()
    let channelIndex: Int
    let spikeTimes: [Double]
}
