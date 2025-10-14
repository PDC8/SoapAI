//
//  HomeView.swift
//  SoapAI
//
//  Created by Cem Kupeli on 4/7/25.
//

import SwiftUI

import SwiftUI

struct HomeView: View {
//    @StateObject private var recordingService = RecordingService()
    @State private var dividedMessages: [ChatMessage] = []
    @State private var selectedTab = 0
    @State private var isTranscribing = false
    @State private var timeElapsed = 0
    @State private var timer: Timer?
    @State private var soReport: SOReport? = nil
    @State private var apReport: APReport? = nil
    @State private var isGeneratingSO = false
    @State private var isGeneratingAP = false
    @StateObject private var st = SpeechTranscriptionVM()


    
    private var safeSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { new in
                if (new == 1 && dividedMessages.isEmpty)
                 || (new == 2 && soReport == nil) { return }
                selectedTab = new
            }
        )
    }
    
    private let transcriptionService = TranscriptionService()
    private let clinicalReasoningService = ClinicalReasoningService()
    
    let appColor = Color(red: 245/255, green: 235/255, blue: 220/255)

    var body: some View {
        ZStack {
            appColor
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                TabView(selection: safeSelection) {
                    // Pane 1
                    VStack(spacing: 16) {
                        Spacer(minLength: 20)

                        // start/stop
                        Button(st.isTranscribing ? "Stop" : "Start") {
                            if st.isTranscribing {
                                st.stop()
                            } else {
                                st.requestPermissions(requireOnDevice: true) { ok in
                                    st.finalLines.removeAll()
                                    st.partialText = ""
                                    if ok { st.start(requireOnDevice: true) }
                                }
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((st.isTranscribing ? Color.red.opacity(0.2) : Color.green.opacity(0.2)))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // live transcript
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Live Transcription").font(.headline).foregroundStyle(.black)
                                    Spacer()
                                    if st.isTranscribing {
                                        Text("Listening…").font(.subheadline).foregroundStyle(.green)
                                    } else {
                                        Text("Idle").font(.subheadline).foregroundStyle(.black)
                                    }
                                }

                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(st.finalLines.enumerated()), id: \.offset) { _, line in
                                            Text(line).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.black)
                                        }
                                        if st.finalLines.isEmpty {
                                            Text("Tap Start and speak to see live text…")
                                                .foregroundStyle(.black)
                                        }
                                    }
                                    .padding(12)
                                }

                                // clear button
                                HStack {
                                    Button("Clear") {
                                        st.finalLines.removeAll()
                                        st.partialText = ""
                                    }
                                    .disabled(st.finalLines.isEmpty && st.partialText.isEmpty)
                                    Spacer()
                                }
                            }
                            .frame(width: 360, height: 360) // fixed width box
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.6)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.15), lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity) // center horizontally

                        Spacer()
                    }
                    .padding()
                    .tag(0)



                    // Pane 2
                    if !dividedMessages.isEmpty {
                        VStack(spacing: 24) {
                            TranscriptionView(messages: dividedMessages)
                            
                            if !dividedMessages.isEmpty && soReport == nil {
                                if isGeneratingSO {
                                    ProgressView("Generating report…")
                                        .padding(.top, 16)
                                }
                                
                                Button {
                                    isGeneratingSO = true
                                    Task {
                                        defer { isGeneratingSO = false }
                                        soReport = try await clinicalReasoningService.generateSOReport(from: dividedMessages)
                                        selectedTab = 2
                                    }
                                } label: {
                                    Text("Generate Report")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color.black.opacity(0.8))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 32)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(appColor.opacity(0.6))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                        .padding(.top, 16)
                                }
                                .disabled(isGeneratingSO)
                            }

                            Spacer()
                        }
                        .padding()
                        .tag(1)
                    }

                    // Pane 3
                    if soReport != nil {
                        ScrollView {
                            VStack(spacing: 24) {
                                // SO card
                                if let so = soReport {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Subjective:").font(.headline)
                                        Text(so.subjective)
                                        Text("Objective:").font(.headline)
                                        Text(so.objective)
                                    }
                                    .padding(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    .padding(.horizontal)
                                }

                                // Generate AP button
                                if soReport != nil && apReport == nil {
                                    if isGeneratingAP {
                                        ProgressView("Generating AP…")
                                    }
                                    Button("Generate Assessment & Plan") {
                                        isGeneratingAP = true
                                        Task {
                                            defer { isGeneratingAP = false }
                                            apReport = try await clinicalReasoningService.generateAPReport(from: dividedMessages)
                                        }
                                    }
                                    .disabled(isGeneratingAP)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.8))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(appColor.opacity(0.6))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                    .padding(.horizontal)
                                    .padding(.top, 16)
                                }

                                // AP card
                                if let ap = apReport {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Assessment:").font(.headline)
                                        Text(ap.assessment)
                                        Text("Plan:").font(.headline)
                                        Text(ap.plan)
                                    }
                                    .padding(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 20)
                        }
                        .tag(2)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: selectedTab)

                Divider()
                    .background(Color.black)
                    .padding(.bottom, 10)

                // Bottom navbar
                HStack {
                    Spacer()
                    navButton(systemName: "microphone", index: 0)
                    Spacer()
                    Spacer()
                    navButton(systemName: "text.bubble", index: 1)
                    Spacer()
                    Spacer()
                    navButton(systemName: "doc.plaintext", index: 2)
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(appColor.ignoresSafeArea(edges: .bottom))
            }
        }
    }
    
    @ViewBuilder
    private func navButton(systemName: String, index: Int) -> some View {
        Button { selectedTab = index } label: {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(selectedTab == index ? .blue : .gray)
        }
        .disabled((index == 1 && dividedMessages.isEmpty)
               || (index == 2 && soReport == nil))
        .opacity(((index == 1 && dividedMessages.isEmpty)
               || (index == 2 && soReport == nil)) ? 0.5 : 1)
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func fetchEphemeralRealtimeToken() async throws -> String {
        var req = URLRequest(url: URL(string: "https://yourserver.example.com/realtime-token")!)
        req.httpMethod = "POST"
        let (data, _) = try await URLSession.shared.data(for: req)
        struct TokenResp: Decodable { let token: String }
        return try JSONDecoder().decode(TokenResp.self, from: data).token
    }
}

#Preview {
    HomeView()
}
