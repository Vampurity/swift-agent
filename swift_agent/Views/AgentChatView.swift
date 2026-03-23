//
//  AgentChatView.swift
//  swift_agent
//
//  Agent 聊天界面 - 文字交互，支持设备控制
//

import SwiftUI

struct AgentChatView: View {
    @StateObject private var viewModel = AgentViewModel()
    @ObservedObject private var speechService = SpeechService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.messages) { msg in
                            MessageRow(message: msg)
                                .id(msg.id)
                        }
                        if viewModel.isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .scaleEffect(0.9)
                                Text("思考中...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            
            // 输入框 - 居中对齐
            HStack(alignment: .center, spacing: 14) {
                TextField("输入指令，例如：把亮度调到 50%、关闭蓝牙", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    .lineLimit(1...5)
                    .onSubmit { viewModel.send() }
                
                Button(action: { viewModel.toggleVoiceInput() }) {
                    Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                        .font(.title2)
                        .foregroundStyle(speechService.isRecording ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                .help(speechService.isRecording ? "点击停止录音" : "语音输入")
                
                Button(action: { viewModel.send() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .clearAgentConversation)) { _ in
            viewModel.clearConversation()
        }
    }
}

struct MessageRow: View {
    let message: ChatMessageItem
    
    private var roleIcon: String {
        switch message.role {
        case "user": return "person.circle.fill"
        case "tool": return "wrench.and.screwdriver.fill"
        default: return "cpu.fill"
        }
    }
    
    private var roleLabel: String {
        switch message.role {
        case "user": return "你"
        case "tool": return "工具"
        default: return "Agent"
        }
    }
    
    private var roleColor: Color {
        switch message.role {
        case "user": return .blue
        case "tool": return .orange
        default: return .green
        }
    }
    
    private var roleBackground: Color {
        switch message.role {
        case "user": return Color.blue.opacity(0.08)
        case "tool": return Color.orange.opacity(0.08)
        default: return Color.green.opacity(0.08)
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: roleIcon)
                .foregroundStyle(roleColor)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(roleLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                if let content = message.content, !content.isEmpty {
                    Text(content)
                        .font(.body)
                        .textSelection(.enabled)
                }
                
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    ForEach(toolCalls, id: \.id) { tc in
                        HStack(spacing: 6) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.caption)
                            Text("调用 \(tc.function.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(roleBackground)
        .cornerRadius(14)
    }
}

// MARK: - ViewModel

struct ChatMessageItem: Identifiable {
    let id = UUID()
    let role: String
    let content: String?
    let toolCalls: [ToolCall]?
}

@MainActor
class AgentViewModel: ObservableObject {
    @Published var messages: [ChatMessageItem] = []
    @Published var inputText = ""
    @Published var isLoading = false
    
    private var conversationHistory: [[String: Any]] = []
    private let maxRetryOnFailure = 2
    private var retryCount = 0
    
    private func buildSystemPrompt() async -> String {
        let memory = await MainActor.run { MemoryService.shared.getRelevantMemory() }
        let perception = await Task.detached(priority: .userInitiated) {
            PerceptionService.perceiveEnvironment()
        }.value
        return """
        你是一个具有完整认知能力的 Mac 设备控制 Agent，具备以下能力：
        
        【大脑 - 规划】面对复杂任务时，先在心里或输出中规划步骤，再逐步执行。例如「调暗屏幕并静音」应分解为：1) set_brightness 2) set_muted。
        
        【感官 - 感知】当前环境状态已提供如下，你可随时调用 perceive_environment 刷新：
        \(perception)
        \(memory)
        
        【工具】亮度、音量、蓝牙、WiFi、勿扰模式、打开应用(open_app)、锁屏(lock_screen)、屏保(start_screensaver)、夜览(get_night_shift_state, set_night_shift)、场景模式(apply_preset: meeting/work/sleep)、剪贴板(get_clipboard, set_clipboard, paste_text)、通知(show_notification)、提醒(create_reminder)、快捷指令(run_shortcut)、定时任务(create_scheduled_task)。设备控制必须调用工具执行。open_app 可打开 Terminal/终端、Finder/访达、Safari、Siri、备忘录、邮件、日历、计算器等 macOS 应用。用户问「电量」「电脑卡不卡」「存储空间」时，环境感知已包含电池、CPU、存储信息。
        
        【自我修正 - 反思】当工具返回失败时，分析原因（如参数错误、需安装 blueutil），尝试替代方案或向用户说明。失败经验会被记录以改进后续行为。
        
        执行完工具后，用简洁中文确认结果。
        """
    }
    
    func toggleVoiceInput() {
        let speech = SpeechService.shared
        if speech.isRecording {
            speech.stopRecording()
        } else {
            WakeWordService.shared.stopListening()
            speech.startRecording { [weak self] text in
                guard let self = self else { return }
                self.inputText = text
                self.send()
            }
        }
    }
    
    func clearConversation() {
        messages.removeAll()
        conversationHistory.removeAll()
    }
    
    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        messages.append(ChatMessageItem(role: "user", content: text, toolCalls: nil))
        
        isLoading = true
        retryCount = 0
        Task {
            let perception = await Task.detached(priority: .userInitiated) {
                PerceptionService.perceiveEnvironment()
            }.value
            let userContent = "\(perception)\n\n【用户指令】\(text)"
            conversationHistory.append(["role": "user", "content": userContent])
            await processAgentResponse()
        }
    }
    
    private func processAgentResponse() async {
        defer { isLoading = false }
        
        let systemPrompt = await buildSystemPrompt()
        var messagesToSend = conversationHistory
        if messagesToSend.first?["role"] as? String != "system" {
            messagesToSend.insert(["role": "system", "content": systemPrompt], at: 0)
        }
        
        do {
            let (content, toolCalls) = try await LLMService.shared.chat(messages: messagesToSend)
            
            let rawContent = content ?? ""
            let displayContent: String?
            if rawContent.isEmpty, let toolCalls = toolCalls, !toolCalls.isEmpty {
                displayContent = "正在执行: \(toolCalls.map { $0.function.name }.joined(separator: ", "))"
            } else {
                displayContent = rawContent.isEmpty ? nil : rawContent
            }
            let assistantItem = ChatMessageItem(role: "assistant", content: displayContent, toolCalls: toolCalls)
            messages.append(assistantItem)
            
            var assistantMsg: [String: Any] = ["role": "assistant"]
            if !rawContent.isEmpty {
                assistantMsg["content"] = rawContent
            }
            if let toolCalls = toolCalls, !toolCalls.isEmpty {
                assistantMsg["tool_calls"] = toolCalls.map { tc in
                    [
                        "id": tc.id,
                        "type": "function",
                        "function": [
                            "name": tc.function.name,
                            "arguments": tc.function.arguments
                        ] as [String: Any]
                    ] as [String: Any]
                }
            }
            conversationHistory.append(assistantMsg)
            
            if let toolCalls = toolCalls, !toolCalls.isEmpty {
                var hasFailure = false
                
                for tc in toolCalls {
                    let result: String
                    if tc.function.name == "$web_search" {
                        // Kimi 内置联网搜索：直接返回参数，由 Kimi 服务端执行搜索
                        result = tc.function.arguments
                    } else {
                        let args = (try? JSONSerialization.jsonObject(with: Data(tc.function.arguments.utf8)) as? [String: Any]) ?? [:]
                        result = await Task.detached(priority: .userInitiated) {
                            await DeviceTools.execute(toolName: tc.function.name, arguments: args)
                        }.value
                    }
                    
                    let isSuccess = !result.contains("失败") && !result.lowercased().contains("error") && !result.contains("无法")
                    if tc.function.name != "$web_search" {
                        Task { @MainActor in
                            MemoryService.shared.addExperience(tool: tc.function.name, success: isSuccess, result: result)
                        }
                    }
                    if !isSuccess { hasFailure = true }
                    
                    conversationHistory.append([
                        "role": "tool",
                        "tool_call_id": tc.id,
                        "content": result
                    ])
                    let displayContent = tc.function.name == "$web_search" ? "🌐 联网搜索中…" : "🔧 \(tc.function.name): \(result)"
                    messages.append(ChatMessageItem(role: "tool", content: displayContent, toolCalls: nil))
                }
                
                if hasFailure && retryCount < maxRetryOnFailure {
                    retryCount += 1
                    conversationHistory.append([
                        "role": "user",
                        "content": "【系统-反思提示】上述部分工具执行失败。请分析原因（如参数错误、需安装 blueutil）并尝试：1) 修正后重试 2) 使用替代方法 3) 向用户说明。"
                    ])
                }
                
                await processAgentResponse()
            }
        } catch {
            messages.append(ChatMessageItem(role: "assistant", content: "错误: \(error.localizedDescription)", toolCalls: nil))
        }
    }
}

#Preview {
    AgentChatView()
}
