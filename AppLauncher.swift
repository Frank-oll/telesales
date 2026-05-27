// 客户电销记录 · macOS 原生壳
// 编译:swiftc -o telesales AppLauncher.swift -framework Cocoa -framework WebKit -O
// 体积约 1 MB,通过 WKWebView 加载 Bundle Resources 里的 prototype.html
import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    let appName = "客户电销记录"

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()

        // 居中开窗,屏幕 85% 宽 / 90% 高(限定上限 1280×820)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let w: CGFloat = min(1280, screen.width * 0.85)
        let h: CGFloat = min(820, screen.height * 0.9)
        let x = screen.origin.x + (screen.width - w) / 2
        let y = screen.origin.y + (screen.height - h) / 2

        window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = appName
        window.minSize = NSSize(width: 760, height: 600)

        // WKWebView:用默认持久化数据仓库,localStorage 跨启动保留
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(webView)

        if let url = Bundle.main.url(forResource: "prototype", withExtension: "html") {
            // 允许读取整个 Resources 目录(vendor/ 下的 JS 也得能读到)
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.loadHTMLString(
                "<html><body style='font:-apple-system;padding:40px;'><h2>启动失败:找不到 prototype.html</h2><p>请重新安装 .app。</p></body></html>",
                baseURL: nil
            )
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // 没有显式菜单的话 WebView 内的 Cmd+C/V/X/A 都会失效,这里建立标准菜单栏
    func setupMenu() {
        let mainMenu = NSMenu()

        // 应用菜单
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏 \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        // 编辑菜单(WKWebView 的输入框依赖这套 selector 才能用快捷键)
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        // 窗口菜单
        let winItem = NSMenuItem()
        mainMenu.addItem(winItem)
        let winMenu = NSMenu(title: "窗口")
        winMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winMenu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        winItem.submenu = winMenu
        NSApp.windowsMenu = winMenu

        NSApp.mainMenu = mainMenu
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
