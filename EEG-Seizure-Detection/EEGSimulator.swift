//
//  EEGSimulator.swift
//  EEGSeizureDetection
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import Foundation
import Combine

/// Simulated EEG + ictal burst generator, 256 Hz timer
class EEGSimulator: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isSimulating = false
    @Published var currentData: [[Double]] = []
    
    private var timer: Timer?
    private let samplingRate = 256.0 // Hz
    private let numberOfChannels = 22 // Standard EEG channel count
    private let windowSize = 256 // 1 second of data
    
    private var timeStep: Double = 0.0
    private var burstProbability: Double = 0.05 // 5% chance of ictal burst
    
    // MARK: - Public Methods
    
    /// Starts the EEG simulation
    func startSimulation() {
        guard !isSimulating else { return }
        
        isSimulating = true
        timeStep = 0.0
        
        // Create timer that fires at 256 Hz (every ~3.9ms)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / samplingRate, repeats: true) { [weak self] _ in
            self?.generateSample()
        }
    }
    
    /// Stops the EEG simulation
    func stopSimulation() {
        isSimulating = false
        timer?.invalidate()
        timer = nil
    }
    
    /// Generates a single sample across all channels
    private func generateSample() {
        var samples: [Double] = []
        
        let isIctalBurst = Double.random(in: 0...1) < burstProbability
        
        for channel in 0..<numberOfChannels {
            let sample = generateChannelSample(channel: channel, isIctal: isIctalBurst)
            samples.append(sample)
        }
        
        // Add to current data window
        if currentData.isEmpty {
            currentData = Array(repeating: [], count: numberOfChannels)
        }
        
        for (idx, sample) in samples.enumerated() {
            currentData[idx].append(sample)
            
            // Keep only the last windowSize samples
            if currentData[idx].count > windowSize {
                currentData[idx].removeFirst()
            }
        }
        
        timeStep += 1.0 / samplingRate
    }
    
    /// Generates a sample for a specific channel
    private func generateChannelSample(channel: Int, isIctal: Bool) -> Double {
        let t = timeStep
        
        // Base EEG frequencies (in Hz)
        let delta = sin(2 * .pi * 2.0 * t) * 50.0  // 1-4 Hz
        let theta = sin(2 * .pi * 6.0 * t) * 30.0  // 4-8 Hz
        let alpha = sin(2 * .pi * 10.0 * t) * 40.0 // 8-13 Hz
        let beta = sin(2 * .pi * 20.0 * t) * 20.0  // 13-30 Hz
        let gamma = sin(2 * .pi * 40.0 * t) * 10.0 // 30-100 Hz
        
        // Combine frequencies
        var signal = delta + theta + alpha + beta + gamma
        
        // Add noise
        signal += Double.random(in: -10...10)
        
        // Add ictal burst if flagged
        if isIctal {
            let burstAmplitude = 150.0
            let burstFrequency = 5.0 // 5 Hz spike-wave
            signal += sin(2 * .pi * burstFrequency * t) * burstAmplitude
        }
        
        // Add channel-specific variation
        signal *= (1.0 + Double(channel) * 0.05)
        
        return signal
    }
    
    /// Generates a complete window of data
    func generateWindow() -> [[Double]] {
        var windowData: [[Double]] = Array(repeating: [], count: numberOfChannels)
        
        let startTime = timeStep
        
        for sample in 0..<windowSize {
            let t = startTime + Double(sample) / samplingRate
            let isIctal = Double.random(in: 0...1) < burstProbability
            
            for channel in 0..<numberOfChannels {
                let value = generateChannelSample(channel: channel, isIctal: isIctal)
                windowData[channel].append(value)
            }
        }
        
        return windowData
    }
}
