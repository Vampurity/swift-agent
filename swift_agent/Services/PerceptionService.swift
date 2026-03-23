//
//  PerceptionService.swift
//  swift_agent
//
//  感官（感知）- 获取当前环境与设备状态
//

import Foundation

enum PerceptionService {
    
    private static func runShell(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
    
    /// 获取电池状态（电量、是否充电）
    private static func getBatteryInfo() -> String {
        guard let output = runShell("pmset -g batt 2>/dev/null") else {
            return "电池: 台式机或无法获取"
        }
        let lines = output.split(separator: "\n")
        for line in lines {
            let str = String(line)
            if str.contains("%") {
                let charging = str.lowercased().contains("charging") || str.contains("充电") ? "充电中" : "未充电"
                if let range = str.range(of: "\\d+%", options: .regularExpression) {
                    let match = String(str[range])
                    if let pct = Int(match.replacingOccurrences(of: "%", with: "")) {
                        return "电池: \(pct)% \(charging)"
                    }
                }
            }
        }
        return "电池: 无法解析"
    }
    
    /// 获取存储空间
    private static func getStorageInfo() -> String {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64,
              let free = attrs[.systemFreeSize] as? Int64 else {
            return "存储: 无法获取"
        }
        let totalGB = Double(total) / 1_000_000_000
        let freeGB = Double(free) / 1_000_000_000
        let usedPercent = total > 0 ? Int((1 - Double(free) / Double(total)) * 100) : 0
        return "存储: 已用 \(usedPercent)%，剩余 \(String(format: "%.1f", freeGB)) GB / \(String(format: "%.1f", totalGB)) GB"
    }
    
    /// 获取 CPU 使用率
    private static func getCPUUsage() -> String {
        guard let output = runShell("top -l 1 -n 0 2>/dev/null | grep -E 'CPU usage'") else {
            return "CPU: 无法获取"
        }
        let cleaned = output.replacingOccurrences(of: "CPU usage: ", with: "")
        return "CPU: \(cleaned)"
    }
    
    /// 感知当前完整环境状态，供 Agent 作为"感官输入"
    static func perceiveEnvironment() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        let now = formatter.string(from: Date())
        
        let brightness = DeviceTools.getBrightness()
        let volume = DeviceTools.getVolume()
        let bluetooth = DeviceTools.getBluetoothState()
        let wifi = DeviceTools.getWiFiState()
        let dnd = DeviceTools.getDoNotDisturbState()
        let battery = getBatteryInfo()
        let storage = getStorageInfo()
        let cpu = getCPUUsage()
        let nightShift = DeviceTools.getNightShiftState()
        
        return """
        【当前环境感知 - \(now)】
        - 时间: \(now)
        - 亮度: \(brightness)
        - 音量: \(volume)
        - 蓝牙: \(bluetooth)
        - WiFi: \(wifi)
        - 勿扰: \(dnd)
        - \(battery)
        - \(storage)
        - \(cpu)
        - 夜览: \(nightShift)
        """
    }
}
