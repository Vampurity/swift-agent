//
//  DeviceTools.swift
//  swift_agent
//
//  设备控制工具 - Agent 可调用的本地函数
//

import Foundation
import AppKit
import IOKit
import IOKit.graphics
import UserNotifications
import EventKit

private let kIODisplayBrightnessKey = "IODisplayBrightness" as CFString

private extension String {
    var shellEscaped: String {
        "'\(self.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

// MARK: - 设备工具执行器

enum DeviceTools {
    
    // MARK: - 亮度控制
    
    /// 设置屏幕亮度 (0.0 - 1.0)
    static func setBrightness(_ level: Float) -> String {
        let level = max(0, min(1, level))
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == kIOReturnSuccess else {
            return "设置亮度失败: 无法访问显示服务"
        }
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        var success = false
        while service != 0 {
            let setResult = IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey, level)
            if setResult == kIOReturnSuccess { success = true }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return success ? "亮度已设置为 \(Int(level * 100))%" : "设置亮度失败"
    }
    
    /// 获取当前亮度
    static func getBrightness() -> String {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == kIOReturnSuccess else {
            return "获取亮度失败"
        }
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        var brightness: Float = 0
        while service != 0 {
            if IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey, &brightness) == kIOReturnSuccess {
                IOObjectRelease(service)
                return "当前亮度: \(Int(brightness * 100))%"
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return "获取亮度失败"
    }
    
    // MARK: - 音量控制
    
    /// 设置系统音量 (0.0 - 1.0)
    static func setVolume(_ level: Float) -> String {
        let level = max(0, min(1, level))
        let script = "set volume output volume \(level)"
        if runAppleScript(script) != nil {
            return "音量已设置为 \(Int(level * 100))%"
        }
        return "设置音量失败（需授予 Apple Events 权限）"
    }
    
    /// 获取当前音量
    static func getVolume() -> String {
        let script = "output volume of (get volume settings)"
        if let result = runAppleScript(script), let vol = Int(result), vol >= 0 {
            return "当前音量: \(vol)%"
        }
        return "无法获取音量（可能无音频设备）"
    }
    
    /// 静音/取消静音
    static func setMuted(_ muted: Bool) -> String {
        let script = muted ? "set volume with output muted" : "set volume without output muted"
        if runAppleScript(script) != nil {
            return muted ? "已静音" : "已取消静音"
        }
        return "设置静音失败（需授予 Apple Events 权限）"
    }
    
    // MARK: - 蓝牙控制
    
    private static var blueutilPath: String? {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/blueutil") {
            return "/opt/homebrew/bin/blueutil"
        }
        if FileManager.default.fileExists(atPath: "/usr/local/bin/blueutil") {
            return "/usr/local/bin/blueutil"
        }
        return nil
    }
    
    /// 获取蓝牙状态
    static func getBluetoothState() -> String {
        if let result = runShell("/usr/sbin/system_profiler SPBluetoothDataType 2>/dev/null | grep -i 'Bluetooth Power'") {
            return result.lowercased().contains("on") ? "蓝牙已开启" : "蓝牙已关闭"
        }
        if let path = blueutilPath, let result = runShell("\(path) -p 2>/dev/null") {
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "1" ? "蓝牙已开启" : "蓝牙已关闭"
        }
        return "无法获取蓝牙状态，请安装 blueutil: brew install blueutil"
    }
    
    /// 开启蓝牙
    static func setBluetoothOn() -> String {
        if let path = blueutilPath, runShell("\(path) -p 1 2>/dev/null") != nil {
            return "蓝牙已开启"
        }
        return runAppleScript("tell application \"System Events\" to tell process \"Control Center\" to click menu bar item \"Bluetooth\" of menu bar 2") ?? "请安装 blueutil: brew install blueutil"
    }
    
    /// 关闭蓝牙
    static func setBluetoothOff() -> String {
        if let path = blueutilPath, runShell("\(path) -p 0 2>/dev/null") != nil {
            return "蓝牙已关闭"
        }
        return "请安装 blueutil: brew install blueutil"
    }
    
    /// 切换蓝牙开关
    static func toggleBluetooth() -> String {
        if let path = blueutilPath, let result = runShell("\(path) -p 2>/dev/null") {
            let isOn = result.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
            _ = runShell("\(path) -p \(isOn ? 0 : 1) 2>/dev/null")
            return isOn ? "蓝牙已关闭" : "蓝牙已开启"
        }
        return "请安装 blueutil: brew install blueutil"
    }
    
    // MARK: - WiFi 控制
    
    /// 获取 WiFi 状态
    static func getWiFiState() -> String {
        let interfaces = ["en0", "en1"]
        for iface in interfaces {
            if let result = runShell("/usr/sbin/networksetup -getairportpower \(iface) 2>/dev/null") {
                return result.lowercased().contains("on") ? "WiFi 已开启" : "WiFi 已关闭"
            }
        }
        return "无法获取 WiFi 状态"
    }
    
    /// 开启 WiFi
    static func setWiFiOn() -> String {
        for iface in ["en0", "en1"] {
            _ = runShell("/usr/sbin/networksetup -setairportpower \(iface) on 2>/dev/null")
        }
        return "WiFi 已开启"
    }
    
    /// 关闭 WiFi
    static func setWiFiOff() -> String {
        for iface in ["en0", "en1"] {
            _ = runShell("/usr/sbin/networksetup -setairportpower \(iface) off 2>/dev/null")
        }
        return "WiFi 已关闭"
    }
    
    /// 切换 WiFi
    static func toggleWiFi() -> String {
        for iface in ["en0", "en1"] {
            if let result = runShell("/usr/sbin/networksetup -getairportpower \(iface) 2>/dev/null"),
               result.lowercased().contains("on") {
                _ = runShell("/usr/sbin/networksetup -setairportpower \(iface) off 2>/dev/null")
                return "WiFi 已关闭"
            }
        }
        _ = runShell("/usr/sbin/networksetup -setairportpower en0 on 2>/dev/null")
        return "WiFi 已开启"
    }
    
    // MARK: - 锁屏 / 屏保
    
    /// 锁定屏幕（需授予辅助功能权限）
    static func lockScreen() -> String {
        let script = """
        tell application "System Events" to keystroke "q" using {command down, control down}
        """
        if runAppleScript(script) != nil {
            return "已锁定屏幕"
        }
        return "锁屏失败，请确保已在 系统设置 > 桌面与程序坞 > 触发角 或 快捷键 中配置锁屏，或手动使用 Cmd+Ctrl+Q"
    }
    
    /// 启动屏保
    static func startScreensaver() -> String {
        if runShell("open /System/Library/CoreServices/ScreenSaverEngine.app 2>/dev/null") != nil {
            return "已启动屏保"
        }
        if runShell("open -a ScreenSaverEngine 2>/dev/null") != nil {
            return "已启动屏保"
        }
        return "启动屏保失败"
    }
    
    // MARK: - 夜览 / True Tone
    
    /// 获取夜览状态
    static func getNightShiftState() -> String {
        if let result = runShell("defaults -currentHost read com.apple.CoreBrightness BlueReduction 2>/dev/null") {
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "1" ? "夜览已开启" : "夜览已关闭"
        }
        return "无法获取夜览状态"
    }
    
    /// 设置夜览模式
    static func setNightShift(_ enabled: Bool) -> String {
        _ = runShell("defaults -currentHost write com.apple.CoreBrightness BlueReduction -bool \(enabled) 2>/dev/null")
        _ = runShell("killall CoreBrightness 2>/dev/null")
        return enabled ? "夜览已开启" : "夜览已关闭"
    }
    
    // MARK: - 勿扰模式 / 专注模式
    
    static func getDoNotDisturbState() -> String {
        if let result = runShell("defaults read com.apple.controlcenter DoNotDisturb 2>/dev/null") {
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "1" ? "勿扰模式已开启" : "勿扰模式已关闭"
        }
        return "无法获取勿扰模式状态"
    }
    
    static func setDoNotDisturb(_ enabled: Bool) -> String {
        _ = runShell("defaults write com.apple.controlcenter DoNotDisturb -bool \(enabled) 2>/dev/null")
        _ = runShell("killall ControlCenter 2>/dev/null")
        return enabled ? "勿扰模式已开启" : "勿扰模式已关闭"
    }
    
    // MARK: - 打开应用
    
    /// 应用名到 open -a 参数的映射（支持中英文）
    private static let appNameMap: [String: String] = [
        "siri": "siri",
        "终端": "Terminal",
        "terminal": "Terminal",
        "访达": "Finder",
        "finder": "Finder",
        "备忘录": "Notes",
        "notes": "Notes",
        "邮件": "Mail",
        "mail": "Mail",
        "日历": "Calendar",
        "calendar": "Calendar",
        "计算器": "Calculator",
        "calculator": "Calculator",
        "系统偏好设置": "System Preferences",
        "system preferences": "System Preferences",
        "系统设置": "System Settings",
        "system settings": "System Settings",
        "safari": "Safari",
        "照片": "Photos",
        "photos": "Photos",
        "音乐": "Music",
        "music": "Music",
        "播客": "Podcasts",
        "podcasts": "Podcasts",
        "地图": "Maps",
        "maps": "Maps",
        "提醒事项": "Reminders",
        "reminders": "Reminders",
        "通讯录": "Contacts",
        "contacts": "Contacts",
        "图书": "Books",
        "books": "Books",
        "快捷指令": "Shortcuts",
        "shortcuts": "Shortcuts",
        "语音备忘录": "Voice Memos",
        "voice memos": "Voice Memos",
        "预览": "Preview",
        "preview": "Preview",
        "文本编辑": "TextEdit",
        "textedit": "TextEdit",
        "磁盘工具": "Disk Utility",
        "disk utility": "Disk Utility",
        "活动监视器": "Activity Monitor",
        "activity monitor": "Activity Monitor",
        "钥匙串访问": "Keychain Access",
        "keychain access": "Keychain Access"
    ]
    
    static func openApp(_ appName: String) -> String {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "请提供应用名称" }
        
        let lower = trimmed.lowercased()
        if lower == "siri" {
            return openSiri()
        }
        
        let resolvedName = appNameMap[lower] ?? trimmed
        let result = runShell("open -a \(resolvedName.shellEscaped) 2>&1")
        if let err = result, (err.lowercased().contains("unable to find") || err.lowercased().contains("cannot find")) {
            return "未找到应用「\(trimmed)」，请确认名称正确"
        }
        return "已打开 \(resolvedName)"
    }
    
    private static func openSiri() -> String {
        let script = """
        tell application "System Events"
            key code 49 using {shift down, command down}
        end tell
        """
        if runAppleScript(script) != nil {
            return "已打开 Siri（默认快捷键 Cmd+Shift+Space）"
        }
        return "打开 Siri 失败，请确保已在 系统设置 > 辅助功能 > Siri 中启用，或手动点击菜单栏 Siri 图标"
    }
    
    // MARK: - 剪贴板
    
    static func getClipboard() -> String {
        let pasteboard = NSPasteboard.general
        if let str = pasteboard.string(forType: .string), !str.isEmpty {
            return str
        }
        return "剪贴板为空或非文本内容"
    }
    
    static func setClipboard(_ text: String) -> String {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return "已复制到剪贴板"
    }
    
    static func pasteText() -> String {
        let script = """
        tell application "System Events" to keystroke "v" using command down
        """
        if runAppleScript(script) != nil {
            return "已粘贴剪贴板内容到当前焦点位置"
        }
        return "粘贴失败，需授予辅助功能权限"
    }
    
    // MARK: - 通知与提醒
    
    static func showNotification(title: String, body: String) -> String {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { err in
            if err != nil { }
        }
        return "已发送通知"
    }
    
    static func createReminder(title: String, dueDate: Date?) async -> String {
        let store = EKEventStore()
        return await withCheckedContinuation { continuation in
            let requestBlock: (Bool, Error?) -> Void = { granted, _ in
                guard granted else {
                    continuation.resume(returning: "需要提醒事项权限")
                    return
                }
                let reminder = EKReminder(eventStore: store)
                reminder.title = title
                let calendars = store.calendars(for: .reminder)
                guard let cal = calendars.first else {
                    continuation.resume(returning: "无可用提醒事项日历")
                    return
                }
                reminder.calendar = cal
                if let date = dueDate {
                    let due = EKAlarm(absoluteDate: date)
                    reminder.addAlarm(due)
                }
                do {
                    try store.save(reminder, commit: true)
                    continuation.resume(returning: "已创建提醒: \(title)")
                } catch {
                    continuation.resume(returning: "创建提醒失败: \(error.localizedDescription)")
                }
            }
            if #available(macOS 14.0, *) {
                store.requestFullAccessToReminders(completion: requestBlock)
            } else {
                store.requestAccess(to: .reminder, completion: requestBlock)
            }
        }
    }
    
