import SwiftUI
import UIKit   // for UIImage

@MainActor
final class PDFExportService {
    static let shared = PDFExportService()

    // 8.5 x 11" at 72 dpi
    private let pdfPageSize = CGSize(width: 612, height: 792)
    private let pdfMargin: CGFloat = 36

    private init() {}

    // MARK: - Public API

    func exportSOAP(
        soReport: SOReport,
        apReport: APReport,
        visitSummary: VisitSummary?,
        patientData: PatientDataModel?,
        issues: [HallucinationIssue]
    ) throws -> URL {
        let contentWidth = pdfPageSize.width - 2 * pdfMargin

        let view = SoapReportPDFView(
            soReport: soReport,
            apReport: apReport,
            visitSummary: visitSummary,
            patientData: patientData,
            issues: issues
        )
        .frame(width: contentWidth)

        return try renderPagedPDF(
            from: view,
            title: "SOAP Report",
            filenamePrefix: "SOAP_Report"
        )
    }
    
    func exportVectorSOAP(
        soReport: SOReport,
        apReport: APReport,
        visitSummary: VisitSummary?,
        patientData: PatientDataModel?,
        issues: [HallucinationIssue],
        emotionAnalysis: EmotionAnalysisResult?
    ) throws -> URL {
        let meta: [String: Any] = [
            kCGPDFContextCreator as String: "SoapAI",
            kCGPDFContextTitle  as String: "SOAP Report"
        ]

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SOAP_Report_\(UUID().uuidString).pdf")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = meta

        let pdfRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pdfPageSize),
            format: format
        )

        try pdfRenderer.writePDF(to: url) { ctx in
            drawSOAPReport(
                in: ctx,
                soReport: soReport,
                apReport: apReport,
                visitSummary: visitSummary,
                patientData: patientData,
                issues: issues,
                emotionAnalysis: emotionAnalysis
            )
        }

        return url
    }
    
    private func drawSOAPReport(
        in ctx: UIGraphicsPDFRendererContext,
        soReport: SOReport,
        apReport: APReport,
        visitSummary: VisitSummary?,
        patientData: PatientDataModel?,
        issues: [HallucinationIssue],
        emotionAnalysis: EmotionAnalysisResult?
    ) {
        let margin = pdfMargin
        let contentWidth = pdfPageSize.width - 2 * margin
        let maxContentHeight = pdfPageSize.height - 2 * margin

        var cursorY = margin

        func beginNewPageIfNeeded(for height: CGFloat) {
            if cursorY + height > margin + maxContentHeight {
                ctx.beginPage()
                cursorY = margin
            }
        }

        func drawHeader() {
            ctx.beginPage()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold)
            ]
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]

            let title = "SOAP Report" as NSString
            let titleSize = title.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: titleAttrs,
                context: nil
            ).size

            title.draw(
                in: CGRect(x: margin, y: cursorY, width: contentWidth, height: titleSize.height),
                withAttributes: titleAttrs
            )
            cursorY += titleSize.height + 4

            let generatedOn = DateFormatter.localizedString(
                from: Date(),
                dateStyle: .medium,
                timeStyle: .short
            )
            let subtitle = "Generated \(generatedOn)" as NSString
            let subtitleSize = subtitle.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: subtitleAttrs,
                context: nil
            ).size

            subtitle.draw(
                in: CGRect(x: margin, y: cursorY, width: contentWidth, height: subtitleSize.height),
                withAttributes: subtitleAttrs
            )
            cursorY += subtitleSize.height + 16
        }

        func drawSection(title: String, body: String) {
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.label
            ]

            // Measure body height
            let bodyNSString = trimmed as NSString
            let bodySize = bodyNSString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: bodyAttrs,
                context: nil
            ).size

            // Title height
            let titleNSString = title as NSString
            let titleSize = titleNSString.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: titleAttrs,
                context: nil
            ).size

            let neededHeight = titleSize.height + 4 + bodySize.height + 12
            beginNewPageIfNeeded(for: neededHeight)

            // Draw title
            titleNSString.draw(
                in: CGRect(x: margin, y: cursorY, width: contentWidth, height: titleSize.height),
                withAttributes: titleAttrs
            )
            cursorY += titleSize.height + 4

            // Draw body
            bodyNSString.draw(
                in: CGRect(x: margin, y: cursorY, width: contentWidth, height: bodySize.height),
                withAttributes: bodyAttrs
            )
            cursorY += bodySize.height + 12
        }

        // ---------- Actual content ----------

        drawHeader()

        // Visit Summary (matches SummaryCard / NotePane style)
        if let summary = visitSummary {
            drawSection(title: "Visit Summary", body: summary.oneLine)
        }

        // SUBJECTIVE: matches SubjectiveCard structure
        do {
            var subjectiveLines: [String] = []

            // main subjective text
            subjectiveLines.append(soReport.subjective)

            if let patientData = patientData {
                // Past Medical History
                if let pmh = patientData.pastMedicalHistory, !pmh.isEmpty {
                    subjectiveLines.append("")
                    subjectiveLines.append("Past Medical History:")
                    for item in pmh {
                        subjectiveLines.append("• \(item)")
                    }
                }

                // Allergies
                if let allergies = patientData.allergies, !allergies.isEmpty {
                    subjectiveLines.append("")
                    subjectiveLines.append("Allergies:")
                    for item in allergies {
                        subjectiveLines.append("• \(item)")
                    }
                }

                // Medications
                if let meds = patientData.medications, !meds.isEmpty {
                    subjectiveLines.append("")
                    subjectiveLines.append("Medications:")
                    for item in meds {
                        subjectiveLines.append("• \(item)")
                    }
                }
            }

            drawSection(
                title: "Subjective",
                body: subjectiveLines.joined(separator: "\n")
            )
        }

        // OBJECTIVE: matches ObjectiveCard structure
        do {
            var objectiveLines: [String] = []

            if let vitals = patientData?.vitals, !vitals.isEmpty {
                objectiveLines.append("Vitals:")
                for v in vitals {
                    objectiveLines.append("• \(v)")
                }
                objectiveLines.append("") // blank line before PE
            }

            objectiveLines.append("Physical Exam")
            let o = soReport.objective
            objectiveLines.append("HEENT: \(o.HEENT)")
            objectiveLines.append("Lungs: \(o.lungs)")
            objectiveLines.append("Heart: \(o.heart)")
            objectiveLines.append("Abdomen: \(o.abdomen)")
            objectiveLines.append("Extremities: \(o.extremities)")
            objectiveLines.append("Neuro: \(o.neuro)")
            objectiveLines.append("Other: \(o.other)")

            drawSection(
                title: "Objective",
                body: objectiveLines.joined(separator: "\n")
            )
        }

        // ASSESSMENT: matches APCard top half
        drawSection(title: "Assessment", body: apReport.assessment)

        // PLAN: matches APCard bullet structure
        do {
            var planText = ""
            for problem in apReport.plan {
                planText += "\(problem.problem):\n"
                for action in problem.actions {
                    planText += "  • \(action)\n"
                }
                planText += "\n"
            }
            drawSection(
                title: "Plan",
                body: planText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        
        // EMOTION:
        if let emotion = emotionAnalysis {
            var lines: [String] = []

            // Overall bullets
            if !emotion.summaryBullets.isEmpty {
                lines.append("Overall emotional impressions:")
                for bullet in emotion.summaryBullets {
                    lines.append("• \(bullet)")
                }
            }

            // Trajectory
            if !emotion.moments.isEmpty {
                if !lines.isEmpty { lines.append("") }
                lines.append("Emotional trajectory:")
                for moment in emotion.moments {
                    let phase = moment.phase.capitalized
                    let label = moment.emotion.capitalized
                    lines.append("\(phase): \(label)")
                    lines.append("  \(moment.description)")
                    lines.append("")
                }
            }

            let body = lines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !body.isEmpty {
                drawSection(
                    title: "Patient Emotional Tone",
                    body: body
                )
            }
        }

        // HALLUCINATIONS: keep your current logic, styled like a section
        if !issues.isEmpty {
            var issuesText = ""
            for (idx, issue) in issues.enumerated() {
                issuesText += "\(idx + 1). \(issue.explanation)\n"
                if let quote = issue.supportingTranscriptQuote, !quote.isEmpty {
                    issuesText += "   Suggested supporting quote: “\(quote)”\n"
                }
                issuesText += "\n"
            }
            drawSection(
                title: "Hallucination Review",
                body: issuesText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }





    func exportTranscript(messages: [ChatMessage]) throws -> URL {
        let contentWidth = pdfPageSize.width - 2 * pdfMargin
        let view = TranscriptPDFView(messages: messages)
            .frame(width: contentWidth)

        return try renderPagedPDF(
            from: view,
            title: "Transcript",
            filenamePrefix: "Transcript"
        )
    }

    // MARK: - Core renderer

    private func renderPagedPDF<V: View>(
        from view: V,
        title: String,
        filenamePrefix: String
    ) throws -> URL {
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale

        guard let uiImage = renderer.uiImage else {
            throw NSError(
                domain: "PDF",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to render \(title) view."]
            )
        }

        let meta: [String: Any] = [
            kCGPDFContextCreator as String: "SoapAI",
            kCGPDFContextTitle  as String: title
        ]

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filenamePrefix)_\(UUID().uuidString).pdf")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = meta

        let pdfRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pdfPageSize),
            format: format
        )

        let contentWidth = pdfPageSize.width - 2 * pdfMargin
        let contentRect = CGRect(
            x: pdfMargin,
            y: pdfMargin,
            width: contentWidth,
            height: pdfPageSize.height - 2 * pdfMargin
        )

        let fullImageHeightPts = uiImage.size.height
        let scalePtsToDest = uiImage.size.width / contentWidth
        let pageSliceHeightPts = contentRect.height * scalePtsToDest

        let pixelScale = uiImage.scale
        let fullImageHeightPx = fullImageHeightPts * pixelScale
        let pageSliceHeightPx = pageSliceHeightPts * pixelScale
        let srcWidthPx = uiImage.size.width * pixelScale

        try pdfRenderer.writePDF(to: url) { ctx in
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

                    let dest = CGRect(
                        x: contentRect.minX,
                        y: contentRect.minY,
                        width: contentRect.width,
                        height: destHeightPts
                    )

                    UIImage(
                        cgImage: cgImage,
                        scale: uiImage.scale,
                        orientation: .up
                    )
                    .draw(in: dest)
                }

                yPts += pageSliceHeightPts
                yPx  += pageSliceHeightPx
            }
        }

        return url
    }
}
