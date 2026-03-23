# Mac Agent - 设备控制助手

基于 MiniMax M2.5 的 Mac 菜单栏 Agent 应用，具备完整认知能力：规划、记忆、感知、自我修正。

## 功能特性

- **Agent 对话**：通过文字与 AI 交互，可执行设备控制（非普通 Chatbot，能真正调用工具）
- **设备控制**：亮度、音量、蓝牙、WiFi、勿扰模式
- **定时任务**：如「每 5 秒检测蓝牙，若开启则关闭」
- **后台运行**：菜单栏常驻，无 Dock 图标（LSUIElement）

## Agent 认知架构

| 能力 | 实现 |
|------|------|
| **大脑（规划）** | 复杂任务自动分解为步骤，先规划再执行 |
| **感官（感知）** | 每次对话自动注入当前环境状态（亮度、音量、蓝牙、WiFi、时间） |
| **记忆（经验）** | 持久化存储用户偏好、工具执行经验，跨对话复用 |
| **自我修正（反思）** | 工具失败时自动反思原因并重试（最多 2 次） |

## 使用前准备

### 1. 安装 blueutil（蓝牙控制）

蓝牙开关需要 `blueutil`：

```bash
brew install blueutil
```

### 2. 配置 API Key

1. 从 [platform.minimax.io](https://platform.minimax.io) 获取 API Key
2. 运行应用后，点击菜单栏图标 → 设置 → API 标签页
3. 填入 API Key 并保存

### 3. 权限

首次使用设备控制时，系统会请求：
- **网络**：调用 MiniMax API
- **Apple Events**：用于 AppleScript 控制音量等
- **辅助功能**（可选）：用于全局快捷键 Cmd+Shift+A 唤起 Agent、粘贴文本。若快捷键无效，请在 系统设置 > 隐私与安全性 > 辅助功能 中添加本应用
- **麦克风 / 语音识别**（可选）：用于语音输入与语音唤醒「嘿 berry」。若不可用，请在 系统设置 > 隐私与安全性 中授权，并确保已启用 Siri
- **提醒事项**（可选）：用于创建提醒（如「10 分钟后提醒我」）

## 使用方式

1. **运行应用**：在 Xcode 中运行，或打开生成的 `.app`
2. **菜单栏**：顶部菜单栏出现 CPU 图标（可替换为自定义图标）
3. **快捷键**：按 Cmd+Shift+A 可快速打开 Agent 弹窗（需在辅助功能中授权）
4. **对话**：点击图标 → 输入指令，如：
   - 「把亮度调到 50%」
   - 「关闭蓝牙」
   - 「静音」
   - 「开启 WiFi」
   - 「锁屏」「打开屏保」
   - 「开启夜览」「会议模式」
   - 「把这段话复制到剪贴板」「粘贴刚才复制的内容」
   - 「10 分钟后提醒我」「明天 9 点提醒开会」
   - 「每天早上 9 点关闭蓝牙」「每 30 分钟提醒我休息」
   - 「运行我的『开始工作』快捷指令」
5. **语音输入**：点击输入框旁的麦克风图标，说话即可转为文字指令（需授权麦克风与语音识别）
6. **语音唤醒**：设置 → 开启「语音唤醒」后，说「嘿，berry」即可弹出 Agent 界面，全程本地离线识别（设备支持时）
7. **场景模式**：设置 → 场景模式 → 一键应用工作/会议/睡眠模式
8. **记忆管理**：设置 → 记忆 → 可清除 Agent 存储的经验与偏好
9. **定时任务**：设置 → 定时任务 → 添加，或通过自然语言创建，例如：
   - 名称：每 5 秒关蓝牙
   - 间隔：5 秒
   - 条件：蓝牙开启时
   - 动作：关闭蓝牙
   - 或自然语言：「每天早上 9 点关闭蓝牙」「每 30 分钟提醒我休息」

## 项目结构

```
swift_agent/
├── Services/
│   ├── DeviceTools.swift      # 设备控制工具（亮度、音量、蓝牙、WiFi、锁屏、屏保、夜览、剪贴板、通知、提醒、快捷指令等）
│   ├── SpeechService.swift   # 语音输入（Speech-to-Text）
│   ├── WakeWordService.swift # 语音唤醒「嘿 berry」（本地离线）
│   ├── MiniMaxService.swift   # MiniMax API 与 Tool Calling
│   ├── TaskScheduler.swift   # 定时任务调度
│   ├── PerceptionService.swift # 感官 - 环境状态感知（含电池、存储、CPU）
│   ├── PresetService.swift    # 场景模式 - 工作/会议/睡眠预设
│   └── MemoryService.swift   # 记忆 - 经验与偏好持久化
├── Views/
│   ├── AgentChatView.swift  # Agent 对话界面
│   ├── SettingsView.swift  # 设置（API Key、定时任务）
│   └── MenuBarView.swift   # 菜单栏与 Popover
└── swift_agentApp.swift  # 应用入口
```

## 图标

- **菜单栏图标**：当前为 SF Symbol `cpu.fill`，可替换为单色模板图
- **应用图标**：使用默认，可自行替换 `Assets.xcassets/AppIcon.appiconset`

## 技术说明

- **平台**：macOS 13.7+
- **模型**：MiniMax-M2.5（支持 Tool Use）
- **架构**：SwiftUI + AppKit（NSStatusItem）
