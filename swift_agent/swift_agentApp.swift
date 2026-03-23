//
//  swift_agentApp.swift
//  swift_agent
//
//  Created by 木合买提 on 2026/3/12.
//

import SwiftUI
import AppKit
import UserNotifications

@main
struct swift_agentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button("打开 Agent (⌘⇧A)") {
                    MenuBarController.shared.togglePopover()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var globalMonitor: Any?
    
    override init() {
        super.init()
        setenv("OS_ACTIVITY_MODE", "disable", 1)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 延迟到下一 run loop，避免 "should not be called on main thread" 断言（SwiftUI 初始化时序问题）
        DispatchQueue.main.async { [self] in
            MenuBarController.shared.setup()
            TaskScheduler.shared.startAll()
            setupGlobalShortcut()
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            startWakeWordIfEnabled()
        }
    }
    
    private func startWakeWordIfEnabled() {
        guard UserDefaults.standard.bool(forKey: "wake_word_enabled") else { return }
        Task { @MainActor in
            WakeWordService.shared.startListening(onWake: {
                MenuBarController.shared.showPopover()
            })
        }
    }
    
    /// 注册全局快捷键 Cmd+Shift+A
    private func setupGlobalShortcut() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command, .shift] && event.keyCode == 0 { // 0 = 'A'
                DispatchQueue.main.async {
                    MenuBarController.shared.showPopover()
                }
            }
        }
        if globalMonitor == nil {
            #if DEBUG
            print("[Agent] 全局快捷键未生效：请在 系统设置 > 隐私与安全性 > 辅助功能 中添加本应用")
            #endif
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
