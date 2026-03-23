//
//  TaskScheduler.swift
//  swift_agent
//
//  定时任务调度器 - 支持周期性检测并执行设备操作
//

import Foundation
import Combine

// MARK: - 定时任务模型

struct ScheduledTask: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var intervalSeconds: Int
    var condition: TaskCondition
    var action: TaskAction
    var isEnabled: Bool
    /// 每日定时：格式 "HH:mm"，如 "09:00"。仅当 scheduleType == .daily 时有效
    var dailyTime: String?
    /// 调度类型：interval=按间隔秒数，daily=每天固定时刻
    var scheduleType: ScheduleType
    
    enum ScheduleType: String, Codable, Equatable {
        case interval = "interval"
        case daily = "daily"
    }
    
    init(id: UUID = UUID(), name: String, intervalSeconds: Int, condition: TaskCondition, action: TaskAction, isEnabled: Bool = true, dailyTime: String? = nil, scheduleType: ScheduleType = .interval) {
        self.id = id
        self.name = name
        self.intervalSeconds = max(1, intervalSeconds)
        self.condition = condition
        self.action = action
        self.isEnabled = isEnabled
        self.dailyTime = dailyTime
        self.scheduleType = scheduleType
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        intervalSeconds = try c.decode(Int.self, forKey: .intervalSeconds)
        condition = try c.decode(TaskCondition.self, forKey: .condition)
        action = try c.decode(TaskAction.self, forKey: .action)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        dailyTime = try c.decodeIfPresent(String.self, forKey: .dailyTime)
        scheduleType = try c.decodeIfPresent(ScheduleType.self, forKey: .scheduleType) ?? .interval
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, intervalSeconds, condition, action, isEnabled, dailyTime, scheduleType
    }
}

enum TaskCondition: Codable, Equatable {
    case bluetoothIsOn
    case bluetoothIsOff
    case wifiIsOn
    case wifiIsOff
    case always
    
    var displayName: String {
        switch self {
        case .bluetoothIsOn: return "蓝牙开启时"
        case .bluetoothIsOff: return "蓝牙关闭时"
        case .wifiIsOn: return "WiFi 开启时"
        case .wifiIsOff: return "WiFi 关闭时"
        case .always: return "始终"
        }
    }
}

enum TaskAction: Codable, Equatable {
    case turnBluetoothOff
    case turnBluetoothOn
    case turnWifiOff
    case turnWifiOn
    case setBrightness(Float)
    case setVolume(Float)
    case showReminder(String)
    
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let str = try? c.decode(String.self) {
            switch str {
            case "turnBluetoothOff": self = .turnBluetoothOff
            case "turnBluetoothOn": self = .turnBluetoothOn
            case "turnWifiOff": self = .turnWifiOff
            case "turnWifiOn": self = .turnWifiOn
            default:
                let keyed = try decoder.container(keyedBy: TaskActionCodingKeys.self)
                if let msg = try keyed.decodeIfPresent(String.self, forKey: .showReminder) {
                    self = .showReminder(msg)
                } else if let v = try keyed.decodeIfPresent(Float.self, forKey: .setBrightness) {
                    self = .setBrightness(v)
                } else if let v = try keyed.decodeIfPresent(Float.self, forKey: .setVolume) {
                    self = .setVolume(v)
                } else {
                    throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown TaskAction"))
                }
            }
            return
        }
        let keyed = try decoder.container(keyedBy: TaskActionCodingKeys.self)
        if let msg = try keyed.decodeIfPresent(String.self, forKey: .showReminder) {
            self = .showReminder(msg)
        } else if let v = try keyed.decodeIfPresent(Float.self, forKey: .setBrightness) {
            self = .setBrightness(v)
        } else if let v = try keyed.decodeIfPresent(Float.self, forKey: .setVolume) {
            self = .setVolume(v)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown TaskAction"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .turnBluetoothOff: var c = encoder.singleValueContainer(); try c.encode("turnBluetoothOff")
        case .turnBluetoothOn: var c = encoder.singleValueContainer(); try c.encode("turnBluetoothOn")
        case .turnWifiOff: var c = encoder.singleValueContainer(); try c.encode("turnWifiOff")
        case .turnWifiOn: var c = encoder.singleValueContainer(); try c.encode("turnWifiOn")
        case .setBrightness(let v): var c = encoder.container(keyedBy: TaskActionCodingKeys.self); try c.encode(v, forKey: .setBrightness)
        case .setVolume(let v): var c = encoder.container(keyedBy: TaskActionCodingKeys.self); try c.encode(v, forKey: .setVolume)
        case .showReminder(let msg): var c = encoder.container(keyedBy: TaskActionCodingKeys.self); try c.encode(msg, forKey: .showReminder)
        }
    }
    
    private enum TaskActionCodingKeys: String, CodingKey {
        case turnBluetoothOff, turnBluetoothOn, turnWifiOff, turnWifiOn, setBrightness, setVolume, showReminder
    }
    
    var displayName: String {
        switch self {
        case .turnBluetoothOff: return "关闭蓝牙"
        case .turnBluetoothOn: return "开启蓝牙"
        case .turnWifiOff: return "关闭 WiFi"
        case .turnWifiOn: return "开启 WiFi"
        case .setBrightness(let v): return "设置亮度 \(Int(v * 100))%"
        case .setVolume(let v): return "设置音量 \(Int(v * 100))%"
        case .showReminder(let msg): return "提醒: \(msg)"
        }
    }
}

