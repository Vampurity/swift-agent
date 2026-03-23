//
//  SpeechService.swift
//  swift_agent
//
//  语音输入 - 使用 macOS Speech 框架将语音转为文字
//

import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechService: ObservableObject {
    static let shared = SpeechService()
    
    @Published var isRecording = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var lastError: String?
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var lastTranscription: String = ""
    private var onResultCallback: ((String) -> Void)?
    private var resultDelivered = false
    
    private init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
    }
    
    var isAvailable: Bool {
        guard let recognizer = speechRecognizer else { return false }
        return recognizer.isAvailable && authorizationStatus == .authorized
    }
    
    func startRecording(onResult: @escaping (String) -> Void) {
        guard isAvailable else {
            lastError = authorizationStatus == .denied ? "请在系统设置中允许语音识别权限" : "语音识别不可用"
            return
        }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
        recognitionRequest.taskHint = .dictation  // 听写模式，支持较长停顿
        
        lastTranscription = ""
        resultDelivered = false
        onResultCallback = onResult
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            lastError = nil
        } catch {
            lastError = "启动录音失败: \(error.localizedDescription)"
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                if !text.isEmpty {
                    Task { @MainActor in
                        self.lastTranscription = text
                    }
                }
                // 不依赖 isFinal 自动停止，由用户手动点击停止，避免短暂停顿即结束
            }
            if error != nil {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        let partial = lastTranscription
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        lastTranscription = ""
        if !resultDelivered, !partial.isEmpty, let cb = onResultCallback {
            cb(partial)
        }
        onResultCallback = nil
        resultDelivered = false
        if UserDefaults.standard.bool(forKey: "wake_word_enabled") {
            WakeWordService.shared.startListening(onWake: { MenuBarController.shared.showPopover() })
        }
    }
}
