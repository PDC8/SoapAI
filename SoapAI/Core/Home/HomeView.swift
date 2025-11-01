//
//  HomeView.swift
//  SoapAI
//
//  Created by Cem Kupeli on 4/7/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct HomeView: View {
    @StateObject private var recordingService = RecordingService()
    @State private var dividedMessages: [ChatMessage] = []
    @State private var selectedTab = 0
    @State private var isTranscribing = false
    @State private var timeElapsed = 0
    @State private var timer: Timer?
    @State private var soReport: SOReport? = nil
    @State private var apReport: APReport? = nil
    @State private var isGeneratingSO = false
    @State private var isGeneratingAP = false
    @State private var isCheckingHallucinations = false
    @State private var hallucinationResult: HallucinationCheckResult? = nil
    @State private var hallucinationError: String? = nil
    
    // for PDF generation
    @State private var pdfURL: URL? = nil
    @State private var isExportingPDF = false
    private let pdfPageSize = CGSize(width: 612, height: 792) // 8.5 x 11"
    private let pdfMargin: CGFloat = 36 // margins 0.5"
    
    @State private var transcriptPDFURL: URL? = nil
    @State private var isExportingTranscriptPDF = false

    private func combinedSOAP() -> String {
        var parts: [String] = []
        if let so = soReport {
            parts.append("Subjective:\n\(so.subjective)\n")
            parts.append("Objective:\n\(so.objective)\n")
//            parts.append("Objective:\n\(so.objective)\nPatient has cancer.\n")
        }
        if let ap = apReport {
            parts.append("Assessment:\n\(ap.assessment)\n")
            parts.append("Plan:\n\(ap.plan)")
        }
        return parts.joined(separator: "\n")
    }

    // Build an AttributedString of SOAP with any issue spans highlighted
    private func highlightedSOAP(_ soap: String, issues: [HallucinationIssue]) -> AttributedString {
        var attr = AttributedString(soap)
        let fullString = soap

        for issue in issues {
            guard issue.start >= 0, issue.end <= fullString.count, issue.start < issue.end else { continue }

            // Convert integer offsets into AttributedString indices
            let start = attr.index(attr.startIndex, offsetByCharacters: issue.start)
            let end = attr.index(attr.startIndex, offsetByCharacters: issue.end)

            let range = start..<end
            attr[range].backgroundColor = .yellow.opacity(0.5)
        }

        return attr
    }
    
    // Clears all UI + data state from the previous session
    private func resetSessionForNewRecording() {
        // timers
        timer?.invalidate()
        timer = nil
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

        // pdf export state
        pdfURL = nil
        isExportingPDF = false

        // UI
        selectedTab = 0
    }


    // pdf generation functions
    @ViewBuilder
    private func pdfReportView(soap: String, issues: [HallucinationIssue]) -> some View {
        // Split SOAP into sections for nice headings; you’re already composing with labels.
        // We'll just draw it verbatim under a title.
        let generatedOn = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("SOAP Report")
                    .font(.title).bold()
                Text("Generated \(generatedOn)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Divider()

            // SOAP text block
            Text(soap)
                .font(.body)
                .textSelection(.enabled)

            Divider()

            // Hallucinations section
            VStack(alignment: .leading, spacing: 10) {
                Text("Hallucination Review")
                    .font(.headline)

                if issues.isEmpty {
                    Text("No hallucinations found ✅")
                        .foregroundColor(.green)
                } else {
                    ForEach(issues) { issue in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Issue")
                                .font(.subheadline).bold()
                            Text(issue.explanation)
                                .font(.body)

                            if let quote = issue.supportingTranscriptQuote, !quote.isEmpty {
                                Text("Suggested supporting quote:")
                                    .font(.caption).foregroundColor(.secondary)
                                Text("“\(quote)”")
                                    .italic().font(.caption)
                            } else {
                                Text("No direct supporting quote in transcript.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(white: 0.98))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.08)))
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }
    
    private func generatePDF(soap: String, issues: [HallucinationIssue]) throws -> URL {
        // 1) Build the report view at the target content width
        let contentWidth = pdfPageSize.width - 2 * pdfMargin
        let report = pdfReportView(soap: soap, issues: issues)
            .frame(width: contentWidth)

        // 2) Render SwiftUI view to a UIImage (off-screen; nothing appears in UI)
        let renderer = ImageRenderer(content: report)
        renderer.scale = UIScreen.main.scale // ensure crisp text

        guard let uiImage = renderer.uiImage else {
            throw NSError(domain: "PDF", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to render report view."])
        }

        // 3) Prepare PDF
        let pdfMeta: [String: Any] = [
            kCGPDFContextCreator as String: "SoapAI",
            kCGPDFContextTitle as String: "SOAP Report"
        ]
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SOAP_Report_\(UUID().uuidString).pdf")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMeta as [String: Any]

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pdfPageSize),
                                                format: format)

        // Geometry
        let contentRect = CGRect(x: pdfMargin, y: pdfMargin,
                                 width: contentWidth,
                                 height: pdfPageSize.height - 2 * pdfMargin)

        // In points (UIImage.size is in points)
        let fullImageHeightPts = uiImage.size.height
        let scalePtsToDest = uiImage.size.width / contentWidth // scale used to fit width
        let pageSliceHeightPts = contentRect.height * scalePtsToDest // how much source (pts) per page

        // Also keep pixel metrics for CGImage cropping
        let pixelScale = uiImage.scale
        let fullImageHeightPx = fullImageHeightPts * pixelScale
        let pageSliceHeightPx = pageSliceHeightPts * pixelScale
        let srcWidthPx = uiImage.size.width * pixelScale

        try pdfRenderer.writePDF(to: tmpURL) { ctx in
            var yPts: CGFloat = 0
            var yPx: CGFloat = 0

            while yPts < fullImageHeightPts - 0.5 {
                ctx.beginPage()

                // Source rect in PIXELS for CGImage cropping
                let srcPx = CGRect(
                    x: 0,
                    y: yPx.rounded(.down),
                    width: srcWidthPx.rounded(.down),
                    height: min(pageSliceHeightPx, fullImageHeightPx - yPx).rounded(.down)
                )

                if let cgImage = uiImage.cgImage?.cropping(to: srcPx.integral) {
                    // Destination height in points after width-fit scaling
                    let destHeightPts = (srcPx.height / pixelScale) / scalePtsToDest

                    let dest = CGRect(
                        x: contentRect.minX,
                        y: contentRect.minY,
                        width: contentRect.width,
                        height: destHeightPts
                    )

                    UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: .up)
                        .draw(in: dest)
                }

                yPts += pageSliceHeightPts
                yPx  += pageSliceHeightPx
            }
        }

        return tmpURL
    }

    private func exportPDF() {
        guard let so = soReport, let ap = apReport else { return }
        let soap = combinedSOAP()
        let issues = hallucinationResult?.issues ?? []

        do {
            let url = try generatePDF(soap: soap, issues: issues)
            pdfURL = url
            isExportingPDF = true
        } catch {
            print("PDF export failed:", error.localizedDescription)
        }
    }
    
    // MARK: - Transcript PDF View
    @ViewBuilder
    private func pdfTranscriptView(messages: [ChatMessage]) -> some View {
        let generatedOn = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Transcript")
                    .font(.title).bold()
                Text("Generated \(generatedOn)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Body - reusing the same message bubble styling keeps visual parity
            // For PDFs we’ll keep the background white so it prints cleanly.
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages.indices, id: \.self) { idx in
                    let m = messages[idx]
                    HStack {
                        if m.role == "doctor" { Spacer(minLength: 0) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.role.capitalized)
                                .font(.caption).bold()
                                .foregroundColor(.secondary)
                            Text(m.content)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(m.role == "doctor" ? Color.orange.opacity(0.20) : Color.blue.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        if m.role == "patient" { Spacer(minLength: 0) }
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }

    // MARK: - Transcript PDF Generator (reuse your slicing approach)
    private func generateTranscriptPDF(messages: [ChatMessage]) throws -> URL {
        let contentWidth = pdfPageSize.width - 2 * pdfMargin
        let view = pdfTranscriptView(messages: messages)
            .frame(width: contentWidth)

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale

        guard let uiImage = renderer.uiImage else {
            throw NSError(domain: "PDF", code: -11,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to render transcript to image."])
        }

        let meta: [String: Any] = [
            kCGPDFContextCreator as String: "SoapAI",
            kCGPDFContextTitle as String: "Transcript"
        ]
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Transcript_\(UUID().uuidString).pdf")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = meta as [String: Any]

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pdfPageSize), format: format)

        // Same geometry as your SOAP exporter
        let contentRect = CGRect(x: pdfMargin, y: pdfMargin,
                                 width: contentWidth,
                                 height: pdfPageSize.height - 2 * pdfMargin)

        let fullImageHeightPts = uiImage.size.height
        let scalePtsToDest = uiImage.size.width / contentWidth
        let pageSliceHeightPts = contentRect.height * scalePtsToDest

        let pixelScale = uiImage.scale
        let fullImageHeightPx = fullImageHeightPts * pixelScale
        let pageSliceHeightPx = pageSliceHeightPts * pixelScale
        let srcWidthPx = uiImage.size.width * pixelScale

        try pdfRenderer.writePDF(to: tmpURL) { ctx in
            var yPts: CGFloat = 0
            var yPx: CGFloat = 0

            while yPts < fullImageHeightPts - 0.5 {
                ctx.beginPage()

                let srcPx = CGRect(
                    x: 0,
                    y: yPx.rounded(.down),
                    width: srcWidthPx.rounded(.down),
                    height: min(pageSliceHeightPx, fullImageHeightPx - yPx).rounded(.down)
                )

                if let cgImage = uiImage.cgImage?.cropping(to: srcPx.integral) {
                    let destHeightPts = (srcPx.height / pixelScale) / scalePtsToDest
                    let dest = CGRect(x: contentRect.minX,
                                      y: contentRect.minY,
                                      width: contentRect.width,
                                      height: destHeightPts)
                    UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: .up)
                        .draw(in: dest)
                }

                yPts += pageSliceHeightPts
                yPx  += pageSliceHeightPx
            }
        }

        return tmpURL
    }

    private func exportTranscriptPDF() {
        guard !dividedMessages.isEmpty else { return }
        do {
            let url = try generateTranscriptPDF(messages: dividedMessages)
            transcriptPDFURL = url
            isExportingTranscriptPDF = true
        } catch {
            print("Transcript PDF export failed:", error.localizedDescription)
        }
    }

    
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
                    VStack(spacing: 24) {
                        Spacer(minLength: 20)
                        
                        Button {
                            if recordingService.isRecording {
                                timer?.invalidate()
                                timer = nil
                                recordingService.stopRecording()
                            } else {
                                resetSessionForNewRecording()
                                
                                timeElapsed = 0
                                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                                    timeElapsed += 1
                                }
                                
                                
                                recordingService.startRecording()
                            }
                        } label: {
                            ZStack {
                                // Fill background
                                Circle()
                                    .fill(
                                        recordingService.isRecording
                                            ? Color.red.opacity(0.3)
                                            : Color.green.opacity(0.3)
                                    )
                                // Stroke on top
                                Circle()
                                    .stroke(Color.black, lineWidth: 4)
                            }
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.black)
                            )
                        }
                        
                        Text(formatTime(timeElapsed))
                            .font(.title2)
                            .padding(.top, 8)
                        
                        if isTranscribing {
                            ProgressView("Transcribing…")
                                .padding(.top, 16)
                        }
                        
                        if !recordingService.isRecording,
                           recordingService.audioFileURL != nil,
                           dividedMessages.isEmpty
                        {
                            Button {
                                isTranscribing = true
                                Task {
                                        defer { isTranscribing = false }
                                        do {
                                            guard let url = recordingService.audioFileURL else { return }
                                            let text = try await transcriptionService.transcribeAudioFile(url: url) // returns text (log shows it does)
                                            dividedMessages = try await clinicalReasoningService.divideConversation(text) // this is where it was failing
                                            selectedTab = 1
                                        } catch {
                                            // surface it so you know what's wrong
                                            print("Transcribe failed: \(error)")
                                            // optionally bind to @State var errorMessage and show an alert/toast
                                        }
                                    }
                            } label: {
                                Text("Transcribe")
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
                            .disabled(isTranscribing)
                        }

                        Spacer()
                    }
                    .padding()
                    .tag(0)

                    // Pane 2
                    if !dividedMessages.isEmpty {
                        VStack(spacing: 24) {
                            TranscriptionView(messages: dividedMessages)
                            
                            // Export Transcript PDF
                            if !dividedMessages.isEmpty {
                                Button {
                                    exportTranscriptPDF()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.up.on.square")
                                        Text("Export Transcript PDF")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.85))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(appColor.opacity(0.7))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.black.opacity(0.15))
                                    )
                                }

                                if let tURL = transcriptPDFURL {
                                    ShareLink(item: tURL,
                                              preview: SharePreview("Transcript", image: Image(systemName: "doc.text"))) {
                                        Label("Share Transcript PDF", systemImage: "square.and.arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color.black.opacity(0.85))
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 24)
                                            .background(RoundedRectangle(cornerRadius: 12).fill(appColor.opacity(0.7)))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.15)))
                                    }
                                }

                            }

                            
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
//                                        Text(so.objective + "\nPatient has cancer.")
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
                                // Hallucination check button (appears when both SO & AP exist and no prior result)
                                if soReport != nil && apReport != nil && hallucinationResult == nil {
                                    if isCheckingHallucinations {
                                        ProgressView("Checking for hallucinations…")
                                    } else {
                                        Button("Check for hallucinations") {
                                            isCheckingHallucinations = true
                                            hallucinationError = nil
                                            Task {
                                                defer { isCheckingHallucinations = false }
                                                do {
                                                    let soap = combinedSOAP()
                                                    hallucinationResult = try await clinicalReasoningService
                                                        .checkHallucinations(soapNote: soap, transcriptMessages: dividedMessages)
                                                } catch {
                                                    hallucinationError = error.localizedDescription
                                                }
                                            }
                                        }
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color.black.opacity(0.8))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 32)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(appColor.opacity(0.6)))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.2), lineWidth: 1))
                                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                        .padding(.horizontal)
                                    }
                                }

                                // Results / Highlighted SOAP
                                if let err = hallucinationError {
                                    Text(err)
                                        .foregroundColor(.red)
                                        .padding(.horizontal)
                                } else if let result = hallucinationResult {
                                    let soap = combinedSOAP()
                                    if result.issues.isEmpty {
                                        Text("No hallucinations found ✅")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                            .padding(.horizontal)
                                    } else {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Review: Unsupported Claims")
                                                .font(.headline)
                                            // Highlighted SOAP block
//                                            ScrollView {
//                                                Text(highlightedSOAP(soap, issues: result.issues))
//                                                    .textSelection(.enabled)
//                                                    .padding(16)
//                                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
//                                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.1)))
//                                            }
                                            // List individual issues with short explanations + (optional) found quotes
                                            ForEach(result.issues) { issue in
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text("Issue").font(.subheadline).bold()
                                                    Text(issue.explanation)
                                                    if let quote = issue.supportingTranscriptQuote, !quote.isEmpty {
                                                        Text("Suggested supporting quote:")
                                                            .font(.caption).foregroundColor(.secondary)
                                                        Text("“\(quote)”").italic()
                                                            .font(.caption)
                                                    } else {
                                                        Text("No direct supporting quote in transcript.")
                                                            .font(.caption).foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(12)
                                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.08)))
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // Export button for PDF
                                if soReport != nil, apReport != nil {
                                    Button {
                                        exportPDF()
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "square.and.arrow.up.on.square")
                                            Text("Export PDF")
                                        }
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color.black.opacity(0.85))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 24)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(appColor.opacity(0.7)))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.15)))
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                }

                                // Share sheet
                                if let url = pdfURL {
                                    ShareLink(item: url, preview: SharePreview("SOAP Report", image: Image(systemName: "doc.richtext")))
                                        .onAppear { isExportingPDF = true }
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
}

#Preview {
    HomeView()
}
