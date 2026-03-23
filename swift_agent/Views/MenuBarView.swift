//
//  MenuBarView.swift
//  swift_agent
//
//  菜单栏视图 - 控制中心图标、弹出面板
//

import SwiftUI
import AppKit

// MARK: - 毛玻璃背景
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.autoresizingMask = [.width, .height]
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

class MenuBarController: NSObject, ObservableObject {
    static let shared = MenuBarController()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    private override init() {
        super.init()
    }
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if let customImage = NSImage(named: "MenuBarIcon") {
                button.image = customImage
            } else {
                button.image = NSImage(systemSymbolName: "cpu.fill", accessibilityDescription: "Agent")
            }
            button.image?.isTemplate = true
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 480, height: 600)
        popover?.behavior = .transient
        popover?.appearance = NSAppearance(named: .aqua)
        let hosting = NSHostingController(rootView: MenuBarContentView())
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        popover?.contentViewController = hosting
    }
    
    @objc func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        let clearItem = NSMenuItem(title: "清空对话", action: #selector(clearConversation), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    /// 供全局快捷键调用
    func showPopover() {
        if popover?.isShown != true, let button = statusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    @objc func clearConversation() {
        NotificationCenter.default.post(name: .clearAgentConversation, object: nil)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension Notification.Name {
    static let clearAgentConversation = Notification.Name("clearAgentConversation")
}

struct MenuBarContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 扁平化 Tab 栏 - 固定高度避免切换时下移
            HStack(spacing: 0) {
                TabButton(title: "对话", icon: "bubble.left.and.bubble.right.fill", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "设置", icon: "gearshape.fill", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            
            // 内容区固定尺寸，避免切换 tab 时顶部下移
            Group {
                if selectedTab == 0 {
                    AgentChatView()
                } else {
                    SettingsView()
                }
            }
            .frame(width: 480, height: 556)
        }
        .background(VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow))
        .contextMenu {
            Button("清空对话") {
                NotificationCenter.default.post(name: .clearAgentConversation, object: nil)
            }
            Divider()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
