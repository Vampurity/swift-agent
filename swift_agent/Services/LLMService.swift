//
//  LLMService.swift
//  swift_agent
//
//  统一 LLM 服务 - 支持 MiniMax、Kimi、DeepSeek
//

import Foundation

// MARK: - 模型提供商

enum LLMProvider: String, CaseIterable {
    case minimax = "minimax"
    case kimi = "kimi"
    case deepseek = "deepseek"
    
    var displayName: String {
        switch self {
        case .minimax: return "MiniMax"
        case .kimi: return "Kimi"
        case .deepseek: return "DeepSeek"
        }
    }
    
    var apiKeyKey: String {
        switch self {
        case .minimax: return "minimax_api_key"
        case .kimi: return "kimi_api_key"
        case .deepseek: return "deepseek_api_key"
        }
    }
    
    var baseURLKey: String {
        switch self {
        case .minimax: return "minimax_base_url"
        case .kimi: return "kimi_base_url"
        case .deepseek: return "deepseek_base_url"
        }
    }
    
    var modelKey: String {
        switch self {
        case .minimax: return "minimax_model"
        case .kimi: return "kimi_model"
        case .deepseek: return "deepseek_model"
        }
    }
    
    var defaultBaseURL: String {
        switch self {
        case .minimax: return "https://api.minimax.io"
        case .kimi: return "https://api.moonshot.ai"
        case .deepseek: return "https://api.deepseek.com"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .minimax: return "MiniMax-M2.5"
        case .kimi: return "kimi-k2.5"
        case .deepseek: return "deepseek-chat"
        }
    }
    
    /// 各提供商支持的模型列表 (id, 显示名)
    var modelOptions: [(id: String, name: String)] {
        switch self {
        case .minimax:
            return [
                ("MiniMax-M2.5", "M2.5（推荐）"),
                ("MiniMax-M2.5-highspeed", "M2.5 极速版"),
                ("MiniMax-M2.1", "M2.1"),
                ("MiniMax-M2", "M2")
            ]
        case .kimi:
            return [
                ("kimi-k2.5", "K2.5（多模态）"),
                ("kimi-k2-turbo-preview", "K2 Turbo"),
                ("kimi-k2-0905-preview", "K2 0905"),
                ("kimi-k2-0711-preview", "K2 0711"),
                ("kimi-k2-thinking", "K2 Thinking"),
                ("kimi-k2-thinking-turbo", "K2 Thinking Turbo"),
                ("moonshot-v1-128k", "Moonshot V1 128K"),
                ("moonshot-v1-32k", "Moonshot V1 32K"),
                ("moonshot-v1-8k", "Moonshot V1 8K")
            ]
        case .deepseek:
            return [
                ("deepseek-chat", "Chat（通用）"),
                ("deepseek-reasoner", "Reasoner（推理）")
            ]
        }
    }
    
    /// 该模型是否仅允许 temperature=1（如 kimi-k2.5）
    func requiresTemperatureOne(modelId: String) -> Bool {
        switch self {
        case .kimi:
            return modelId == "kimi-k2.5" || modelId.hasPrefix("kimi-k2-thinking")
        default:
            return false
        }
    }
    
    var chatEndpoint: String {
        switch self {
        case .minimax: return "/v1/text/chatcompletion_v2"
        case .kimi, .deepseek: return "/v1/chat/completions"
        }
    }
    
    var isMiniMax: Bool { self == .minimax }
}

// MARK: - 工具调用结构（复用）

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: FunctionCall
    
    struct FunctionCall: Codable {
        let name: String
        let arguments: String
    }
}

// MARK: - LLM 服务

class LLMService {
    static let shared = LLMService()
    
