//
//  HomeViewModel.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/15/25.
//

import Foundation
import PDFKit

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Services
    let recordingService = RecordingService()
    private let transcriptionService = TranscriptionService()
    private let clinicalReasoningService = ClinicalReasoningService()

    // MARK: - Top-level UI state
    @Published var selectedTab: Int = 0

    // MARK: - Recording / transcription
    @Published var dividedMessages: [ChatMessage] = []
    @Published var isTranscribing: Bool = false
    @Published var timeElapsed: Int = 0
    
    @Published var isRecording: Bool = false
    @Published var hasAudioFile: Bool = false

    private var timer: Timer?
    
    // MARK: - Patient data (from presheet)
    @Published var presheetRawText: String? = nil
    @Published var patientData: PatientDataModel? = nil

    // MARK: - SOAP reports
    @Published var visitSummary: VisitSummary?
    
    @Published var soReport: SOReport?
    @Published var apReport: APReport?
    @Published var emotionAnalysis: EmotionAnalysisResult? = nil

    @Published var isGeneratingSO: Bool = false
    @Published var isGeneratingAP: Bool = false

    // MARK: - Hallucination checking
    @Published var isCheckingHallucinations: Bool = false
    @Published var hallucinationResult: HallucinationCheckResult?
    @Published var hallucinationError: String?

    // MARK: - Lifecycle
    init() {}

    // MARK: - Public API used by the view

    func toggleRecording() {
        if recordingService.isRecording {
            stopRecording()
            isRecording = false
            hasAudioFile = recordingService.audioFileURL != nil
        } else {
            startNewRecording()
            isRecording = true
            hasAudioFile = false
        }
    }

    func handleTranscribeTapped() async {
        guard !isTranscribing,
              !recordingService.isRecording,
              recordingService.audioFileURL != nil else { return }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            guard let url = recordingService.audioFileURL else { return }
            let text = try await transcriptionService.transcribeAudioFile(url: url)
            dividedMessages = try await clinicalReasoningService.divideConversation(text)
            selectedTab = 1
        } catch {
            // Later we can surface this as a user-visible alert
            print("Transcribe failed: \(error)")
        }
    }
    
    func generateVisitSummary() async {
        // only require transcript, presheet is optional
        guard !dividedMessages.isEmpty else { return }
        guard visitSummary == nil else { return }

        do {
            visitSummary = try await clinicalReasoningService.generateVisitSummary(
                patient: patientData,                 // can be nil
                conversationMessages: dividedMessages
            )
        } catch {
            print("Visit summary generation failed: \(error)")
        }
    }



    func generateSOReport() async {
        guard !dividedMessages.isEmpty, soReport == nil else { return }

        isGeneratingSO = true
        defer { isGeneratingSO = false }

        do {
            soReport = try await clinicalReasoningService.generateSOReport(from: dividedMessages)
            selectedTab = 2
        } catch {
            print("SO generation failed: \(error)")
        }
    }

    func generateAPReport() async {
        guard !dividedMessages.isEmpty, soReport != nil, apReport == nil else { return }

        isGeneratingAP = true
        defer { isGeneratingAP = false }

        do {
            apReport = try await clinicalReasoningService.generateAPReport(from: dividedMessages)
        } catch {
            print("AP generation failed: \(error)")
        }
    }

    func checkHallucinations() async {
        guard soReport != nil,
              apReport != nil,
              hallucinationResult == nil else { return }

        isCheckingHallucinations = true
        hallucinationError = nil
        defer { isCheckingHallucinations = false }

        do {
            let soap = combinedSOAP()
            hallucinationResult = try await clinicalReasoningService
                .checkHallucinations(soapNote: soap, transcriptMessages: dividedMessages)
        } catch {
            hallucinationError = error.localizedDescription
        }
    }
    
    func runEmotionAnalysis() async {
        guard !dividedMessages.isEmpty else { return }

        do {
            let result = try await clinicalReasoningService.analyzePatientEmotions(
                from: dividedMessages
            )
            await MainActor.run {
                self.emotionAnalysis = result
            }
        } catch {
            print("Emotion analysis failed: \(error)")
        }
    }
    
    func resetSessionForNewRecording() {
        // timers
        stopTimer()
        timeElapsed = 0

        // conversation + reports
        dividedMessages = []
        soReport = nil
        apReport = nil

        // hallucination state
        isCheckingHallucinations = false
        hallucinationResult = nil
        hallucinationError = nil

        // generation flags
        isTranscribing = false
        isGeneratingSO = false
        isGeneratingAP = false

        // tab
        selectedTab = 0
    }

    // MARK: - Helpers exposed to the view

    func combinedSOAP() -> String {
        var parts: [String] = []
        if let so = soReport {
            parts.append("Subjective:\n\(so.subjective)\n")
            parts.append("Objective:\n\(so.objective)\n")
        }
        if let ap = apReport {
            parts.append("Assessment:\n\(ap.assessment)\n")
            parts.append("Plan:\n\(ap.plan)")
        }
        return parts.joined(separator: "\n")
    }

    func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func handlePresheetPDFData(_ data: Data) {
        guard let text = extractTextFromPDF(data: data) else {
            print("Failed to extract text from PDF")
            return
        }

        DispatchQueue.main.async {
            self.presheetRawText = text

            // For now, keep parsing minimal 
            self.patientData = PresheetParser.parse(from: text)
        }
    }

    // MARK: - Private helpers

    private func startNewRecording() {
        resetSessionForNewRecording()
        timeElapsed = 0

        // timer on main run loop
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timeElapsed += 1
        }

        recordingService.startRecording()
    }

    private func stopRecording() {
        stopTimer()
        recordingService.stopRecording()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
