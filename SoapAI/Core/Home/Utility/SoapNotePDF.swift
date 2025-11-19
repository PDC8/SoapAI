//
//  SoapReportPDFView.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/15/25.
//

import SwiftUI

struct SoapReportPDFView: View {
    let soReport: SOReport
    let apReport: APReport
    let visitSummary: VisitSummary?
    let patientData: PatientDataModel?
    let issues: [HallucinationIssue]

    var body: some View {
        let generatedOn = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .medium,
            timeStyle: .short
        )

        VStack(spacing: 24) {

            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("SOAP Report")
                    .font(.title).bold()
                Text("Generated \(generatedOn)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            // Visit Summary (same layout as NotePaneView)
            if let summary = visitSummary {
                SummaryCard(summary: summary)
                    .padding(.horizontal, 16)
            }

            // SUBJECTIVE card
            SubjectiveCard(
                soReport: soReport,
                patientData: patientData
            )
            .padding(.horizontal, 16)

            // OBJECTIVE card
            ObjectiveCard(
                soReport: soReport,
                patientData: patientData
            )
            .padding(.horizontal, 16)

            // AP card
            APCard(apReport: apReport)
                .padding(.horizontal, 16)

            // Hallucination Review
            HallucinationCard(issues: issues)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 24)
        .background(Color.white)
        // Make sure the view takes its natural height instead of shrinking
        .fixedSize(horizontal: false, vertical: true)
    }
}

