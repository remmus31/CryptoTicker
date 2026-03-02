import Foundation

/// 加密货币价格模型
struct CryptoPrice: Identifiable, Codable {
    let id: String          // coingecko id: bitcoin, ethereum, solana
    let symbol: String     // 符号: btc, eth, sol
    let name: String       // 名称: Bitcoin, Ethereum, Solana
    var currentPrice: Double
    var priceChange24h: Double  // 24h 涨跌幅 (百分比)
    var lastUpdated: Date
    
    var isPositive: Bool {
        priceChange24h >= 0
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = currentPrice >= 1000 ? 0 : 2
        return formatter.string(from: NSNumber(value: currentPrice)) ?? "$\(currentPrice)"
    }
    
    var formattedChange: String {
        let sign = priceChange24h >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", priceChange24h))%"
    }
}

/// 价格数据点 (用于图表)
struct PricePoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let price: Double
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}

/// 时间框架枚举
enum TimeFrame: String, CaseIterable, Identifiable {
    case oneMin = "1m"
    case fiveMin = "5m"
    case fifteenMin = "15m"
    case oneHour = "1h"
    case fourHour = "4h"
    case oneDay = "1d"
    case oneMonth = "1M"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    /// API 请求所需的天数
    var daysForAPI: Double {
        switch self {
        case .oneMin, .fiveMin, .fifteenMin:
            return 1.0 / 24.0  // 1小时
        case .oneHour:
            return 1.0
        case .fourHour:
            return 1.0
        case .oneDay:
            return 1.0
        case .oneMonth:
            return 30.0
        }
    }
    
    /// 图表数据点数量
    var dataPoints: Int {
        switch self {
        case .oneMin: return 60
        case .fiveMin: return 60
        case .fifteenMin: return 60
        case .oneHour: return 60
        case .fourHour: return 24
        case .oneDay: return 24
        case .oneMonth: return 30
        }
    }
}

/// 币种配置
enum CryptoCoin: String, CaseIterable, Identifiable {
    case bitcoin
    case ethereum
    case solana
    
    var id: String { rawValue }
    
    var coingeckoId: String { rawValue }
    
    var symbol: String {
        switch self {
        case .bitcoin: return "BTC"
        case .ethereum: return "ETH"
        case .solana: return "SOL"
        }
    }
    
    var name: String {
        switch self {
        case .bitcoin: return "Bitcoin"
        case .ethereum: return "Ethereum"
        case .solana: return "Solana"
        }
    }
    
    var iconName: String {
        switch self {
        case .bitcoin: return "bitcoinsign.circle.fill"
        case .ethereum: return "e.circle.fill"
        case .solana: return "s.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .bitcoin: return "#F7931A"
        case .ethereum: return "#627EEA"
        case .solana: return "#14F195"
        }
    }
}
