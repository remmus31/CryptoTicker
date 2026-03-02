import SwiftUI
import Charts

/// 价格图表组件
struct PriceChartView: View {
    let coin: CryptoCoin
    let priceHistory: [PricePoint]
    let timeFrame: TimeFrame
    let onChartHover: (Bool) -> Void
    let onVisibleRangeChange: (Double, Double, Date, Date) -> Void
    
    @State private var visibleRange: ClosedRange<Double>? = nil
    
    private var minPrice: Double {
        priceHistory.map { $0.price }.min() ?? 0
    }
    
    private var maxPrice: Double {
        priceHistory.map { $0.price }.max() ?? 0
    }
    
    private var displayMinPrice: Double {
        visibleRange?.lowerBound ?? minPrice
    }
    
    private var displayMaxPrice: Double {
        visibleRange?.upperBound ?? maxPrice
    }
    
    private var startTime: Date {
        priceHistory.first?.timestamp ?? Date()
    }
    
    private var endTime: Date {
        priceHistory.last?.timestamp ?? Date()
    }
    
    private var chartColor: Color {
        guard let first = priceHistory.first?.price,
              let last = priceHistory.last?.price else {
            return Color(hex: coin.color)
        }
        return last >= first ? Color.green : Color.red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(coin.name) 价格走势")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if visibleRange != nil {
                    Button(action: { visibleRange = nil }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if priceHistory.isEmpty {
                emptyChartView
            } else {
                chartView
            }
            
            HStack {
                Text("$\(String(format: "%.0f", displayMinPrice)) - $\(String(format: "%.0f", displayMaxPrice))")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary.opacity(0.5))
                Spacer()
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.25))
        )
        .onHover { hovering in
            onChartHover(hovering)
        }
        .onChange(of: priceHistory) { _ in
            // 当数据变化时报告范围
            DispatchQueue.main.async {
                onVisibleRangeChange(minPrice, maxPrice, startTime, endTime)
            }
        }
        .onChange(of: coin) { _ in
            // 当币种变化时重置缩放范围
            visibleRange = nil
            DispatchQueue.main.async {
                onVisibleRangeChange(minPrice, maxPrice, startTime, endTime)
            }
        }
        .onChange(of: timeFrame) { _ in
            // 当时间框架变化时重置缩放范围
            visibleRange = nil
            DispatchQueue.main.async {
                onVisibleRangeChange(minPrice, maxPrice, startTime, endTime)
            }
        }
    }
    
    private var chartView: some View {
        Chart(priceHistory) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Price", point.price)
            )
            .foregroundStyle(chartColor)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel()
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .font(.system(size: 7))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { value in
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text("$\(formatCompactPrice(price))")
                            .foregroundStyle(Color.secondary.opacity(0.4))
                            .font(.system(size: 7))
                    }
                }
            }
        }
        .chartYScale(domain: displayMinPrice...displayMaxPrice)
        .frame(height: 100)
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 20))
                .foregroundColor(.secondary.opacity(0.3))
            Text("加载中...")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
    
    private func formatCompactPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "%.0fK", price / 1000)
        } else if price >= 1 {
            return String(format: "%.0f", price)
        } else {
            return String(format: "%.2f", price)
        }
    }
}

#Preview {
    let sampleData = (0..<60).map { i in
        PricePoint(
            timestamp: Date().addingTimeInterval(TimeInterval(-i * 60)),
            price: Double.random(in: 65000...70000)
        )
    }.reversed()
    
    return PriceChartView(
        coin: .bitcoin,
        priceHistory: Array(sampleData),
        timeFrame: .fifteenMin,
        onChartHover: { _ in },
        onVisibleRangeChange: { _, _, _, _ in }
    )
    .padding()
    .frame(width: 300)
    .background(Color(nsColor: .windowBackgroundColor))
}
