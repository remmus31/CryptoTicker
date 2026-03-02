import SwiftUI
import Charts

struct CompactChartView: View {
    @ObservedObject var viewModel: CryptoViewModel
    @State private var isHovered = false
    
    private var data: [PricePoint] {
        viewModel.currentHistory
    }
    
    private var minPrice: Double {
        data.map { $0.price }.min() ?? 0
    }
    
    private var maxPrice: Double {
        data.map { $0.price }.max() ?? 1
    }
    
    private var chartColor: Color {
        guard let first = data.first?.price,
              let last = data.last?.price else { return .green }
        return last >= first ? Color.green : Color.red
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // 价格标签在左侧
            if let price = viewModel.currentPrice {
                VStack(alignment: .leading, spacing: 2) {
                    Text("$\(String(format: "%.0f", price.currentPrice))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text(price.formattedChange)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(price.isPositive ? .green : .red)
                }
            }
            
            // 图表在右侧
            if !data.isEmpty {
                Chart(data) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Price", point.price)
                    )
                    .foregroundStyle(chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: minPrice...maxPrice)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().scaleEffect(0.3)
            }
        }
        .padding(8)
        .frame(width: 360, height: 70)
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { isHovered = $0 }
        .onTapGesture {
            viewModel.exitCompactMode()
        }
    }
}
