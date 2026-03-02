import Foundation
import Combine
import AppKit

/// 主 ViewModel - 管理所有加密货币数据
@MainActor
final class CryptoViewModel: ObservableObject {
    
    // MARK: - Published 属性
    
    @Published var prices: [CryptoPrice] = []
    @Published var priceHistory: [CryptoCoin: [PricePoint]] = [:]
    @Published var selectedCoin: CryptoCoin = .bitcoin
    @Published var selectedTimeFrame: TimeFrame = .fifteenMin
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isOffline = false
    @Published var isDemoMode = false
    
    // 紧凑模式 (只显示曲线)
    @Published var isCompactMode = false
    
    // MARK: - 私有属性
    
    private let coinbaseService = CoinbaseService.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var historyRefreshTimer: Timer?
    
    // 刷新间隔
    private let priceRefreshInterval: TimeInterval = 10  // 10秒
    private let historyRefreshInterval: TimeInterval = 30 // 30秒
    
    // MARK: - 初始化
    
    init() {
        setupBindings()
    }
    
    deinit {
        // Clean up timers on main actor
        Task { @MainActor in
            refreshTimer?.invalidate()
            historyRefreshTimer?.invalidate()
        }
    }
    
    // MARK: - 公开方法
    
    /// 启动自动刷新
    func startAutoRefresh() {
        // 立即获取一次数据
        Task {
            await fetchPrices()
            await fetchPriceHistory()
        }
        
        // 价格刷新定时器
        refreshTimer = Timer.scheduledTimer(withTimeInterval: priceRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchPrices()
            }
        }
        
        // 历史数据刷新定时器
        historyRefreshTimer = Timer.scheduledTimer(withTimeInterval: historyRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchPriceHistory()
            }
        }
    }
    
    /// 停止自动刷新
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        historyRefreshTimer?.invalidate()
        historyRefreshTimer = nil
    }
    
    /// 重新启动定时器 (用于更新间隔设置后)
    func restartTimers() {
        stopAutoRefresh()
        startAutoRefresh()
    }
    
    /// 手动刷新所有数据
    func refresh() async {
        await fetchPrices()
        await fetchPriceHistory()
    }
    
    /// 获取实时价格 (使用 Coinbase)
    func fetchPrices() async {
        isLoading = prices.isEmpty
        
        do {
            let newPrices = try await coinbaseService.fetchPrices()
            prices = newPrices
            errorMessage = nil
            isOffline = false
            isDemoMode = false
        } catch {
            errorMessage = error.localizedDescription
            isOffline = (error as NSError).code == NSURLErrorNotConnectedToInternet
            // 使用演示数据
            isDemoMode = true
        }
        
        isLoading = false
    }
    
    /// 获取历史价格数据 (使用 Coinbase)
    func fetchPriceHistory() async {
        do {
            let history = try await coinbaseService.fetchPriceHistory(
                for: selectedCoin,
                timeFrame: selectedTimeFrame
            )
            priceHistory[selectedCoin] = history
            errorMessage = nil
            isDemoMode = false
        } catch {
            // 静默失败，不影响主价格显示
            print("历史数据获取失败: \(error.localizedDescription)")
        }
    }
    
    /// 切换选中的币种
    func selectCoin(_ coin: CryptoCoin) {
        selectedCoin = coin
        Task {
            await fetchPriceHistory()
        }
    }
    
    /// 切换时间框架
    func selectTimeFrame(_ timeFrame: TimeFrame) {
        selectedTimeFrame = timeFrame
        Task {
            await fetchPriceHistory()
        }
    }
    
    /// 切换紧凑模式
    func toggleCompactMode() {
        isCompactMode.toggle()
    }
    
    /// 进入紧凑模式
    func enterCompactMode() {
        isCompactMode = true
    }
    
    /// 退出紧凑模式
    func exitCompactMode() {
        isCompactMode = false
    }
    
    // MARK: - 计算属性
    
    /// 当前选中的币种价格历史
    var currentHistory: [PricePoint] {
        priceHistory[selectedCoin] ?? []
    }
    
    /// 当前选中的币种价格
    var currentPrice: CryptoPrice? {
        prices.first { $0.id == selectedCoin.coingeckoId }
    }
    
    /// BTC 价格
    var btcPrice: CryptoPrice? {
        prices.first { $0.id == "bitcoin" }
    }
    
    /// ETH 价格
    var ethPrice: CryptoPrice? {
        prices.first { $0.id == "ethereum" }
    }
    
    /// SOL 价格
    var solPrice: CryptoPrice? {
        prices.first { $0.id == "solana" }
    }
    
    // MARK: - 私有方法
    
    private func setupBindings() {
        // 监听币种变化
        $selectedCoin
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchPriceHistory()
                }
            }
            .store(in: &cancellables)
        
        // 监听时间框架变化
        $selectedTimeFrame
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchPriceHistory()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - 工具扩展

extension CryptoViewModel {
    
    /// 格式化价格为带千分位的字符串
    static func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = price >= 1000 ? 0 : 2
        formatter.minimumFractionDigits = price >= 1000 ? 0 : 2
        
        if let result = formatter.string(from: NSNumber(value: price)) {
            return "$\(result)"
        }
        return "$\(price)"
    }
    
    /// 格式化涨跌幅
    static func formatChange(_ change: Double) -> String {
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", change))%"
    }
}
