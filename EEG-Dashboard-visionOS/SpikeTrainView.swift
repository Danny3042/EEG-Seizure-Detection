//
//  SpikeTrainView.swift
//  EEG-Dashboard-visionOS
//
//  Created by Daniel Ramzani on 21/04/2026.
//

import SwiftUI

/// Floating 22-channel raster plot window, delta spike visualisation
struct SpikeTrainView: View {
    @Environment(AppModel.self) var appModel
    
    let channelNames = [
        "Fp1", "Fp2", "F7", "F3", "Fz", "F4", "F8",
        "C3", "Cz", "C4",
        "T3", "T4", "T5", "T6",
        "P3", "Pz", "P4",
        "O1", "O2",
        "A1", "A2", "Ground"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Spike Train Activity")
                .font(.title2)
                .padding()
            
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(channelNames.enumerated()), id: \.offset) { index, name in
                        HStack(spacing: 8) {
                            Text(name)
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 60, alignment: .trailing)
                                .foregroundColor(.secondary)
                            
                            SpikeRasterRow(
                                spikes: getSpikes(for: index),
                                timeWindow: 5.0
                            )
                            .frame(height: 20)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
    }
    
    private func getSpikes(for channel: Int) -> [Double] {
        // Find spike train for this channel
        if let train = appModel.spikeTrains.first(where: { $0.channelIndex == channel }) {
            return train.spikeTimes
        }
        return []
    }
}

struct SpikeRasterRow: View {
    let spikes: [Double]
    let timeWindow: Double
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for spikeTime in spikes {
                    // Only show spikes within the time window
                    if spikeTime >= 0 && spikeTime <= timeWindow {
                        let x = (spikeTime / timeWindow) * size.width
                        
                        let path = Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        
                        context.stroke(
                            path,
                            with: .color(.green),
                            lineWidth: 2
                        )
                    }
                }
            }
        }
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    SpikeTrainView()
        .environment(AppModel())
}
