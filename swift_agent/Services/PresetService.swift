//
//  PresetService.swift
//  swift_agent
//
//  场景模式 - 一键执行预设的设备状态组合
//

import Foundation

// MARK: - 预设模型

struct Preset: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let actions: [PresetAction]
    
    init(id: String, name: String, actions: [PresetAction]) {
        self.id = id
        self.name = name
        self.actions = actions
    }
}

enum PresetAction: Codable, Equatable {
    case setBrightness(Float)
    case setVolume(Float)
    case setMuted(Bool)
    case setBluetooth(Bool)
    case setWiFi(Bool)
    case setDoNotDisturb(Bool)
    case setNightShift(Bool)
    
    var displayName: String {
        switch self {
        case .setBrightness(let v): return "亮度 \(Int(v * 100))%"
        case .setVolume(let v): return "音量 \(Int(v * 100))%"
        case .setMuted(let m): return m ? "静音" : "取消静音"
        case .setBluetooth(let on): return on ? "开启蓝牙" : "关闭蓝牙"
        case .setWiFi(let on): return on ? "开启 WiFi" : "关闭 WiFi"
        case .setDoNotDisturb(let on): return on ? "开启勿扰" : "关闭勿扰"
        case .setNightShift(let on): return on ? "开启夜览" : "关闭夜览"
        }
    }
}

// MARK: - 预设服务

@MainActor
class PresetService: ObservableObject {
    static let shared = PresetService()
    
    /// 内置预设
    static let builtinPresets: [Preset] = [
        Preset(id: "meeting", name: "会议模式", actions: [
            .setMuted(true),
            .setDoNotDisturb(true),
            .setBluetooth(false)
        ]),
        Preset(id: "work", name: "工作模式", actions: [
            .setBrightness(0.7),
            .setDoNotDisturb(false),
            .setVolume(0.5)
        ]),
        Preset(id: "sleep", name: "睡眠模式", actions: [
            .setMuted(true),
            .setDoNotDisturb(true),
            .setBluetooth(false),
            .setBrightness(0.2)
        ])
    ]
    
    @Published var presets: [Preset] = builtinPresets
    
    private init() {}
    
    /// 执行预设
    func apply(_ preset: Preset) -> [String] {
        var results: [String] = []
        for action in preset.actions {
            let result: String
            switch action {
            case .setBrightness(let level):
                result = DeviceTools.setBrightness(level)
            case .setVolume(let level):
                result = DeviceTools.setVolume(level)
            case .setMuted(let muted):
                result = DeviceTools.setMuted(muted)
            case .setBluetooth(let on):
                result = on ? DeviceTools.setBluetoothOn() : DeviceTools.setBluetoothOff()
            case .setWiFi(let on):
                result = on ? DeviceTools.setWiFiOn() : DeviceTools.setWiFiOff()
            case .setDoNotDisturb(let enabled):
                result = DeviceTools.setDoNotDisturb(enabled)
            case .setNightShift(let enabled):
                result = DeviceTools.setNightShift(enabled)
            }
            results.append(result)
        }
        return results
    }
}
