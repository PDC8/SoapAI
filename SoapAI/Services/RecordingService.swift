//
//  STT.swift
//  SoapAI
//
//  Created by Shomari Smith on 3/26/25.
//

import Foundation
import AVFoundation
import Combine

class RecordingService: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var audioFileURL: URL?
    @Published var error: Error?

    private var audioRecorder: AVAudioRecorder?
    
    override init() {
        super.init()
        requestRecordPermission()
    }
    
    /// Requests microphone access from the user.
    private func requestRecordPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            guard allowed else {
                DispatchQueue.main.async {
                    self?.error = NSError(
                        domain: "RecordingService",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Microphone permission not granted"]
                    )
                }
                return
            }
        }
    }
    
    /// Starts recording audio and saves it to a temporary file.
    func startRecording() {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            self.error = error
            return
        }
        
        // Create a file URL in the temporary directory
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Define recording settings (using AAC, 44.1 kHz, stereo)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            isRecording = true
            audioFileURL = fileURL
        } catch {
            self.error = error
        }
    }
    
    /// Stops the recording.
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }
}

extension RecordingService: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            self.error = error
        }
    }
}
