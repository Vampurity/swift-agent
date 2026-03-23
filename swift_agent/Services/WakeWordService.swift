//
//  WakeWordService.swift
//  swift_agent
//
//  语音唤醒 - 本地离线持续监听「嘿 berry」，检测到后弹出界面
//

import Foundation
import Speech
import AVFoundation

/// 唤醒词服务：持续监听麦克风，检测到「嘿 berry」时触发回调。全程本地离线。
@MainActor
class WakeWordService: ObservableObject {
    static let shared = WakeWordService()
    
    @Published var isListening = false
    @Published var isAvailable = false
    @Published var isOnDeviceSupported = false
    @Published var lastError: String?
    /// 详细错误信息，用于诊断：domain、code、描述
    @Published var lastErrorDetail: String?
    
    /// 唤醒词匹配：包含「嘿/hey」且包含「berry」（不区分大小写）
    private let wakePhraseCheck: (String) -> Bool = { text in
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        let hasHey = t.contains("嘿") || t.contains("hey")
        let hasBerry = t.contains("berry") || t.contains("贝瑞") || t.contains("贝里") || t.contains("贝利")
        return hasHey && hasBerry
    }
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasTapInstalled = false
    /// 使用 en-US 避免 zh-CN 触发本地识别 1101 报错；唤醒词 "hey berry" 仍可识别
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var onWakeDetected: (() -> Void)?
    private var shouldKeepListening = false
    private var consecutiveFailureCount = 0
    private let maxConsecutiveFailures = 10
    private var isSwappingTask = false
    private init() {
        SFSpeechRecognizer.requestAuthorization { [weak self] _ in
            Task { @MainActor in
                self?.updateAvailability()
                // 授权完成后，若用户曾开启语音唤醒则自动开始监听
                if self?.isAvailable == true,
                   UserDefaults.standard.bool(forKey: "wake_word_enabled"),
                   self?.isListening == false {
                    self?.startListening(onWake: { MenuBarController.shared.showPopover() })
                }
            }
        }
    }
    
    /// 刷新可用性状态（如从系统设置授权后返回时调用）
    func refreshAvailability() {
        updateAvailability()
    }

    private func updateAvailability() {
        let auth = SFSpeechRecognizer.authorizationStatus()
        let recognizerAvailable = speechRecognizer?.isAvailable ?? false
        isOnDeviceSupported = speechRecognizer?.supportsOnDeviceRecognition ?? false
        isAvailable = (auth == .authorized) && recognizerAvailable
        if !isAvailable && auth != .notDetermined {
            lastError = auth == .denied ? "需要语音识别权限" : (recognizerAvailable ? "" : "语音识别不可用，请确保已启用 Siri")
        }
    }
    
    /// 开始监听唤醒词，检测到「嘿 berry」时调用 onWake
    func startListening(onWake: @escaping () -> Void) {
        guard !isListening else { return }
        updateAvailability()
        guard isAvailable else {
            lastError = lastError ?? "语音识别不可用，请检查权限并确保已启用 Siri"
            return
        }
        onWakeDetected = onWake
        shouldKeepListening = true
        isListening = true
        lastError = nil
        lastErrorDetail = nil
        consecutiveFailureCount = 0
        startRecognitionSession()
    }
    
    func stopListening() {
        shouldKeepListening = false
        stopCurrentSession()
        isListening = false
    }
    
