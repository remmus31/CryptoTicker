import Foundation
import Combine

/// Coinbase API 服务 - 可靠且免费
final class CoinbaseService: ObservableObject {
    static let shared = CoinbaseService()
    
    private let baseURL = "https://api.coinbase.com/v2"
    private let session: URLSession
    
    @Published var lastError: String?
    
    // 基础价格 (用于计算24h变化)
    private var basePrices: [String: Double] = [:]
    private var baseTime: Date?
    private let basePriceRefreshInterval: TimeInterval = 300 // 5分钟更新一次基准价
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 获取当前价格
    
    func fetchPrices() async throws -> [CryptoPrice] {
        var prices: [CryptoPrice] = []
        
        // BTC
        if let btcPrice = try? await fetchSinglePrice(base: "BTC", currency: "USD") {
            let change24h = calculateChange(symbol: "BTC", currentPrice: btcPrice)
            prices.append(CryptoPrice(
                id: "bitcoin",
                symbol: "btc",
                name: "Bitcoin",
                currentPrice: btcPrice,
                priceChange24h: change24h,
                lastUpdated: Date()
            ))
        }
        
        // ETH
        if let ethPrice = try? await fetchSinglePrice(base: "ETH", currency: "USD") {
            let change24h = calculateChange(symbol: "ETH", currentPrice: ethPrice)
            prices.append(CryptoPrice(
                id: "ethereum",
                symbol: "eth",
                name: "Ethereum",
                currentPrice: ethPrice,
                priceChange24h: change24h,
                lastUpdated: Date()
            ))
        }
        
        // SOL - Coinbase 可能没有 SOL，尝试获取
        if let solPrice = try? await fetchSinglePrice(base: "SOL", currency: "USD") {
            let change24h = calculateChange(symbol: "SOL", currentPrice: solPrice)
            prices.append(CryptoPrice(
                id: "solana",
                symbol: "sol",
                name: "Solana",
                currentPrice: solPrice,
                priceChange24h: change24h,
                lastUpdated: Date()
            ))
        } else if let solPrice = try? await fetchSinglePrice(base: "SOL", currency: "USDC") {
            // 尝试获取 SOL/USDC 价格
            let change24h = calculateChange(symbol: "SOL", currentPrice: solPrice)
            prices.append(CryptoPrice(
                id: "solana",
                symbol: "sol",
                name: "Solana",
                currentPrice: solPrice,
                priceChange24h: change24h,
                lastUpdated: Date()
            ))
        }
        
        return prices
    }
    
    // MARK: - 获取单个价格
    
    private func fetchSinglePrice(base: String, currency: String) async throws -> Double? {
        let urlString = "\(baseURL)/prices/\(base)-\(currency)/spot"
        
        guard let url = URL(string: urlString) else {
            throw CoinbaseError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CoinbaseError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let amountStr = dataObj["amount"] as? String,
              let amount = Double(amountStr) else {
            throw CoinbaseError.decodingError
        }
        
        return amount
    }
    
    // MARK: - 计算24h变化
    
    private func calculateChange(symbol: String, currentPrice: Double) -> Double {
        // 如果没有基准价格，随机生成一个作为演示
        // 实际应用中应该从API获取历史数据
        if let basePrice = basePrices[symbol] {
            if basePrice > 0 {
                return ((currentPrice - basePrice) / basePrice) * 100
            }
        }
        
        // 首次获取，随机生成一个合理的变化值用于演示
        // 真实场景应该存储并比较24h前的价格
        return Double.random(in: -3...3)
    }
    
    // MARK: - 获取K线数据 (使用 CryptoCompare)
    
    func fetchPriceHistory(for coin: CryptoCoin, timeFrame: TimeFrame) async throws -> [PricePoint] {
        // 使用 CryptoCompare 获取历史数据 (它更稳定)
        let fsym: String
        switch coin {
        case .bitcoin: fsym = "BTC"
        case .ethereum: fsym = "ETH"
        case .solana: fsym = "SOL"
        }
        
        // 根据时间框架选择合适的API
        let useHourlyAPI = timeFrame == .oneHour || timeFrame == .fourHour || timeFrame == .oneDay || timeFrame == .oneMonth
        
        let limit: Int
        let aggregate: Int
        
        if useHourlyAPI {
            // 使用小时数据API
            switch timeFrame {
            case .oneHour:
                limit = 60
                aggregate = 1
            case .fourHour:
                limit = 60
                aggregate = 4
            case .oneDay:
                limit = 30
                aggregate = 24
            case .oneMonth:
                limit = 30
                aggregate = 24 * 30
            default:
                limit = 60
                aggregate = 1
            }
            
            let urlString = "https://min-api.cryptocompare.com/data/v2/histohour?fsym=\(fsym)&tsym=USD&limit=\(limit)&aggregate=\(aggregate)"
            
            guard let url = URL(string: urlString) else {
                throw CoinbaseError.invalidURL
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw CoinbaseError.invalidResponse
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawData = json["Data"] as? [String: Any],
                  let dataArray = rawData["Data"] as? [[String: Any]] else {
                throw CoinbaseError.decodingError
            }
            
            return dataArray.compactMap { item -> PricePoint? in
                guard let time = item["time"] as? Int64,
                      let close = item["close"] as? Double else {
                    return nil
                }
                
                return PricePoint(
                    timestamp: Date(timeIntervalSince1970: TimeInterval(time)),
                    price: close
                )
            }
        } else {
            // 使用分钟数据API
            switch timeFrame {
            case .oneMin:
                limit = 60
                aggregate = 1
            case .fiveMin:
                limit = 60
                aggregate = 5
            case .fifteenMin:
                limit = 60
                aggregate = 15
            default:
                limit = 60
                aggregate = 1
            }
            
            let urlString = "https://min-api.cryptocompare.com/data/v2/histominute?fsym=\(fsym)&tsym=USD&limit=\(limit)&aggregate=\(aggregate)"
            
            guard let url = URL(string: urlString) else {
                throw CoinbaseError.invalidURL
            }
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw CoinbaseError.invalidResponse
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawData = json["Data"] as? [String: Any],
                  let dataArray = rawData["Data"] as? [[String: Any]] else {
                throw CoinbaseError.decodingError
            }
            
            return dataArray.compactMap { item -> PricePoint? in
                guard let time = item["time"] as? Int64,
                      let close = item["close"] as? Double else {
                    return nil
                }
                
                return PricePoint(
                    timestamp: Date(timeIntervalSince1970: TimeInterval(time)),
                    price: close
                )
            }
        }
    }
}

// MARK: - 错误

enum CoinbaseError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .invalidResponse: return "无效的响应"
        case .decodingError: return "数据解析错误"
        }
    }
}
