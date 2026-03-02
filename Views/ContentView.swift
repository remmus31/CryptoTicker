import SwiftUI
import AppKit

// 全局变量存储 panel 引用
var sharedPanel: NSPanel?

struct AppSettings {
    static let updateIntervals: [Int] = [5, 10, 15, 30, 60]
    static var priceRefreshInterval: TimeInterval = 10
    static var historyRefreshInterval: TimeInterval = 30
}

struct ContentView: View {
    @StateObject private var viewModel = CryptoViewModel()
    @State private var selectedInterval: Int = 10
    
    @State private var chartMinPrice: Double = 0
    @State private var chartMaxPrice: Double = 1
    @State private var chartStartTime: Date = Date()
    @State private var chartEndTime: Date = Date()
    @State private var isHovering = false
    
    var body: some View {
        Group {
            if viewModel.isCompactMode {
                CompactChartView(viewModel: viewModel)
            } else {
                FullDashboardView(
                    viewModel: viewModel,
                    selectedInterval: $selectedInterval,
                    chartMinPrice: $chartMinPrice,
                    chartMaxPrice: $chartMaxPrice,
                    chartStartTime: $chartStartTime,
                    chartEndTime: $chartEndTime,
                    isHovering: $isHovering
                )
            }
        }
        .onAppear {
            viewModel.startAutoRefresh()
            startMouseTracking()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .onChange(of: selectedInterval) { newValue in
            AppSettings.priceRefreshInterval = TimeInterval(newValue)
            AppSettings.historyRefreshInterval = TimeInterval(newValue * 3)
            viewModel.restartTimers()
        }
    }
    
    private func startMouseTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard let panel = sharedPanel else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            let windowFrame = panel.frame
            
            let isInside = mouseLocation.x >= windowFrame.minX && 
                          mouseLocation.x <= windowFrame.maxX &&
                          mouseLocation.y >= windowFrame.minY && 
                          mouseLocation.y <= windowFrame.maxY
            
            DispatchQueue.main.async {
                self.isHovering = isInside
            }
        }
    }
}

struct FullDashboardView: View {
    @ObservedObject var viewModel: CryptoViewModel
    @Binding var selectedInterval: Int
    @Binding var chartMinPrice: Double
    @Binding var chartMaxPrice: Double
    @Binding var chartStartTime: Date
    @Binding var chartEndTime: Date
    @Binding var isHovering: Bool
    
    private let expandedWidth: CGFloat = 380
    private let expandedHeight: CGFloat = 520
    private let compactWidth: CGFloat = 340
    private let compactHeight: CGFloat = 420
    
    var body: some View {
        VStack(spacing: 8) {
            headerView
            coinCardsView
            
            TimeFrameSelectorView(
                selectedTimeFrame: $viewModel.selectedTimeFrame
            ) { timeFrame in
                viewModel.selectTimeFrame(timeFrame)
            }
            
            PriceChartView(
                coin: viewModel.selectedCoin,
                priceHistory: viewModel.currentHistory,
                timeFrame: viewModel.selectedTimeFrame,
                onChartHover: { _ in },
                onVisibleRangeChange: { minP, maxP, startT, endT in
                    chartMinPrice = minP
                    chartMaxPrice = maxP
                    chartStartTime = startT
                    chartEndTime = endT
                }
            )
            
            statusBar
        }
        .padding(12)
        .frame(width: isHovering ? expandedWidth : compactWidth, height: isHovering ? expandedHeight : compactHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            // 交通灯按钮 - 仅在大尺寸时显示
            VStack {
                if isHovering {
                    HStack {
                        trafficLightButtons
                        Spacer()
                    }
                }
                Spacer()
            }
            .padding(8)
        )
    }
    
    private var trafficLightButtons: some View {
        HStack(spacing: 8) {
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Circle().fill(Color.red).frame(width: 10, height: 10)
            }
            .buttonStyle(.plain)
            
            Button(action: { NSApp.keyWindow?.orderOut(nil) }) {
                Circle().fill(Color.yellow).frame(width: 10, height: 10)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var headerView: some View {
        HStack {
            Circle().fill(Color.clear).frame(width: 10, height: 10)
            
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.linearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            Text("CryptoTicker")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: { viewModel.enterCompactMode() }) {
                Image(systemName: "rectangle.compress.vertical")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Button(action: { Task { await viewModel.refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var coinCardsView: some View {
        VStack(spacing: 4) {
            CryptoCardView(coin: .bitcoin, price: viewModel.btcPrice, isSelected: viewModel.selectedCoin == .bitcoin, onTap: { viewModel.selectCoin(.bitcoin) })
            CryptoCardView(coin: .ethereum, price: viewModel.ethPrice, isSelected: viewModel.selectedCoin == .ethereum, onTap: { viewModel.selectCoin(.ethereum) })
            CryptoCardView(coin: .solana, price: viewModel.solPrice, isSelected: viewModel.selectedCoin == .solana, onTap: { viewModel.selectCoin(.solana) })
        }
    }
    
    private var statusBar: some View {
        HStack {
            HStack(spacing: 3) {
                Circle().fill(viewModel.isOffline ? Color.red : Color.green).frame(width: 4, height: 4)
                Text(viewModel.isOffline ? "离线" : "在线").font(.system(size: 8)).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                ForEach(AppSettings.updateIntervals, id: \.self) { interval in
                    Button("\(interval)秒") { selectedInterval = interval }
                }
            } label: {
                HStack(spacing: 1) {
                    Image(systemName: "clock").font(.system(size: 8))
                    Text("\(selectedInterval)s").font(.system(size: 8))
                }
                .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 50)
            
            if let price = viewModel.currentPrice {
                Text(price.lastUpdated, style: .time).font(.system(size: 7)).foregroundColor(.secondary.opacity(0.4))
            }
        }
    }
}

#Preview { ContentView() }
