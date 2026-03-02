import SwiftUI
import AppKit

@main
struct CryptoTickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

/// 应用代理 - 管理窗口生命周期
class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: FloatingPanelController?
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建悬浮面板
        panelController = FloatingPanelController()
        let panel = panelController!.createPanel()
        
        // 显示面板
        panelController!.showPanel()
        
        // 创建菜单栏图标 (可选)
        setupStatusBar()
        
        // 确保应用不退出
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        panelController?.closePanel()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "CryptoTicker")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示面板", action: #selector(showPanel), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "关于", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func showPanel() {
        panelController?.showPanel()
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "CryptoTicker Pro"
        alert.informativeText = "版本 1.0.0\n\n实时加密货币价格看板\n支持 BTC, ETH, SOL"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

/// 设置视图 (minimal)
struct SettingsView: View {
    var body: some View {
        Text("设置")
            .frame(width: 200, height: 100)
    }
}
