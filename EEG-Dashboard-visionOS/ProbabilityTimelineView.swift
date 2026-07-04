//
//  ProbabilityTimelineView.swift
//  EEG-Dashboard-visionOS
//
//  Floating window showing the rolling 120-second pIctal history as a
//  filled area chart with colour-coded threshold bands.

import SwiftUI

struct ProbabilityTimelineView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerRow
            timelineCanvas
            HStack {
                thresholdLegend
                Spacer()
                statsRow
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 260)
        .navigationTitle("Probability Timeline")
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Seizure Probability Timeline")
                    .font(.title2.bold())
                Text(appModel.probabilityHistory.isEmpty
                     ? "Start EEG to begin recording"
                     : "Last \(appModel.probabilityHistory.count) seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f%%", appModel.seizureProbability * 100))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(probColor(appModel.seizureProbability))
                    .contentTransition(.numericText())
                Text(probLabel(appModel.seizureProbability))
                    .font(.caption.bold())
                    .foregroundStyle(probColor(appModel.seizureProbability))
            }
        }
    }

    // MARK: - Canvas

    private var timelineCanvas: some View {
        Canvas { ctx, size in
            // Background grid lines + threshold bands
            drawGrid(ctx: ctx, size: size)

            let history = appModel.probabilityHistory
            guard history.count > 1 else { return }

            let step = size.width / CGFloat(history.count - 1)
            func pt(_ i: Int, _ v: Double) -> CGPoint {
                CGPoint(x: CGFloat(i) * step,
                        y: size.height - CGFloat(v) * size.height)
            }

            // Filled area below curve
            var fill = Path()
            fill.move(to: CGPoint(x: 0, y: size.height))
            for (i, v) in history.enumerated() { fill.addLine(to: pt(i, v)) }
            fill.addLine(to: CGPoint(x: CGFloat(history.count - 1) * step, y: size.height))
            fill.closeSubpath()
            ctx.fill(fill, with: .color(.cyan.opacity(0.12)))

            // Line
            var line = Path()
            for (i, v) in history.enumerated() {
                let p = pt(i, v)
                i == 0 ? line.move(to: p) : line.addLine(to: p)
            }
            ctx.stroke(line, with: .color(.cyan), lineWidth: 2)

            // Current-value dot
            if let last = history.last {
                let x = CGFloat(history.count - 1) * step
                let y = size.height - CGFloat(last) * size.height
                let dot = Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
                ctx.fill(dot, with: .color(probColor(last)))
            }
        }
        .frame(height: 130)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        let rules: [(Double, Color, [CGFloat])] = [
            (0.25, .white.opacity(0.06), [2, 4]),
            (0.50, .orange.opacity(0.45), [6, 3]),
            (0.70, .red.opacity(0.45),    [6, 3]),
            (0.90, .white.opacity(0.06), [2, 4]),
        ]
        for (pct, color, dash) in rules {
            let y = size.height - CGFloat(pct) * size.height
            var g = Path()
            g.move(to: CGPoint(x: 0, y: y))
            g.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(g, with: .color(color),
                       style: StrokeStyle(lineWidth: 1, dash: dash))
        }
    }

    // MARK: - Legend / stats

    private var thresholdLegend: some View {
        HStack(spacing: 16) {
            legendItem(.cyan,   "pIctal")
            legendItem(.orange, "50% elevated")
            legendItem(.red,    "70% high-risk")
        }
    }

    private var statsRow: some View {
        let h = appModel.probabilityHistory
        let avg  = h.isEmpty ? 0.0 : h.reduce(0, +) / Double(h.count)
        let peak = h.max() ?? 0.0
        return HStack(spacing: 20) {
            statChip(label: "Avg",  value: String(format: "%.0f%%", avg  * 100))
            statChip(label: "Peak", value: String(format: "%.0f%%", peak * 100))
        }
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(color).frame(width: 14, height: 2)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func statChip(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.bold())
        }
    }

    private func probColor(_ p: Double) -> Color {
        p >= 0.7 ? .red : p >= 0.5 ? .orange : .green
    }

    private func probLabel(_ p: Double) -> String {
        p >= 0.7 ? "High Risk" : p >= 0.5 ? "Elevated" : "Normal"
    }
}

#Preview(windowStyle: .automatic) {
    ProbabilityTimelineView()
        .environment(AppModel())
}