    private func startRecognitionSession() {
        guard shouldKeepListening else { return }
        guard let recognizer = speechRecognizer else {
            isListening = false
            lastError = "语音识别不可用，请确保已启用 Siri"
            return
        }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            lastErrorDetail = "AVAudioEngine 创建失败"
            lastError = "音频引擎创建失败"
            consecutiveFailureCount += 1
            handleSessionFailure()
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            lastErrorDetail = "SFSpeechAudioBufferRecognitionRequest 创建失败"
            lastError = "识别请求创建失败"
            consecutiveFailureCount += 1
            handleSessionFailure()
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        recognitionRequest.taskHint = .search
        recognitionRequest.contextualStrings = ["hey berry", "hey Barry", "hey very"]
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        hasTapInstalled = true
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            lastErrorDetail = "麦克风启动失败: \((error as NSError).localizedDescription)"
            lastError = "麦克风启动失败: \(error.localizedDescription)"
            consecutiveFailureCount += 1
            handleSessionFailure()
            return
        }
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                if !text.isEmpty && self.wakePhraseCheck(text) {
                    Task { @MainActor in
                        self.consecutiveFailureCount = 0
                        self.onWakeDetected?()
                        self.swapRecognitionTaskWithoutStoppingEngine()
                    }
                    return
                }
                if result.isFinal {
                    Task { @MainActor in
                        self.consecutiveFailureCount = 0
                        self.swapRecognitionTaskWithoutStoppingEngine()
                    }
                    return
                }
            }
            if let err = error, !self.isSwappingTask, !self.isCancelledError(err) {
                if self.isLocalRecognitionUnavailableError(err) { return }
                Task { @MainActor in
                    self.recordAndHandleError(err, from: "startRecognitionSession")
                }
            }
        }
    }
    
    private func isCancelledError(_ err: Error) -> Bool {
        let nsErr = err as NSError
        return nsErr.domain == "NSCocoaErrorDomain" && nsErr.code == 2048
            || nsErr.localizedDescription.lowercased().contains("cancel")
    }

    /// 1101 = 本地识别不可用（如中文模型未下载），应忽略并避免重试
    private func isLocalRecognitionUnavailableError(_ err: Error) -> Bool {
        let nsErr = err as NSError
        return nsErr.domain == "kAFAssistantErrorDomain" && nsErr.code == 1101
    }

    /// 记录错误详情并处理（首次失败即展示，便于诊断）
    private func recordAndHandleError(_ err: Error, from context: String) {
        let nsErr = err as NSError
        let detail = "domain: \(nsErr.domain), code: \(nsErr.code), \(nsErr.localizedDescription)"
        lastErrorDetail = detail
        #if DEBUG
        print("[WakeWord] \(context) 错误: \(detail)")
        if !nsErr.userInfo.isEmpty {
            print("[WakeWord] userInfo: \(nsErr.userInfo)")
        }
        #endif
        consecutiveFailureCount += 1
        swapRecognitionTaskOrStopOnTooManyFailures(lastError: err)
    }
    
    /// 仅替换识别任务，麦克风持续开启，避免控制中心显示反复开关
    private func swapRecognitionTaskWithoutStoppingEngine() {
        guard shouldKeepListening, let recognizer = speechRecognizer, let audioEngine = audioEngine else {
            stopCurrentSession()
            isListening = false
            return
        }
        let oldRequest = recognitionRequest
        let oldTask = recognitionTask
        isSwappingTask = true
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = false
        newRequest.taskHint = .search
        newRequest.contextualStrings = ["hey berry", "hey Barry", "hey very"]
        recognitionRequest = newRequest
        recognitionTask = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                if !text.isEmpty && self.wakePhraseCheck(text) {
                    Task { @MainActor in
                        self.consecutiveFailureCount = 0
                        self.onWakeDetected?()
                        self.swapRecognitionTaskWithoutStoppingEngine()
                    }
                    return
                }
                if result.isFinal {
                    Task { @MainActor in
                        self.consecutiveFailureCount = 0
                        self.swapRecognitionTaskWithoutStoppingEngine()
                    }
                    return
                }
            }
            if let err = error, !self.isSwappingTask, !self.isCancelledError(err) {
                if self.isLocalRecognitionUnavailableError(err) { return }
                Task { @MainActor in
                    self.recordAndHandleError(err, from: "swapRecognitionTask")
                }
            }
        }
        oldRequest?.endAudio()
        oldTask?.cancel()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.isSwappingTask = false
        }
    }
    
    private func swapRecognitionTaskOrStopOnTooManyFailures(lastError: Error? = nil) {
        guard shouldKeepListening else {
            stopCurrentSession()
            isListening = false
            return
        }
        if consecutiveFailureCount >= maxConsecutiveFailures {
            isListening = false
            let errMsg = (lastError as NSError?)?.localizedDescription ?? ""
            self.lastError = "语音识别异常\(errMsg.isEmpty ? "" : ": \(errMsg)")"
            stopCurrentSession()
            return
        }
        swapRecognitionTaskWithoutStoppingEngine()
    }
    
    private func handleSessionFailure() {
        stopCurrentSession()
        guard shouldKeepListening else {
            isListening = false
            return
        }
        if consecutiveFailureCount >= maxConsecutiveFailures {
            isListening = false
            lastError = "语音识别异常。请检查：1) 系统设置 > Siri 已开启 2) 网络连接正常 3) 关闭后重新开启语音唤醒"
            return
        }
        let delayMs = min(1000 * UInt64(1 << min(consecutiveFailureCount, 4)), 8000)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            if self.shouldKeepListening {
                self.startRecognitionSession()
            }
        }
    }
    
    private func stopCurrentSession() {
        if hasTapInstalled {
            audioEngine?.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
}
