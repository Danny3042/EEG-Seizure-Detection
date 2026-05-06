//
//  DetectionState.swift
//  Shared — Tick ALL THREE targets in Xcode File Inspector:
//    ✓ EEG-Seizure-Detection (iOS)
//    ✓ SeizureDetection-Watch Watch App (watchOS)
//    ✓ EEG-Dashboard-visionOS (visionOS)
//
//  This enum must be available to all targets

import Foundation

/// Represents the current detection state
public enum DetectionState: String, Codable {
    case normal
    case warning
    case seizure
}
