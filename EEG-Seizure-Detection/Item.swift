//
//  Item.swift
//  EEG-Seizure-Detection
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
