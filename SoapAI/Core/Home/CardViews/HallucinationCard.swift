//
//  HallucinationCard.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/18/25.
//

import SwiftUI

struct HallucinationCard: View {
    let issues: [HallucinationIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

                        if let quote = issue.supportingTranscriptQuote,
                           !quote.isEmpty {
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
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}
