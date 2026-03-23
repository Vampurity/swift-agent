//
//  MemoryService.swift
//  swift_agent
//
//  记忆（经验）- 持久化存储与检索
//

import Foundation

// MARK: - 记忆类型

struct MemoryItem: Codable, Identifiable {
    let id: UUID
    let type: MemoryType
    let content: String
    let timestamp: Date
    var importance: Int
    
    enum MemoryType: String, Codable {
        case preference   // 用户偏好
        case experience   // 执行经验（成功/失败）
        case fact         // 重要事实
        case summary     // 对话摘要
    }
}

// MARK: - 记忆服务

@MainActor
class MemoryService: ObservableObject {
    static let shared = MemoryService()
    private let storageKey = "agent_memories"
    private let maxItems = 100
    
    @Published private(set) var items: [MemoryItem] = []
    
    private init() {
        load()
    }
    
    // MARK: - 添加记忆
    
    func addPreference(_ content: String) {
        add(type: .preference, content: content, importance: 3)
    }
    
    func addExperience(tool: String, success: Bool, result: String) {
        let content = success
            ? "\(tool) 执行成功: \(result)"
            : "\(tool) 执行失败: \(result)"
        add(type: .experience, content: content, importance: success ? 2 : 4)
    }
    
    func addFact(_ content: String) {
        add(type: .fact, content: content, importance: 2)
    }
    
    func addSummary(_ content: String) {
        add(type: .summary, content: content, importance: 1)
    }
    
    private func add(type: MemoryItem.MemoryType, content: String, importance: Int) {
        let item = MemoryItem(
            id: UUID(),
            type: type,
            content: content,
            timestamp: Date(),
            importance: importance
        )
        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        save()
    }
    
    // MARK: - 检索记忆
    
    /// 获取与当前对话相关的记忆，用于注入到 Agent 上下文
    func getRelevantMemory(limit: Int = 15) -> String {
        let recent = items.prefix(limit)
        guard !recent.isEmpty else { return "" }
        
        let lines = recent.map { "• \($0.content)" }
        return """
        
        【记忆/经验】
        \(lines.joined(separator: "\n"))
        """
    }
    
    /// 获取用户偏好摘要
    func getPreferencesSummary() -> String {
        let prefs = items.filter { $0.type == .preference }
        guard !prefs.isEmpty else { return "" }
        return prefs.prefix(5).map { $0.content }.joined(separator: "; ")
    }
    
    // MARK: - 持久化
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MemoryItem].self, from: data) else {
            return
        }
        items = decoded
    }
    
    private func save() {
        let itemsToSave = items
        DispatchQueue.global(qos: .utility).async { [storageKey] in
            guard let data = try? JSONEncoder().encode(itemsToSave) else { return }
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func clearAll() {
        items.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
