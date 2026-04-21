//
//  EEGPreprocessor.swift
//  EEGSeizureDetection
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import Foundation
import Accelerate
import CoreML

/// Bandpass filter, CAR, artifact rejection, MLMultiArray builder
class EEGPreprocessor {
    
    // MARK: - Properties
    
    private let samplingRate: Double
    private let lowCutoff: Double
    private let highCutoff: Double
    
    // MARK: - Initialization
    
    init(samplingRate: Double = 256.0, lowCutoff: Double = 0.5, highCutoff: Double = 50.0) {
        self.samplingRate = samplingRate
        self.lowCutoff = lowCutoff
        self.highCutoff = highCutoff
    }
    
    // MARK: - Public Methods
    
    /// Preprocesses raw EEG data through the full pipeline
    /// - Parameter rawData: 2D array [channels][samples]
    /// - Returns: Preprocessed MLMultiArray ready for model input
    func preprocess(rawData: [[Double]]) throws -> MLMultiArray {
        // Step 1: Apply bandpass filter to each channel
        var filtered = try bandpassFilter(data: rawData)
        
        // Step 2: Apply Common Average Reference (CAR)
        filtered = applyCAR(data: filtered)
        
        // Step 3: Artifact rejection
        filtered = try rejectArtifacts(data: filtered)
        
        // Step 4: Convert to MLMultiArray
        return try buildMLMultiArray(from: filtered)
    }
    
    // MARK: - Private Methods
    
    /// Applies bandpass filter to remove frequencies outside the range of interest
    private func bandpassFilter(data: [[Double]]) throws -> [[Double]] {
        var filteredData: [[Double]] = []
        
        for channel in data {
            let filtered = applyButterworthBandpass(signal: channel)
            filteredData.append(filtered)
        }
        
        return filteredData
    }
    
    /// Applies Butterworth bandpass filter to a single channel
    private func applyButterworthBandpass(signal: [Double]) -> [Double] {
        // Simplified bandpass implementation
        // In production, use a proper DSP library or vDSP
        
        var result = signal
        
        // High-pass filter (remove low frequencies)
        result = highPassFilter(signal: result, cutoff: lowCutoff)
        
        // Low-pass filter (remove high frequencies)
        result = lowPassFilter(signal: result, cutoff: highCutoff)
        
        return result
    }
    
    /// Simple high-pass filter implementation
    private func highPassFilter(signal: [Double], cutoff: Double) -> [Double] {
        let alpha = cutoff / (cutoff + samplingRate)
        var filtered = [Double](repeating: 0.0, count: signal.count)
        filtered[0] = signal[0]
        
        for i in 1..<signal.count {
            filtered[i] = alpha * (filtered[i-1] + signal[i] - signal[i-1])
        }
        
        return filtered
    }
    
    /// Simple low-pass filter implementation
    private func lowPassFilter(signal: [Double], cutoff: Double) -> [Double] {
        let alpha = (2.0 * .pi * cutoff) / samplingRate
        var filtered = [Double](repeating: 0.0, count: signal.count)
        filtered[0] = signal[0]
        
        for i in 1..<signal.count {
            filtered[i] = filtered[i-1] + alpha * (signal[i] - filtered[i-1])
        }
        
        return filtered
    }
    
    /// Applies Common Average Reference (CAR) to reduce common noise
    private func applyCAR(data: [[Double]]) -> [[Double]] {
        guard !data.isEmpty else { return data }
        
        let numChannels = data.count
        let numSamples = data[0].count
        var carData: [[Double]] = Array(repeating: Array(repeating: 0.0, count: numSamples), count: numChannels)
        
        // Calculate average across all channels for each time point
        for sampleIdx in 0..<numSamples {
            var sum = 0.0
            for channelIdx in 0..<numChannels {
                sum += data[channelIdx][sampleIdx]
            }
            let average = sum / Double(numChannels)
            
            // Subtract average from each channel
            for channelIdx in 0..<numChannels {
                carData[channelIdx][sampleIdx] = data[channelIdx][sampleIdx] - average
            }
        }
        
        return carData
    }
    
    /// Rejects artifacts based on amplitude threshold
    private func rejectArtifacts(data: [[Double]]) throws -> [[Double]] {
        let threshold = 200.0 // microvolts, adjust as needed
        var cleanData = data
        
        for (channelIdx, channel) in data.enumerated() {
            for (sampleIdx, sample) in channel.enumerated() {
                if abs(sample) > threshold {
                    // Replace artifact with interpolated value or zero
                    cleanData[channelIdx][sampleIdx] = 0.0
                }
            }
        }
        
        return cleanData
    }
    
    /// Builds MLMultiArray from preprocessed data
    private func buildMLMultiArray(from data: [[Double]]) throws -> MLMultiArray {
        let numChannels = data.count
        let numSamples = data.isEmpty ? 0 : data[0].count
        
        // Create MLMultiArray with shape [1, channels, samples]
        let shape = [1, numChannels, numSamples] as [NSNumber]
        let multiArray = try MLMultiArray(shape: shape, dataType: .double)
        
        // Fill the array
        for channelIdx in 0..<numChannels {
            for sampleIdx in 0..<numSamples {
                let index = [0, channelIdx, sampleIdx] as [NSNumber]
                multiArray[index] = NSNumber(value: data[channelIdx][sampleIdx])
            }
        }
        
        return multiArray
    }
}
