//
//  RealtimeVM.swift
//  SoapAI
//
//  Created by Vinni Yu on 10/6/25.
//

import Foundation
import Combine

final class SpeechTranscriptionVM: ObservableObject, SpeechTranscriptionListener {
    @Published var isTranscribing = false
    @Published var partialText: String = ""
    @Published var finalLines: [String] = []

    private var lastAcceptedPartial: String = ""
    private var partialDebounceTimer: Timer?

    let service = SpeechTranscriptionService()

    init() {
        service.listener = self
    }

    func requestPermissions(requireOnDevice: Bool = false, onDone: @escaping (Bool) -> Void) {
        service.requestPermissions(requireOnDevice: requireOnDevice) { result in
            switch result {
            case .success: onDone(true)
            case .failure(let err):
                print("Permissions error:", err.localizedDescription)
                onDone(false)
            }
        }
    }

    func start(requireOnDevice: Bool = false) {
        do {
            try service.start(requireOnDevice: requireOnDevice)
        } catch {
            print("Start error:", error.localizedDescription)
        }
    }

    func stop()   { service.stop() }
    func cancel() { service.cancel() }

    // MARK: - Listener
    private func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitCurrentPartial() {
        let t = norm(partialText)
        guard !t.isEmpty else { return }
        if let last = finalLines.last, norm(last) == t {
            // already committed same words - keep one line
            finalLines[finalLines.count - 1] = t
        } else {
            finalLines.append(t)
        }
        partialText = ""
    }
    
    func onPartialTranscript(_ text: String) {
        partialText = text

        partialDebounceTimer?.invalidate()
        partialDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.commitCurrentPartial()
        }
    }


    func onFinalTranscript(_ text: String) {
        partialDebounceTimer?.invalidate()
        let t = norm(text)
        guard !t.isEmpty else { return }

        // if just committed a partial, replace that last line with the final
        if let last = finalLines.last {
            if norm(last) == t || (!partialText.isEmpty && norm(partialText) == t) {
                finalLines[finalLines.count - 1] = text
                partialText = ""
                return
            }
        }

        // if nothing similar was just committed, append once
        finalLines.append(text)
        partialText = ""
    }

    
    func onStatusChange(isTranscribing: Bool) {
        self.isTranscribing = isTranscribing
        if !isTranscribing {
            partialDebounceTimer?.invalidate()
            partialDebounceTimer = nil
        }
    }


    func onError(_ error: Error) { print("ASR error:", error.localizedDescription) }
}
