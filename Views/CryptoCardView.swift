import SwiftUI

/// 加密货币卡片组件
struct CryptoCardView: View {
    let coin: CryptoCoin
    let price: CryptoPrice?
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    private var priceColor: Color {
        guard let price = price else { return .secondary }
        return price.isPositive ? Color(hex: "#00C853") : Color(hex: "#FF1744")
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 币种图标
                ZStack {
                    Circle()
                        .fill(Color(hex: coin.color).opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: coin.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: coin.color))
                }
                
                // 名称和价格
                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let price = price {
                        Text(price.formattedChange)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(priceColor)
                    } else {
                        Text("--")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 价格
                VStack(alignment: .trailing, spacing: 2) {
                    if let price = price {
                        Text(price.formattedPrice)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    } else {
                        Text("Loading...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? 
                          Color.accentColor.opacity(0.15) : 
                          Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Color 扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        CryptoCardView(
            coin: .bitcoin,
            price: CryptoPrice(
                id: "bitcoin",
                symbol: "btc",
                name: "Bitcoin",
                currentPrice: 67842.50,
                priceChange24h: 2.34,
                lastUpdated: Date()
            ),
            isSelected: true,
            onTap: {}
        )
        
        CryptoCardView(
            coin: .ethereum,
            price: CryptoPrice(
                id: "ethereum",
                symbol: "eth",
                name: "Ethereum",
                currentPrice: 3456.78,
                priceChange24h: -1.23,
                lastUpdated: Date()
            ),
            isSelected: false,
            onTap: {}
        )
        
        CryptoCardView(
            coin: .solana,
            price: CryptoPrice(
                id: "solana",
                symbol: "sol",
                name: "Solana",
                currentPrice: 145.67,
                priceChange24h: 5.67,
                lastUpdated: Date()
            ),
            isSelected: false,
            onTap: {}
        )
    }
    .padding()
    .frame(width: 400)
    .background(Color(nsColor: .windowBackgroundColor))
}