    var selectedProvider: LLMProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: "llm_provider") ?? LLMProvider.minimax.rawValue
            return LLMProvider(rawValue: raw) ?? .minimax
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "llm_provider")
        }
    }
    
    func apiKey(for provider: LLMProvider) -> String? {
        UserDefaults.standard.string(forKey: provider.apiKeyKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func setApiKey(_ key: String, for provider: LLMProvider) {
        UserDefaults.standard.set(key.trimmingCharacters(in: .whitespacesAndNewlines), forKey: provider.apiKeyKey)
    }
    
    func baseURL(for provider: LLMProvider) -> String {
        UserDefaults.standard.string(forKey: provider.baseURLKey) ?? provider.defaultBaseURL
    }
    
    func setBaseURL(_ url: String, for provider: LLMProvider) {
        UserDefaults.standard.set(url, forKey: provider.baseURLKey)
    }
    
    func model(for provider: LLMProvider) -> String {
        UserDefaults.standard.string(forKey: provider.modelKey) ?? provider.defaultModel
    }
    
    func setModel(_ modelId: String, for provider: LLMProvider) {
        UserDefaults.standard.set(modelId, forKey: provider.modelKey)
    }
    
    var kimiWebSearchEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "kimi_web_search_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "kimi_web_search_enabled") }
    }
    
    private init() {}
    
    func chat(messages: [[String: Any]]) async throws -> (content: String?, toolCalls: [ToolCall]?) {
        let provider = selectedProvider
        let key = apiKey(for: provider) ?? ""
        guard !key.isEmpty else {
            throw LLMError.noAPIKey
        }
        
        let baseURL = baseURL(for: provider).trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: "\(baseURL)\(provider.chatEndpoint)")!
        let modelId = model(for: provider)
        
        var tools: [[String: Any]] = ToolDefinitions.toolDefinitions
        if provider == .kimi && kimiWebSearchEnabled {
            tools.append([
                "type": "builtin_function",
                "function": ["name": "$web_search"] as [String: Any]
            ] as [String: Any])
        }
        var body: [String: Any] = [
            "model": modelId,
            "messages": messages,
            "tools": tools,
            "tool_choice": "auto",
            "max_tokens": 4096
        ]
        // Kimi 部分模型仅允许 0.6；k2.5 禁用 thinking 后也可能要求 0.6
        if provider == .kimi {
            body["temperature"] = 0.6
        } else {
            body["temperature"] = 0.7
        }
        // Kimi k2.5 启用 thinking 时，tool call 需传 reasoning_content，禁用可避免多轮工具调用报错
        if provider == .kimi && modelId == "kimi-k2.5" {
            body["thinking"] = ["type": "disabled"]
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            var errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 && provider == .kimi {
                errorStr += " 请尝试切换 API 地址：中国账户用 api.moonshot.cn，国际账户用 api.moonshot.ai"
            }
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorStr)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if provider.isMiniMax {
            if let baseResp = json?["base_resp"] as? [String: Any],
               let statusCode = baseResp["status_code"] as? Int, statusCode != 0 {
                var msg = baseResp["status_msg"] as? String ?? "Unknown"
                if statusCode == 2049 {
                    msg += " 请检查 API Key 与地址区域是否匹配"
                }
                throw LLMError.apiError(statusCode: statusCode, message: msg)
            }
        } else {
            if let error = json?["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw LLMError.apiError(statusCode: 400, message: message)
            }
        }
        
        let choices = json?["choices"] as? [[String: Any]]
        let firstChoice = choices?.first
        let message = firstChoice?["message"] as? [String: Any]
        
        var content = message?["content"] as? String ?? ""
        content = content.replacingOccurrences(of: #"<think>[\s\S]*?</think>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        var toolCalls: [ToolCall]?
        if let toolCallsArray = message?["tool_calls"] as? [[String: Any]], !toolCallsArray.isEmpty {
            toolCalls = toolCallsArray.compactMap { tc -> ToolCall? in
                guard let id = tc["id"] as? String,
                      let fn = tc["function"] as? [String: Any],
                      let name = fn["name"] as? String,
                      let args = fn["arguments"] as? String else { return nil }
                return ToolCall(id: id, type: "function", function: .init(name: name, arguments: args))
            }
        }
        
        return (content, toolCalls)
    }
}

enum LLMError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "请先在设置中配置当前模型的 API Key"
        case .invalidResponse: return "无效的 API 响应"
        case .apiError(let code, let msg): return "API 错误 (\(code)): \(msg)"
        }
    }
}
