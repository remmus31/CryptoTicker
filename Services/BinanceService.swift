import Foundation
import Combine

/// Binance API 服务 - 无需 API Key
final class BinanceService: ObservableObject {
    static let shared = BinanceService()
    
    private let baseURL = "https://api.binance.com/api/v3"
    private let session: URLSession
    
    @Published var lastError: String?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 获取当前价格
    
    func fetchPrices() async throws -> [CryptoPrice] {
        // 获取多个交易对的最新价格
        let symbols = ["BTCUSDT", "ETHUSDT", "SOLUSDT"]
        var prices: [CryptoPrice] = []
        
        for symbol in symbols {
            let urlString = "\(baseURL)/ticker/24hr?symbol=\(symbol)"
            
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, _) = try await session.data(from: url)
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let price = Double(json["lastPrice"] as? String ?? "0") ?? 0
                    let change = Double(json["priceChangePercent"] as? String ?? "0") ?? 0
                    
                    let cryptoPrice = CryptoPrice(
                        id: self.symbolToId(symbol),
                        symbol: self.symbolToSymbol(symbol),
                        name: self.symbolToName(symbol),
                        currentPrice: price,
                        priceChange24h: change,
                        lastUpdated: Date()
                    )
                    prices.append(cryptoPrice)
                }
            } catch {
                continue
            }
        }
        
        return prices
    }
    
    // MARK: - 获取K线数据 (用于图表)
    
    func fetchKlines(symbol: String, interval: String, limit: Int = 60) async throws -> [PricePoint] {
        let binanceSymbol = self.symbolToBinanceSymbol(symbol)
        let urlString = "\(baseURL)/klines?symbol=\(binanceSymbol)&interval=\(interval)&limit=\(limit)"
        
        guard let url = URL(string: urlString) else {
            throw BinanceError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        
        guard let klines = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
            throw BinanceError.decodingError
        }
        
        return klines.compactMap { kline -> PricePoint? in
            guard kline.count >= 5,
                  let timestamp = kline[0] as? Int64,
                  let closePrice = (kline[4] as? String).flatMap({ Double($0) }) else {
                return nil
            }
            
            return PricePoint(
                timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000),
                price: closePrice
            )
        }
    }
    
    // MARK: - 辅助转换
    
    private func symbolToId(_ symbol: String) -> String {
        switch symbol {
        case "BTCUSDT": return "bitcoin"
        case "ETHUSDT": return "ethereum"
        case "SOLUSDT": return "solana"
        default: return symbol.lowercased()
        }
    }
    
    private func symbolToSymbol(_ symbol: String) -> String {
        switch symbol {
        case "BTCUSDT": return "btc"
        case "ETHUSDT": return "eth"
        case "SOLUSDT": return "sol"
        default: return symbol.lowercased()
        }
    }
    
    private func symbolToName(_ symbol: String) -> String {
        switch symbol {
        case "BTCUSDT": return "Bitcoin"
        case "ETHUSDT": return "Ethereum"
        case "SOLUSDT": return "Solana"
        default: return symbol
        }
    }
    
    private func symbolToBinanceSymbol(_ symbol: String) -> String {
        switch symbol {
        case "bitcoin": return "BTCUSDT"
        case "ethereum": return "ETHUSDT"
        case "solana": return "SOLUSDT"
        default: return "BTCUSDT"
        }
    }
    
    /// 获取 Binance 交易对符号
    func getBinanceSymbol(for coin: CryptoCoin) -> String {
        switch coin {
        case .bitcoin: return "BTCUSDT"
        case .ethereum: return "ETHUSDT"
        case .solana: return "SOLUSDT"
        }
    }
    
    /// 转换时间框架为 Binance interval
    func getInterval(for timeFrame: TimeFrame) -> String {
        switch timeFrame {
        case .oneMin: return "1m"
        case .fiveMin: return "5m"
        case .fifteenMin: return "15m"
        case .oneHour: return "1h"
        case .fourHour: return "4h"
        case .oneDay: return "1d"
        case .oneMonth: return "1M"
        }
    }
}

// MARK: - 错误

enum BinanceError: LocalizedError {
    case invalidURL
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .decodingError: return "数据解析错误"
        }
    }
}
