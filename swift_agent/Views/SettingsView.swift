//
//  SettingsView.swift
//  swift_agent
//
//  设置界面 - API Key、定时任务
//

import SwiftUI
import AppKit

private struct AddTaskSheetTrigger: Identifiable {
    let id = UUID()
}

struct SettingsView: View {
    @StateObject private var presetService = PresetService.shared
    @AppStorage("llm_provider") private var selectedProvider = LLMProvider.minimax.rawValue
    @AppStorage("minimax_api_key") private var minimaxApiKey = ""
    @AppStorage("kimi_api_key") private var kimiApiKey = ""
    @AppStorage("deepseek_api_key") private var deepseekApiKey = ""
    @AppStorage("minimax_base_url") private var apiBaseURL = "https://api.minimax.io"
    @AppStorage("kimi_base_url") private var kimiBaseURL = "https://api.moonshot.ai"
    @AppStorage("minimax_model") private var minimaxModel = "MiniMax-M2.5"
    @AppStorage("kimi_model") private var kimiModel = "kimi-k2.5"
    @AppStorage("deepseek_model") private var deepseekModel = "deepseek-chat"
    @AppStorage("kimi_web_search_enabled") private var kimiWebSearchEnabled = false
    @AppStorage("wake_word_enabled") private var wakeWordEnabled = false
    @StateObject private var wakeWordService = WakeWordService.shared
    @StateObject private var scheduler = TaskScheduler.shared
    @State private var addTaskSheetId: AddTaskSheetTrigger?
    @State private var newTaskName = ""
    @State private var newTaskInterval = 5
    @State private var newTaskCondition: TaskCondition = .bluetoothIsOn
    @State private var newTaskAction: TaskAction = .turnBluetoothOff
    
