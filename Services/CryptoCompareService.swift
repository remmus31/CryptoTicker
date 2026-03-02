import Foundation
import Combine

/// CryptoCompare API 服务 - 可靠且免费
final class CryptoCompareService: ObservableObject {
    static let shared = CryptoCompareService()
    
    private let baseURL = "https://min-api.cryptocompare.com/data"
    private let session: URLSession
    
    @Published var lastError: String?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 获取当前价格
    
    func fetchPrices() async throws -> [CryptoPrice] {
        let fsyms = "BTC,ETH,SOL"
        let tsyms = "USD"
        let urlString = "\(baseURL)/pricemulti?fsyms=\(fsyms)&tsyms=\(tsyms)"
        
        guard let url = URL(string: urlString) else {
            throw CryptoCompareError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CryptoCompareError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] else {
            throw CryptoCompareError.decodingError
        }
        
        var prices: [CryptoPrice] = []
        
        // BTC
        if let btc = json["BTC"] {
            prices.append(CryptoPrice(
                id: "bitcoin",
                symbol: "btc",
                name: "Bitcoin",
                currentPrice: btc["USD"] ?? 0,
                priceChange24h: 0, // 需要另外获取
                lastUpdated: Date()
            ))
        }
        
        // ETH
        if let eth = json["ETH"] {
            prices.append(CryptoPrice(
                id: "ethereum",
                symbol: "eth",
                name: "Ethereum",
                currentPrice: eth["USD"] ?? 0,
                priceChange24h: 0,
                lastUpdated: Date()
            ))
        }
        
        // SOL
        if let sol = json["SOL"] {
            prices.append(CryptoPrice(
                id: "solana",
                symbol: "sol",
                name: "Solana",
                currentPrice: sol["USD"] ?? 0,
                priceChange24h: 0,
                lastUpdated: Date()
            ))
        }
        
        // 获取24小时变化 - 使用简单的计算方式
        // 从价格历史数据中计算
        if let btcHistory = try? await fetchPriceHistory(for: .bitcoin, timeFrame: .oneDay),
           btcHistory.count >= 2,
           let firstPrice = btcHistory.first?.price,
           let lastPrice = btcHistory.last?.price,
           firstPrice > 0 {
            if let idx = prices.firstIndex(where: { $0.id == "bitcoin" }) {
                prices[idx].priceChange24h = ((lastPrice - firstPrice) / firstPrice) * 100
            }
        }
        
        if let ethHistory = try? await fetchPriceHistory(for: .ethereum, timeFrame: .oneDay),
           ethHistory.count >= 2,
           let firstPrice = ethHistory.first?.price,
           let lastPrice = ethHistory.last?.price,
           firstPrice > 0 {
            if let idx = prices.firstIndex(where: { $0.id == "ethereum" }) {
                prices[idx].priceChange24h = ((lastPrice - firstPrice) / firstPrice) * 100
            }
        }
        
        if let solHistory = try? await fetchPriceHistory(for: .solana, timeFrame: .oneDay),
           solHistory.count >= 2,
           let firstPrice = solHistory.first?.price,
           let lastPrice = solHistory.last?.price,
           firstPrice > 0 {
            if let idx = prices.firstIndex(where: { $0.id == "solana" }) {
                prices[idx].priceChange24h = ((lastPrice - firstPrice) / firstPrice) * 100
            }
        }
        
        return prices
    }
    
    // MARK: - 获取K线数据
    
    func fetchPriceHistory(for coin: CryptoCoin, timeFrame: TimeFrame) async throws -> [PricePoint] {
        let fsym = coin.symbol.uppercased()
        let tsym = "USD"
        
        let limit: Int
        let aggregate: Int
        
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
        case .oneHour:
            limit = 60
            aggregate = 60
        case .fourHour:
            limit = 60
            aggregate = 240
        case .oneDay:
            limit = 30
            aggregate = 1440
        case .oneMonth:
            limit = 30
            aggregate = 43200
        }
        
        let urlString = "\(baseURL)/v2/histohour?fsym=\(fsym)&tsym=\(tsym)&limit=\(limit)&aggregate=\(aggregate)"
        
        guard let url = URL(string: urlString) else {
            throw CryptoCompareError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CryptoCompareError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawData = json["Data"] as? [String: Any],
              let dataArray = rawData["Data"] as? [[String: Any]] else {
            throw CryptoCompareError.decodingError
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

// MARK: - 错误

enum CryptoCompareError: LocalizedError {
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
