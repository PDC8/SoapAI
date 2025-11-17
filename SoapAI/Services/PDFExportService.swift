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

    func exportSOAP(soap: String, issues: [HallucinationIssue]) throws -> URL {
        let contentWidth = pdfPageSize.width - 2 * pdfMargin
        let view = SoapReportPDFView(soap: soap, issues: issues)
            .frame(width: contentWidth)

        return try renderPagedPDF(
            from: view,
            title: "SOAP Report",
            filenamePrefix: "SOAP_Report"
        )
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
