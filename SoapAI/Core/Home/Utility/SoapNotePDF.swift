//
//  SoapReportPDFView.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/15/25.
//

import SwiftUI

struct SoapReportPDFView: View {
    let soap: String
    let issues: [HallucinationIssue]

    var body: some View {
        let generatedOn = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .medium,
            timeStyle: .short
        )

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
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("“\(quote)”")
                                    .italic()
                                    .font(.caption)
                            } else {
                                Text("No direct supporting quote in transcript.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(white: 0.98))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.08))
                        )
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }
}