    var body: some View {
        TabView {
            // API Key 设置
            Form {
                Section {
                    Picker("模型", selection: $selectedProvider) {
                        ForEach(LLMProvider.allCases, id: \.rawValue) { p in
                            Text(p.displayName).tag(p.rawValue)
                        }
                    }
                    .onChange(of: selectedProvider) { newVal in
                        LLMService.shared.selectedProvider = LLMProvider(rawValue: newVal) ?? .minimax
                    }
                    
                    if selectedProvider == LLMProvider.minimax.rawValue {
                        Picker("模型版本", selection: $minimaxModel) {
                            ForEach(LLMProvider.minimax.modelOptions, id: \.id) { opt in
                                Text(opt.name).tag(opt.id)
                            }
                        }
                        .onChange(of: minimaxModel) { LLMService.shared.setModel($0, for: .minimax) }
                        SecureField("MiniMax API Key", text: $minimaxApiKey)
                            .onChange(of: minimaxApiKey) { newValue in
                                LLMService.shared.setApiKey(newValue.trimmingCharacters(in: .whitespacesAndNewlines), for: .minimax)
                            }
                        Picker("API 地址", selection: $apiBaseURL) {
                            Text("api.minimax.io（默认）").tag("https://api.minimax.io")
                            Text("api.minimaxi.chat（国际）").tag("https://api.minimaxi.chat")
                            Text("api.minimaxi.com（中国）").tag("https://api.minimaxi.com")
                        }
                        .onChange(of: apiBaseURL) { newValue in
                            LLMService.shared.setBaseURL(newValue, for: .minimax)
                        }
                        Text("2049 错误时请尝试切换 API 地址，确保与 Key 区域匹配")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if selectedProvider == LLMProvider.kimi.rawValue {
                        Picker("模型版本", selection: $kimiModel) {
                            ForEach(LLMProvider.kimi.modelOptions, id: \.id) { opt in
                                Text(opt.name).tag(opt.id)
                            }
                        }
                        .onChange(of: kimiModel) { LLMService.shared.setModel($0, for: .kimi) }
                        Toggle("联网搜索", isOn: $kimiWebSearchEnabled)
                        Text("开启后 Agent 可搜索实时信息，每次搜索约 $0.005 费用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("Kimi API Key", text: $kimiApiKey)
                            .onChange(of: kimiApiKey) { newValue in
                                LLMService.shared.setApiKey(newValue.trimmingCharacters(in: .whitespacesAndNewlines), for: .kimi)
                            }
                        Picker("API 地址", selection: $kimiBaseURL) {
                            Text("api.moonshot.ai（国际）").tag("https://api.moonshot.ai")
                            Text("api.moonshot.cn（中国）").tag("https://api.moonshot.cn")
                        }
                        .onChange(of: kimiBaseURL) { newValue in
                            LLMService.shared.setBaseURL(newValue, for: .kimi)
                        }
                        Text("401 错误时请切换 API 地址：中国账户用 .cn，国际账户用 .ai")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if selectedProvider == LLMProvider.deepseek.rawValue {
                        Picker("模型版本", selection: $deepseekModel) {
                            ForEach(LLMProvider.deepseek.modelOptions, id: \.id) { opt in
                                Text(opt.name).tag(opt.id)
                            }
                        }
                        .onChange(of: deepseekModel) { LLMService.shared.setModel($0, for: .deepseek) }
                        SecureField("DeepSeek API Key", text: $deepseekApiKey)
                            .onChange(of: deepseekApiKey) { newValue in
                                LLMService.shared.setApiKey(newValue.trimmingCharacters(in: .whitespacesAndNewlines), for: .deepseek)
                            }
                        Text("使用 api.deepseek.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("API 配置")
                }
                Section {
                    Toggle("语音唤醒「hey berry」", isOn: $wakeWordEnabled)
                        .onChange(of: wakeWordEnabled) { enabled in
                            if enabled {
                                WakeWordService.shared.startListening(onWake: {
                                    MenuBarController.shared.showPopover()
                                })
                            } else {
                                WakeWordService.shared.stopListening()
                            }
                        }
                    Text(wakeWordService.isAvailable
                         ? "说「hey berry」即可弹出 Agent 界面（需网络）"
                         : "若无法开启，请到 系统设置 > 隐私与安全性 中授权麦克风与语音识别，并确保已启用 Siri")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let err = wakeWordService.lastError, !err.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                            if let detail = wakeWordService.lastErrorDetail, !detail.isEmpty {
                                Text("诊断: \(detail)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                } header: {
                    Text("语音唤醒")
                }
            }
            .formStyle(.columns)
            .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .padding(24)
            .tabItem { Label("API", systemImage: "key.fill") }
            .onAppear {
                WakeWordService.shared.refreshAvailability()
                if WakeWordService.shared.isAvailable && wakeWordEnabled && !WakeWordService.shared.isListening {
                    WakeWordService.shared.startListening(onWake: { MenuBarController.shared.showPopover() })
                }
                // 确保 API Key、Base URL、模型版本同步到 LLMService
                let k = minimaxApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                if !k.isEmpty { LLMService.shared.setApiKey(k, for: .minimax) }
                let k2 = kimiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                if !k2.isEmpty { LLMService.shared.setApiKey(k2, for: .kimi) }
                let k3 = deepseekApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                if !k3.isEmpty { LLMService.shared.setApiKey(k3, for: .deepseek) }
                LLMService.shared.setBaseURL(apiBaseURL, for: .minimax)
                LLMService.shared.setBaseURL(kimiBaseURL, for: .kimi)
                LLMService.shared.setModel(minimaxModel, for: .minimax)
                LLMService.shared.setModel(kimiModel, for: .kimi)
                LLMService.shared.setModel(deepseekModel, for: .deepseek)
            }
            
            // 定时任务
            VStack(spacing: 0) {
                List {
                    ForEach(scheduler.tasks) { task in
                        TaskRowView(task: task, scheduler: scheduler)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                
                Button(action: { addTaskSheetId = AddTaskSheetTrigger() }) {
                    Label("添加定时任务", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .tabItem { Label("定时任务", systemImage: "clock.fill") }
            
            // 场景模式
            VStack(spacing: 20) {
                Text("一键切换设备状态组合")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
                
                ForEach(presetService.presets) { preset in
                    PresetCardView(preset: preset)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("场景模式", systemImage: "square.grid.2x2.fill") }
            
            // 记忆管理
            Form {
                Section {
                    Text("Agent 会记住用户偏好、执行经验等，用于改进后续对话。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    Button(role: .destructive) {
                        MemoryService.shared.clearAll()
                    } label: {
                        Label("清除所有记忆", systemImage: "trash")
                    }
                } header: {
                    Text("记忆")
                }
            }
            .formStyle(.columns)
            .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .padding(24)
            .tabItem { Label("记忆", systemImage: "brain.head.profile") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow))
        .sheet(item: $addTaskSheetId) { _ in
            AddTaskSheet(
                name: $newTaskName,
                interval: $newTaskInterval,
                condition: $newTaskCondition,
                action: $newTaskAction,
                onSave: {
                    let task = ScheduledTask(
                        name: newTaskName.isEmpty ? "定时任务" : newTaskName,
                        intervalSeconds: newTaskInterval,
                        condition: newTaskCondition,
                        action: newTaskAction
                    )
                    scheduler.addTask(task)
                    newTaskName = ""
                    newTaskInterval = 5
                    newTaskCondition = .bluetoothIsOn
                    newTaskAction = .turnBluetoothOff
                    addTaskSheetId = nil
                },
                onCancel: { addTaskSheetId = nil }
            )
        }
    }
}

struct PresetCardView: View {
    let preset: Preset
    @State private var isApplying = false
    @State private var lastResult: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                    Text(preset.actions.map { $0.displayName }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: applyPreset) {
                    if isApplying {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("应用")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isApplying)
            }
            if let result = lastResult {
                Text(result)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
    
    private func applyPreset() {
        isApplying = true
        lastResult = nil
        Task { @MainActor in
            let results = PresetService.shared.apply(preset)
            lastResult = results.joined(separator: "; ")
            isApplying = false
        }
    }
}

struct TaskRowView: View {
    let task: ScheduledTask
    @ObservedObject var scheduler: TaskScheduler
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.name)
                    .font(.headline)
                Text(task.scheduleType == .daily
                     ? "每天 \(task.dailyTime ?? "?") · \(task.condition.displayName) → \(task.action.displayName)"
                     : "每 \(task.intervalSeconds) 秒 · \(task.condition.displayName) → \(task.action.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { task.isEnabled },
                set: { _ in scheduler.toggleTask(task) }
            ))
            Button(role: .destructive) {
                scheduler.removeTask(task)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

enum TaskActionOption: String, CaseIterable {
    case turnBluetoothOff = "关闭蓝牙"
    case turnBluetoothOn = "开启蓝牙"
    case turnWifiOff = "关闭 WiFi"
    case turnWifiOn = "开启 WiFi"
    case setBrightness = "设置亮度 50%"
    case setVolume = "设置音量 50%"
    
    var action: TaskAction {
        switch self {
        case .turnBluetoothOff: return .turnBluetoothOff
        case .turnBluetoothOn: return .turnBluetoothOn
        case .turnWifiOff: return .turnWifiOff
        case .turnWifiOn: return .turnWifiOn
        case .setBrightness: return .setBrightness(0.5)
        case .setVolume: return .setVolume(0.5)
        }
    }
}

/// 使用 NSTextField 包装，正确支持中文输入法（IME）组合输入。
private struct IMECompatibleTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = NSColor.controlBackgroundColor
        // 延迟聚焦，避免在 viewWillDraw 等绘制阶段调用导致 "should not be called on main thread" 报错
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard field.window != nil else { return }
            field.window?.makeFirstResponder(field)
        }
        return field
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // 用户正在编辑（含 IME 选字）时不要覆盖，否则会打断中文输入法选字
        if nsView.currentEditor() != nil { return }
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: IMECompatibleTextField
        
        init(_ parent: IMECompatibleTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                parent.text = field.stringValue
            }
        }
    }
}

struct AddTaskSheet: View {
    @Binding var name: String
    @Binding var interval: Int
    @Binding var condition: TaskCondition
    @Binding var action: TaskAction
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var selectedActionOption: TaskActionOption = .turnBluetoothOff
    
    private let conditions: [TaskCondition] = [.bluetoothIsOn, .bluetoothIsOff, .wifiIsOn, .wifiIsOff, .always]
    
    var body: some View {
        VStack(spacing: 24) {
            Text("添加定时任务")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("任务名称")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                IMECompatibleTextField(text: $name, placeholder: "例如：每 5 秒关蓝牙")
                    .frame(height: 28)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.bottom, 8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("执行间隔（秒）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Stepper("", value: $interval, in: 1...3600)
                    Text("\(interval) 秒")
                        .frame(width: 60, alignment: .trailing)
                        .font(.body)
                }
                .padding(.bottom, 8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("触发条件")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $condition) {
                    ForEach(conditions, id: \.self) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .padding(.bottom, 8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("执行动作")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $selectedActionOption) {
                    ForEach(TaskActionOption.allCases, id: \.self) { a in
                        Text(a.rawValue).tag(a)
                    }
                }
                .pickerStyle(.menu)
                .padding(.bottom, 8)
            }
            
            HStack(spacing: 16) {
                Button("取消", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("添加") {
                    action = selectedActionOption.action
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(width: 400)
    }
}

#Preview {
    SettingsView()
}
