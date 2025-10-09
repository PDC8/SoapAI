//
//  RecordingView.swift
//  SoapAI
//
//  Created by Jessi Avila-Shah on 3/26/25.
//

import SwiftUI

//struct RecordingView: View {
//    @StateObject private var recordingService = RecordingService()
//    @State private var transcriptionText: String = ""
//    @State private var dividedMessages: [ChatMessage] = []
//    @State private var soapReport: SOAPReport? = nil
//    @State private var timerActive = false
//    @State private var timeElapsed = 0
//    @State private var timer: Timer?
//    
//    private let transcriptionService = TranscriptionService()
//    private let clinicalReasoningService = ClinicalReasoningService()
//    
//    var body: some View {
//        ZStack {
//            Color(red: 245/255, green: 235/255, blue: 220/255)
//                .edgesIgnoringSafeArea(.all)
//            
//            ScrollView {
//                VStack(spacing: 16) {
//                    Spacer(minLength: 20)
//                    
//                    Button(action: {
//                        toggleRecording()
//                    }) {
//                        Circle()
//                            .stroke(Color.black, lineWidth: 4)
//                            .fill(timerActive ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
//                            .frame(width: 80, height: 80)
//                            .overlay(
//                                Image(systemName: "mic.fill")
//                                    .font(.system(size: 30))
//                                    .foregroundColor(.black)
//                            )
//                    }
//
//                    Text(formatTime(timeElapsed))
//                        .font(.title)
//                        .foregroundColor(.black)
//                        .padding(.top, 10)
//
//                    // Transcription text
//                    Text(transcriptionText)
//                        .font(.body)
//                        .foregroundColor(.black)
//                        .padding()
//
//                    // Divided messages
//                    LazyVStack(alignment: .leading, spacing: 8) {
//                        ForEach(dividedMessages, id: \.content) { message in
//                            HStack(alignment: .top) {
//                                Text(message.role.capitalized + ":")
//                                    .fontWeight(.bold)
//                                Text(message.content)
//                            }
//                        }
//                        .padding(.horizontal)
//                    }
//
//                    // SOAP Report
//                    if let soapReport = soapReport {
//                        VStack(alignment: .leading, spacing: 8) {
//                            Text("SOAP Report")
//                                .font(.headline)
//                            Text("Subjective: \(soapReport.subjective)")
//                            Text("Objective: \(soapReport.objective)")
//                        }
//                        .padding()
//                    }
//                    
//                    Spacer(minLength: 20)
//                }
//                .padding(.horizontal)
//            }
//        }
//    }
//    
//    private func toggleRecording() {
//        if timerActive {
//            timer?.invalidate()
//            timer = nil
//            timerActive.toggle()
//            recordingService.stopRecording()
//            
//            // When recording stops, transcribe, divide conversation, and generate the SOAP report.
//            if let fileURL = recordingService.audioFileURL {
//                Task {
//                    do {
//                        let text = try await transcriptionService.transcribeAudioFile(url: fileURL)
//                        transcriptionText = text
//                        
//                        let messages = try await clinicalReasoningService.divideConversation(text)
//                        dividedMessages = messages
//                        
//                        let report = try await clinicalReasoningService.generateSOAPReport(from: messages)
//                        soapReport = report
//                    } catch {
//                        transcriptionText = "Error: \(error.localizedDescription)"
//                    }
//                }
//            }
//        } else {
//            timeElapsed = 0
//            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
//                timeElapsed += 1
//            }
//            timerActive.toggle()
//            recordingService.startRecording()
//        }
//    }
//    
//    private func formatTime(_ totalSeconds: Int) -> String {
//        let hours = totalSeconds / 3600
//        let minutes = (totalSeconds % 3600) / 60
//        let seconds = totalSeconds % 60
//        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
//    }
//}
//
//#Preview {
//    RecordingView()
//}