// MARK: - 任务调度器

@MainActor
class TaskScheduler: ObservableObject {
    static let shared = TaskScheduler()
    
    @Published var tasks: [ScheduledTask] = []
    private var timers: [UUID: Timer] = [:]
    private let storageKey = "scheduled_tasks"
    
    private init() {
        loadTasks()
    }
    
    func addTask(_ task: ScheduledTask) {
        tasks.append(task)
        saveTasks()
        if task.isEnabled {
            startTask(task)
        }
    }
    
    func removeTask(_ task: ScheduledTask) {
        stopTask(task)
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    func updateTask(_ task: ScheduledTask) {
        stopTask(task)
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        }
        saveTasks()
        if task.isEnabled {
            startTask(task)
        }
    }
    
    func toggleTask(_ task: ScheduledTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].isEnabled.toggle()
            if tasks[idx].isEnabled {
                startTask(tasks[idx])
            } else {
                stopTask(tasks[idx])
            }
            saveTasks()
        }
    }
    
    func startTask(_ task: ScheduledTask) {
        guard task.isEnabled else { return }
        stopTask(task)
        
        let taskCopy = task
        if task.scheduleType == .daily, let timeStr = task.dailyTime {
            let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                Task { @MainActor in
                    if Self.isDailyTimeMatch(timeStr) {
                        TaskScheduler.shared.executeTaskAsync(taskCopy)
                    }
                }
            }
            timer.tolerance = 5
            RunLoop.main.add(timer, forMode: .common)
            timers[task.id] = timer
        } else {
            let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(task.intervalSeconds), repeats: true) { _ in
                Task { @MainActor in
                    TaskScheduler.shared.executeTaskAsync(taskCopy)
                }
            }
            timer.tolerance = 1
            RunLoop.main.add(timer, forMode: .common)
            timers[task.id] = timer
        }
    }
    
    private static func isDailyTimeMatch(_ timeStr: String) -> Bool {
        let parts = timeStr.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              h >= 0, h <= 23, m >= 0, m <= 59 else { return false }
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        return hour == h && minute == m
    }
    
    func stopTask(_ task: ScheduledTask) {
        timers[task.id]?.invalidate()
        timers[task.id] = nil
    }
    
    func startAll() {
        for task in tasks where task.isEnabled {
            startTask(task)
        }
    }
    
    func stopAll() {
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()
    }
    
    func executeTaskAsync(_ task: ScheduledTask) {
        Task.detached(priority: .userInitiated) {
            let conditionMet: Bool
            switch task.condition {
            case .bluetoothIsOn:
                conditionMet = DeviceTools.getBluetoothState().contains("开启")
            case .bluetoothIsOff:
                conditionMet = DeviceTools.getBluetoothState().contains("关闭")
            case .wifiIsOn:
                conditionMet = DeviceTools.getWiFiState().contains("开启")
            case .wifiIsOff:
                conditionMet = DeviceTools.getWiFiState().contains("关闭")
            case .always:
                conditionMet = true
            }
            guard conditionMet else { return }
            switch task.action {
            case .turnBluetoothOff: _ = DeviceTools.setBluetoothOff()
            case .turnBluetoothOn: _ = DeviceTools.setBluetoothOn()
            case .turnWifiOff: _ = DeviceTools.setWiFiOff()
            case .turnWifiOn: _ = DeviceTools.setWiFiOn()
            case .setBrightness(let level): _ = DeviceTools.setBrightness(level)
            case .setVolume(let level): _ = DeviceTools.setVolume(level)
            case .showReminder(let msg): _ = DeviceTools.showNotification(title: "提醒", body: msg)
            }
        }
    }
    
    private func loadTasks() {
        DispatchQueue.global(qos: .userInitiated).async { [storageKey] in
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let decoded = try? JSONDecoder().decode([ScheduledTask].self, from: data) else {
                return
            }
            Task { @MainActor in
                self.tasks = decoded
                self.startAll()
            }
        }
    }
    
    private func saveTasks() {
        let tasksToSave = tasks
        DispatchQueue.global(qos: .utility).async { [storageKey] in
            guard let data = try? JSONEncoder().encode(tasksToSave) else { return }
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
