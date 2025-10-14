//
//  RealtimeTranscription.swift
//  SoapAI
//
//  Created by Vinni Yu on 10/6/25.
//

import Foundation
import AVFoundation
import Speech


// MARK: - Listener protocol for UI updates
protocol SpeechTranscriptionListener: AnyObject {
    func onPartialTranscript(_ text: String)        // live updates
    func onFinalTranscript(_ text: String)          // final transcript
    func onStatusChange(isTranscribing: Bool)       // started/stopped
    func onError(_ error: Error)                    // surfaced errors
}

final class SpeechTranscriptionService: NSObject {
    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    weak var listener: SpeechTranscriptionListener?
    private(set) var isTranscribing = false

    // choose your default locale here
    init(locale: Locale = Locale(identifier: "en-US")) {
        // fallback to the system default
        recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()!
        super.init()
    }

    enum ServiceError: Error, LocalizedError {
        case permissionDenied
        case recognizerUnavailable
        case engineNotReady
        case onDeviceNotSupported(locale: String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Speech/Microphone permission denied."
            case .recognizerUnavailable: return "Speech recognizer is currently unavailable."
            case .engineNotReady: return "Audio engine not ready."
            case .onDeviceNotSupported(let l): return "On-device recognition not supported for \(l)."
            }
        }
    }

    // request mic + speech permissions.
    func requestPermissions(requireOnDevice: Bool = false, completion: @escaping (Result<Void, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { auth in
            DispatchQueue.main.async {
                guard auth == .authorized else {
                    completion(.failure(ServiceError.permissionDenied)); return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            completion(.failure(ServiceError.permissionDenied)); return
                        }
                        if requireOnDevice && !self.recognizer.supportsOnDeviceRecognition {
                            completion(.failure(ServiceError.onDeviceNotSupported(locale: self.recognizer.locale.identifier)))
                        } else {
                            completion(.success(()))
                        }
                    }
                }
            }
        }
    }

    // start live transcription (partials + finals).
    // force on-device if supported (privacy/offline). falls back to server if false.
    func start(requireOnDevice: Bool = false) throws {
        guard !isTranscribing else { return }
        guard recognizer.isAvailable else { throw ServiceError.recognizerUnavailable }

        // cancel any prior task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // configure audio session for capture
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // build the streaming request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13, *) { request.requiresOnDeviceRecognition = requireOnDevice }
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let error = error {
                self.listener?.onError(error)
                self.listener?.onStatusChange(isTranscribing: false)
                return
            }

            guard let result = result else { return }

            // partial updates
            let text = result.bestTranscription.formattedString
            if !text.isEmpty {
                self.listener?.onPartialTranscript(text)
            }

            // final update
            if result.isFinal {
                self.listener?.onFinalTranscript(text)
            }
        }

        // mic tap → feed buffers to the request
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        
        // 2048 for low latency. typical range 1028-4096
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isTranscribing = true
        listener?.onStatusChange(isTranscribing: true)
    }

    // stop and finalize the current session
    func stop() {
        guard isTranscribing else { return }
        recognitionRequest?.endAudio()

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {}

        isTranscribing = false
        listener?.onStatusChange(isTranscribing: false)
    }

    // cancel immediately
    func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
        stop()
    }

    // change language/region mid-app (use when switching locales)
    func updateLocale(_ locale: Locale) {
        if let new = SFSpeechRecognizer(locale: locale) {
            recognizer = new
        }
    }
}