    static func runShortcut(_ name: String) -> String {
        let result = runShell("shortcuts run \(name.shellEscaped) 2>&1")
        if result != nil, !(result ?? "").lowercased().contains("error") {
            return "已执行快捷指令「\(name)」"
        }
        return "执行快捷指令失败，请确认「\(name)」存在（可用 shortcuts list 查看）"
    }
    
    // MARK: - 辅助方法
    
    private static func runAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let output = appleScript?.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        return output?.stringValue
    }
    
    private static func runShell(_ command: String, captureStderr: Bool = false) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        if captureStderr {
            let errPipe = Pipe()
            process.standardError = errPipe
            do {
                try process.run()
                process.waitUntilExit()
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                var result = String(data: outData, encoding: .utf8) ?? ""
                if !errData.isEmpty, let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !errStr.isEmpty {
                    result = result.isEmpty ? errStr : "\(result)\n[stderr] \(errStr)"
                }
                return result.isEmpty ? nil : result.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return nil
            }
        } else {
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return nil
            }
        }
    }
    
    // MARK: - 执行工具调用
    
    static func execute(toolName: String, arguments: [String: Any]) async -> String {
        switch toolName {
        case "set_brightness":
            if let level = arguments["level"] as? Double {
                return setBrightness(Float(level))
            }
            return "缺少参数: level (0.0-1.0)"
            
        case "get_brightness":
            return getBrightness()
            
        case "set_volume":
            if let level = arguments["level"] as? Double {
                return setVolume(Float(level))
            }
            return "缺少参数: level (0.0-1.0)"
            
        case "get_volume":
            return getVolume()
            
        case "set_muted":
            if let muted = arguments["muted"] as? Bool {
                return setMuted(muted)
            }
            return "缺少参数: muted (true/false)"
            
        case "get_bluetooth_state":
            return getBluetoothState()
            
        case "set_bluetooth_on":
            return setBluetoothOn()
            
        case "set_bluetooth_off":
            return setBluetoothOff()
            
        case "toggle_bluetooth":
            return toggleBluetooth()
            
        case "get_wifi_state":
            return getWiFiState()
            
        case "set_wifi_on":
            return setWiFiOn()
            
        case "set_wifi_off":
            return setWiFiOff()
            
        case "toggle_wifi":
            return toggleWiFi()
            
        case "get_do_not_disturb_state":
            return getDoNotDisturbState()
            
        case "set_do_not_disturb":
            if let enabled = arguments["enabled"] as? Bool {
                return setDoNotDisturb(enabled)
            }
            return "缺少参数: enabled (true/false)"
            
        case "perceive_environment":
            return PerceptionService.perceiveEnvironment()
            
        case "remember":
            if let content = arguments["content"] as? String, !content.isEmpty {
                Task { @MainActor in
                    if arguments["type"] as? String == "preference" {
                        MemoryService.shared.addPreference(content)
                    } else {
                        MemoryService.shared.addFact(content)
                    }
                }
                return "已记住: \(content)"
            }
            return "缺少参数: content"
            
        case "open_app":
            if let name = arguments["app_name"] as? String {
                return openApp(name)
            }
            return "缺少参数: app_name"
            
        case "lock_screen":
            return lockScreen()
            
        case "start_screensaver":
            return startScreensaver()
            
        case "get_night_shift_state":
            return getNightShiftState()
            
        case "set_night_shift":
            if let enabled = arguments["enabled"] as? Bool {
                return setNightShift(enabled)
            }
            return "缺少参数: enabled (true/false)"
            
        case "apply_preset":
            if let presetId = arguments["preset_id"] as? String {
                return applyPreset(presetId)
            }
            return "缺少参数: preset_id (meeting/work/sleep)"
            
        case "get_clipboard":
            return getClipboard()
            
        case "set_clipboard":
            if let text = arguments["text"] as? String {
                return setClipboard(text)
            }
            return "缺少参数: text"
            
        case "paste_text":
            return pasteText()
            
        case "show_notification":
            let title = arguments["title"] as? String ?? "提醒"
            let body = arguments["body"] as? String ?? ""
            return showNotification(title: title, body: body)
            
        case "create_reminder":
            if let title = arguments["title"] as? String, !title.isEmpty {
                let dueStr = arguments["due_date"] as? String
                let due = parseDueDate(dueStr)
                return await createReminder(title: title, dueDate: due)
            }
            return "缺少参数: title"
            
        case "run_shortcut":
            if let name = arguments["shortcut_name"] as? String, !name.isEmpty {
                return runShortcut(name)
            }
            return "缺少参数: shortcut_name"
            
        case "create_scheduled_task":
            return await createScheduledTaskFromArgs(arguments)
            
        default:
            return "未知工具: \(toolName)"
        }
    }
    
    private static func parseDueDate(_ str: String?) -> Date? {
        guard let s = str, !s.isEmpty else { return nil }
        let lower = s.lowercased().trimmingCharacters(in: .whitespaces)
        let now = Date()
        let cal = Calendar.current
        let numbers = s.filter { $0.isNumber }
        if lower.contains("分钟后") || lower.contains("分钟") {
            if let n = Int(numbers), n > 0 {
                return cal.date(byAdding: .minute, value: n, to: now)
            }
        }
        if lower.contains("小时后") || lower.contains("小时") {
            if let n = Int(numbers), n > 0 {
                return cal.date(byAdding: .hour, value: n, to: now)
            }
        }
        if lower.contains("明天") {
            let day = cal.date(byAdding: .day, value: 1, to: now) ?? now
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = 9
            comps.minute = 0
            if !numbers.isEmpty, let n = Int(numbers) {
                if n < 24 {
                    comps.hour = n
                } else if n < 2400 {
                    comps.hour = n / 100
                    comps.minute = n % 100
                }
            }
            return cal.date(from: comps)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: s) {
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            let d = cal.dateComponents([.hour, .minute], from: date)
            comps.hour = d.hour ?? 9
            comps.minute = d.minute ?? 0
            return cal.date(from: comps)
        }
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: s)
    }
    
    private static func createScheduledTaskFromArgs(_ args: [String: Any]) async -> String {
        guard let name = args["name"] as? String, !name.isEmpty else {
            return "缺少参数: name"
        }
        let scheduleType = (args["schedule_type"] as? String) ?? "interval"
        let actionStr = (args["action"] as? String) ?? ""
        let conditionStr = (args["condition"] as? String) ?? "always"
        
        let condition: TaskCondition
        switch conditionStr {
        case "bluetooth_is_on": condition = .bluetoothIsOn
        case "bluetooth_is_off": condition = .bluetoothIsOff
        case "wifi_is_on": condition = .wifiIsOn
        case "wifi_is_off": condition = .wifiIsOff
        default: condition = .always
        }
        
        let action: TaskAction
        switch actionStr {
        case "turn_bluetooth_off": action = .turnBluetoothOff
        case "turn_bluetooth_on": action = .turnBluetoothOn
        case "turn_wifi_off": action = .turnWifiOff
        case "turn_wifi_on": action = .turnWifiOn
        case "set_brightness":
            let level = (args["level"] as? Double).map { Float($0) } ?? 0.5
            action = .setBrightness(level)
        case "set_volume":
            let level = (args["level"] as? Double).map { Float($0) } ?? 0.5
            action = .setVolume(level)
        case "show_reminder":
            let msg = args["message"] as? String ?? "该休息了"
            action = .showReminder(msg)
        default:
            return "未知动作: \(actionStr)，可选: turn_bluetooth_off, turn_bluetooth_on, turn_wifi_off, turn_wifi_on, set_brightness, set_volume, show_reminder"
        }
        
        let interval = (args["interval_seconds"] as? Int) ?? 300
        let dailyTime = args["daily_time"] as? String
        
        let task: ScheduledTask
        if scheduleType == "daily", let time = dailyTime, !time.isEmpty {
            task = ScheduledTask(
                name: name,
                intervalSeconds: 3600,
                condition: condition,
                action: action,
                dailyTime: time,
                scheduleType: .daily
            )
        } else {
            task = ScheduledTask(
                name: name,
                intervalSeconds: max(1, interval),
                condition: condition,
                action: action
            )
        }
        
        await MainActor.run {
            TaskScheduler.shared.addTask(task)
        }
        return "已创建定时任务「\(name)」"
    }
    
    private static func applyPreset(_ presetId: String) -> String {
        let preset = PresetService.builtinPresets.first { $0.id == presetId }
        guard let p = preset else {
            return "未知预设，可选: meeting(会议模式), work(工作模式), sleep(睡眠模式)"
        }
        var results: [String] = []
        for action in p.actions {
            switch action {
            case .setBrightness(let level): results.append(setBrightness(level))
            case .setVolume(let level): results.append(setVolume(level))
            case .setMuted(let m): results.append(setMuted(m))
            case .setBluetooth(let on): results.append(on ? setBluetoothOn() : setBluetoothOff())
            case .setWiFi(let on): results.append(on ? setWiFiOn() : setWiFiOff())
            case .setDoNotDisturb(let e): results.append(setDoNotDisturb(e))
            case .setNightShift(let e): results.append(setNightShift(e))
            }
        }
        return "已应用「\(p.name)」: \(results.joined(separator: "; "))"
    }
}
