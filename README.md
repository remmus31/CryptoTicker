# CryptoTicker - macOS Cryptocurrency Ticker App

A beautiful, floating cryptocurrency ticker for macOS that displays real-time prices for Bitcoin, Ethereum, and Solana.

## Features

- 🚀 Real-time price updates from Coinbase API
- 📊 Interactive price charts with Swift Charts
- 🎨 Glassmorphism design with transparent floating window
- 📱 Compact mode with price curve display
- 🔄 Auto-refresh with configurable intervals
- 🌙 Dark theme with green/red price indicators

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later

## Installation

### From DMG
1. Download the latest release from GitHub
2. Open the DMG file
3. Drag CryptoTicker to your Applications folder
4. Launch the app

### From Source
```bash
# Clone the repository
git clone https://github.com/yourusername/CryptoTicker.git
cd CryptoTicker

# Open in Xcode
open CryptoTicker.xcodeproj

# Or build from command line
xcodebuild -project CryptoTicker.xcodeproj -scheme CryptoTicker -configuration Release build
```

## Usage

- **Hover** over the window to expand and see detailed charts
- **Click** outside to return to compact mode
- **Select** different cryptocurrencies (BTC, ETH, SOL) from the cards
- **Choose** different timeframes (1m, 5m, 15m, 1h, 4h, 1d, 1M)
- **Configure** refresh interval from the status bar menu

## Configuration

The app uses [Coinbase API](https://www.coinbase.com/) for real-time price data, which is:
- Free to use
- No API key required
- Reliable and fast

## License

MIT License - see LICENSE for details

## Acknowledgments

- [Coinbase API](https://www.coinbase.com/) for price data
- [Swift Charts](https://developer.apple.com/documentation/charts) for visualization
- [CryptoCompare](https://www.cryptocompare.com/) for historical data
