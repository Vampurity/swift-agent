//
//  MiniMaxService.swift
//  swift_agent
//
//  工具定义 - 供 LLMService 等使用的 Agent 工具列表
//

import Foundation

// MARK: - 工具定义

enum ToolDefinitions {
    static let toolDefinitions: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "set_brightness",
                "description": "设置屏幕亮度。参数 level 为 0.0 到 1.0 之间的浮点数。",
                "parameters": [
                    "type": "object",
                    "properties": ["level": ["type": "number", "description": "亮度 0.0-1.0"]],
                    "required": ["level"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "get_brightness",
                "description": "获取当前屏幕亮度。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "set_volume",
                "description": "设置系统音量。参数 level 为 0.0 到 1.0 之间的浮点数。",
                "parameters": [
                    "type": "object",
                    "properties": ["level": ["type": "number", "description": "音量 0.0-1.0"]],
                    "required": ["level"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "get_volume",
                "description": "获取当前系统音量。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "set_muted",
                "description": "设置静音状态。",
                "parameters": [
                    "type": "object",
                    "properties": ["muted": ["type": "boolean", "description": "是否静音"]],
                    "required": ["muted"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "get_bluetooth_state",
                "description": "获取蓝牙开关状态。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "set_bluetooth_on",
                "description": "开启蓝牙。需要安装 blueutil: brew install blueutil",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "set_bluetooth_off",
                "description": "关闭蓝牙。需要安装 blueutil: brew install blueutil",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "toggle_bluetooth",
                "description": "切换蓝牙开关状态。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "get_wifi_state",
                "description": "获取 WiFi 开关状态。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "set_wifi_on",
                "description": "开启 WiFi。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "set_wifi_off",
                "description": "关闭 WiFi。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "toggle_wifi",
                "description": "切换 WiFi 开关状态。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "get_do_not_disturb_state",
                "description": "获取勿扰模式状态。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "set_do_not_disturb",
                "description": "设置勿扰模式。",
                "parameters": [
                    "type": "object",
                    "properties": ["enabled": ["type": "boolean", "description": "是否开启勿扰"]],
                    "required": ["enabled"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "perceive_environment",
                "description": "感知当前环境状态（亮度、音量、蓝牙、WiFi、勿扰、时间）。在需要了解当前设备状态时调用。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "remember",
                "description": "将重要信息存入长期记忆，如用户偏好、重要事实。用于跨对话记忆。",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "content": ["type": "string", "description": "要记住的内容，如「用户偏好亮度70%」"],
                        "type": ["type": "string", "enum": ["preference", "fact"], "description": "preference=用户偏好, fact=重要事实"]
                    ] as [String: Any],
                    "required": ["content"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "open_app",
                "description": "打开 macOS 自带或已安装的应用。支持中英文名称，如：Terminal/终端、Finder/访达、Safari、Notes/备忘录、Mail/邮件、Calendar/日历、Calculator/计算器、Siri、System Settings/系统设置 等。",
                "parameters": [
                    "type": "object",
                    "properties": ["app_name": ["type": "string", "description": "应用名称，如 Terminal、Siri、备忘录"]],
                    "required": ["app_name"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "lock_screen",
                "description": "锁定屏幕。用户说「锁屏」「锁定电脑」时调用。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "start_screensaver",
                "description": "启动屏保。用户说「打开屏保」「启动屏保」时调用。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "get_night_shift_state",
                "description": "获取夜览模式状态。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "set_night_shift",
                "description": "设置夜览模式。用户说「开启夜览」「关闭夜览」时调用。",
                "parameters": [
                    "type": "object",
                    "properties": ["enabled": ["type": "boolean", "description": "是否开启夜览"]],
                    "required": ["enabled"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "apply_preset",
                "description": "一键应用场景模式。meeting=会议模式(静音+勿扰+关蓝牙)，work=工作模式(亮度70%+关勿扰+音量50%)，sleep=睡眠模式(静音+勿扰+关蓝牙+低亮度)。",
                "parameters": [
                    "type": "object",
                    "properties": ["preset_id": ["type": "string", "description": "预设ID: meeting, work, sleep"]],
                    "required": ["preset_id"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "get_clipboard",
                "description": "获取剪贴板中的文本内容。用户说「粘贴刚才复制的内容」「看看剪贴板有什么」时调用。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "set_clipboard",
                "description": "将文本复制到剪贴板。用户说「把这段话复制到剪贴板」「复制xxx」时调用。",
                "parameters": [
                    "type": "object",
                    "properties": ["text": ["type": "string", "description": "要复制到剪贴板的文本"]],
                    "required": ["text"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "paste_text",
                "description": "将剪贴板内容粘贴到当前焦点位置。用户说「粘贴」「粘贴刚才复制的内容」时调用。",
                "parameters": ["type": "object", "properties": [:], "required": [] as [String]]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "show_notification",
                "description": "发送系统通知。用户说「提醒我」「发个通知」时调用。",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string", "description": "通知标题，默认「提醒」"],
                        "body": ["type": "string", "description": "通知内容"]
                    ] as [String: Any],
                    "required": ["body"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "create_reminder",
                "description": "创建提醒事项。支持「10 分钟后提醒我」「明天 9 点提醒开会」等。due_date 可为「10分钟后」「明天9点」或 ISO 时间。",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string", "description": "提醒标题"],
                        "due_date": ["type": "string", "description": "可选，如「10分钟后」「明天9点」「09:00」"]
                    ] as [String: Any],
                    "required": ["title"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "run_shortcut",
                "description": "运行 macOS 快捷指令。用户说「运行我的『开始工作』快捷指令」「执行xxx快捷指令」时调用。",
                "parameters": [
                    "type": "object",
                    "properties": ["shortcut_name": ["type": "string", "description": "快捷指令名称"]],
                    "required": ["shortcut_name"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "function": [
                "name": "create_scheduled_task",
                "description": "用自然语言创建定时任务。例如「每天早上 9 点关闭蓝牙」「每 30 分钟提醒我休息」。schedule_type: interval=按间隔秒数, daily=每天固定时刻。action: turn_bluetooth_off, turn_bluetooth_on, turn_wifi_off, turn_wifi_on, set_brightness, set_volume, show_reminder。daily_time 格式 HH:mm。",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "任务名称"],
                        "schedule_type": ["type": "string", "enum": ["interval", "daily"], "description": "interval=每N秒, daily=每天固定时刻"],
                        "interval_seconds": ["type": "integer", "description": "间隔秒数，schedule_type=interval 时使用"],
                        "daily_time": ["type": "string", "description": "每日时刻 HH:mm，如 09:00，schedule_type=daily 时使用"],
                        "condition": ["type": "string", "description": "触发条件: always, bluetooth_is_on, bluetooth_is_off, wifi_is_on, wifi_is_off"],
                        "action": ["type": "string", "description": "动作"],
                        "level": ["type": "number", "description": "set_brightness/set_volume 时的 0-1 值"],
                        "message": ["type": "string", "description": "show_reminder 时的提醒内容"]
                    ] as [String: Any],
                    "required": ["name", "action"]
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any]
    ]
}
