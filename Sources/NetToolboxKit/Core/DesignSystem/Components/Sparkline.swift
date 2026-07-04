import SwiftUI

/// A tiny line chart for a series of values (e.g. ping latencies), drawn
/// with a `Path` so it needs no charting dependency.
struct Sparkline: View {
    @Environment(\.theme) private var theme

    let values: [Double]
    var height: CGFloat = 60

    var body: some View {
        GeometryReader { geometry in
            let maxValue = values.max() ?? 1
            let minValue = values.min() ?? 0
            let range = max(maxValue - minValue, 0.001)
            let stepX = values.count > 1 ? geometry.size.width / CGFloat(values.count - 1) : 0

            ZStack {
                Path { path in
                    guard values.count > 1 else { return }
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height * (1 - CGFloat((value - minValue) / range))
                        let point = CGPoint(x: x, y: y)
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                }
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
        }
        .frame(height: height)
    }
}
