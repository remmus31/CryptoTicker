import SwiftUI
import AppKit

class FloatingPanelController: NSObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    
    func createPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [
                .nonactivatingPanel,
                .fullSizeContentView,
                .closable,
                .miniaturizable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        // 允许 resize 但不显示 indicator
        panel.minSize = NSSize(width: 300, height: 350)
        panel.maxSize = NSSize(width: 450, height: 600)
        
        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: AnyView(contentView))
        hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: 420)
        hostingView.autoresizingMask = [.width, .height]
        
        panel.contentView = hostingView
        self.panel = panel
        self.hostingView = hostingView
        
        // 设置全局 panel 引用
        sharedPanel = panel
        
        // 初始窗口大小 (紧凑模式)
        let compactSize = NSSize(width: 100, height: 80)
        var frame = panel.frame
        frame.size = compactSize
        panel.setFrame(frame, display: true)
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 340
            let y = screenFrame.maxY - 470
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        return panel
    }
    
    func showPanel() {
        panel?.makeKeyAndOrderFront(nil)
    }
    
    func closePanel() {
        panel?.close()
    }
}
