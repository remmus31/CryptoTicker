import Foundation
import Combine

/// CoinGecko API 服务
final class CoinGeckoService: ObservableObject {
    static let shared = CoinGeckoService()
    
    private let baseURL = "https://api.coingecko.com/api/v3"
    private let session: URLSession
    
    @Published var lastError: String?
    @Published var isLoading = false
    @Published var useDemoMode = false
    
    // 模拟数据 (当 API 失败时使用)
    private var demoPrices: [CryptoPrice] = [
        CryptoPrice(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 67842.00, priceChange24h: 2.34, lastUpdated: Date()),
        CryptoPrice(id: "ethereum", symbol: "eth", name: "Ethereum", currentPrice: 3456.78, priceChange24h: -1.23, lastUpdated: Date()),
        CryptoPrice(id: "solana", symbol: "sol", name: "Solana", currentPrice: 145.67, priceChange24h: 5.67, lastUpdated: Date())
    ]
    
    // 指数退避参数
    private var retryCount = 0
    private let maxRetries = 2  // 减少重试次数，快速切换到演示模式
    private var retryDelay: TimeInterval = 5
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 获取当前价格
    
    func fetchPrices(for coins: [CryptoCoin] = CryptoCoin.allCases) async throws -> [CryptoPrice] {
        let ids = coins.map { $0.coingeckoId }.joined(separator: ",")
        let urlString = "\(baseURL)/simple/price?ids=\(ids)&vs_currencies=usd&include_24hr_change=true&include_last_updated_at=true"
        
        guard let url = URL(string: urlString) else {
            throw CoinGeckoError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CoinGeckoError.invalidResponse
            }
            
            // 处理速率限制
            if httpResponse.statusCode == 429 {
                throw CoinGeckoError.rateLimited
            }
            
            guard httpResponse.statusCode == 200 else {
                throw CoinGeckoError.httpError(httpResponse.statusCode)
            }
            
            // 解析 JSON
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CoinGeckoError.decodingError
            }
            
            var prices: [CryptoPrice] = []
            
            for coin in coins {
                if let coinData = json[coin.coingeckoId] as? [String: Any] {
                    let currentPrice = coinData["usd"] as? Double ?? 0
                    let change24h = coinData["usd_24h_change"] as? Double ?? 0
                    
                    let price = CryptoPrice(
                        id: coin.coingeckoId,
                        symbol: coin.symbol,
                        name: coin.name,
                        currentPrice: currentPrice,
                        priceChange24h: change24h,
                        lastUpdated: Date()
                    )
                    prices.append(price)
                }
            }
            
            // 重置
            retryCount = 0
            useDemoMode = false
            
            return prices
            
        } catch {
            // API 失败时使用演示模式
            await MainActor.run {
                self.useDemoMode = true
                self.lastError = "API 限流，使用演示数据"
            }
            
            // 返回带随机波动的模拟数据
            return generateDemoPrices()
        }
    }
    
    // MARK: - 生成演示数据
    
    private func generateDemoPrices() -> [CryptoPrice] {
        // 模拟价格波动
        return demoPrices.map { price in
            var mutablePrice = price
            let randomChange = Double.random(in: -3...3)
            mutablePrice.currentPrice *= (1 + randomChange / 100)
            mutablePrice.priceChange24h = randomChange
            mutablePrice.lastUpdated = Date()
            return mutablePrice
        }
    }
    
    // MARK: - 获取历史价格数据 (用于图表)
    
    func fetchPriceHistory(
        for coin: CryptoCoin,
        timeFrame: TimeFrame
    ) async throws -> [PricePoint] {
        
        // 如果是演示模式，生成模拟历史数据
        if useDemoMode {
            return generateDemoHistory(for: coin, timeFrame: timeFrame)
        }
        
        let days: String
        switch timeFrame {
        case .oneMin, .fiveMin, .fifteenMin:
            days = "0.04"
        case .oneHour, .fourHour:
            days = "1"
        case .oneDay:
            days = "1"
        case .oneMonth:
            days = "30"
        }
        
        let urlString = "\(baseURL)/coins/\(coin.coingeckoId)/market_chart?vs_currency=usd&days=\(days)&interval=minute"
        
        guard let url = URL(string: urlString) else {
            throw CoinGeckoError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CoinGeckoError.invalidResponse
            }
            
            if httpResponse.statusCode == 429 || httpResponse.statusCode != 200 {
                // API 失败，返回演示数据
                return generateDemoHistory(for: coin, timeFrame: timeFrame)
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pricesArray = json["prices"] as? [[Double]] else {
                throw CoinGeckoError.decodingError
            }
            
            let points = pricesArray.compactMap { item -> PricePoint? in
                guard item.count >= 2 else { return nil }
                let timestamp = Date(timeIntervalSince1970: item[0] / 1000)
                let price = item[1]
                return PricePoint(timestamp: timestamp, price: price)
            }
            
            return downsample(points: points, targetCount: timeFrame.dataPoints)
            
        } catch {
            // 返回演示历史数据
            return generateDemoHistory(for: coin, timeFrame: timeFrame)
        }
    }
    
    // MARK: - 生成演示历史数据
    
    private func generateDemoHistory(for coin: CryptoCoin, timeFrame: TimeFrame) -> [PricePoint] {
        let basePrice: Double
        switch coin {
        case .bitcoin: basePrice = 67000
        case .ethereum: basePrice = 3400
        case .solana: basePrice = 145
        }
        
        let pointCount = timeFrame.dataPoints
        var points: [PricePoint] = []
        
        let now = Date()
        let interval: TimeInterval
        
        switch timeFrame {
        case .oneMin: interval = 60
        case .fiveMin: interval = 300
        case .fifteenMin: interval = 900
        case .oneHour: interval = 3600
        case .fourHour: interval = 14400
        case .oneDay: interval = 86400
        case .oneMonth: interval = 86400 * 3
        }
        
        for i in 0..<pointCount {
            let timestamp = now.addingTimeInterval(-Double(pointCount - i) * interval)
            // 添加随机波动
            let variation = Double.random(in: -0.02...0.02)
            let price = basePrice * (1 + variation * Double(i) / Double(pointCount))
            points.append(PricePoint(timestamp: timestamp, price: price))
        }
        
        return points
    }
    
    // MARK: - 降采样
    
    private func downsample(points: [PricePoint], targetCount: Int) -> [PricePoint] {
        guard points.count > targetCount else { return points }
        
        let step = points.count / targetCount
        var result: [PricePoint] = []
        
        for i in stride(from: 0, to: points.count, by: step) {
            result.append(points[i])
            if result.count >= targetCount { break }
        }
        
        return result
    }
    
    // MARK: - 错误处理
    
    func handleError(_ error: Error) -> String {
        if let coingeckoError = error as? CoinGeckoError {
            switch coingeckoError {
            case .rateLimited:
                return "API 限流中，使用演示数据"
            case .networkError:
                return "网络连接失败"
            case .decodingError:
                return "数据解析失败"
            default:
                return "请求失败: \(error.localizedDescription)"
            }
        }
        
        if (error as NSError).code == NSURLErrorNotConnectedToInternet {
            return "无网络连接"
        }
        
        return "未知错误: \(error.localizedDescription)"
    }
}

// MARK: - 错误枚举

enum CoinGeckoError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case rateLimited
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .decodingError:
            return "数据解析错误"
        case .rateLimited:
            return "API 限流"
        case .networkError:
            return "网络错误"
        }
    }
}
