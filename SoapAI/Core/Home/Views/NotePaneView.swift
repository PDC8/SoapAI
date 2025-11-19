//
//  NotePaneView.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/17/25.
//

import SwiftUI

struct NotePaneView: View {
    @ObservedObject var viewModel: HomeViewModel
    let appColor: Color

    @Binding var pdfURL: URL?
    @Binding var isExportingPDF: Bool
    let onExportSOAP: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
            
                
                // SOAP Note
                if let summary = viewModel.visitSummary,
                   let so = viewModel.soReport,
                   let ap = viewModel.apReport {
                    
                    SummaryCard(summary: summary)
                    
                    SubjectiveCard(
                        soReport: so,
                        patientData: viewModel.patientData
                    )

                    ObjectiveCard(
                        soReport: so,
                        patientData: viewModel.patientData
                    )
                    
                    APCard(apReport: ap)
                }
                
                if let emotion = viewModel.emotionAnalysis {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Patient Emotional Tone")
                            .font(.headline)

                        // bullets
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(emotion.summaryBullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                    Text(bullet)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        // mini “trajectory” row from `moments`
                        if !emotion.moments.isEmpty {
                            Divider().padding(.vertical, 8)

                            Text("Emotional trajectory")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(emotion.moments) { moment in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(moment.phase.capitalized)
                                            .font(.caption)
                                            .frame(width: 70, alignment: .leading)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(appColor.opacity(0.4))
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(moment.emotion.capitalized)
                                                .font(.caption.bold())
                                            Text(moment.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                }

                // Hallucination check button (appears when both SO & AP exist and no prior result)
                if viewModel.soReport != nil,
                   viewModel.apReport != nil,
                   viewModel.hallucinationResult == nil {
                    if viewModel.isCheckingHallucinations {
                        ProgressView("Checking for hallucinations…")
                    } else {
                        Button("Check for hallucinations") {
                            Task {
                                await viewModel.checkHallucinations()
                            }
                        }
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
                    }
                }

                // Results / issues
                if let err = viewModel.hallucinationError {
                    Text(err)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                } else if let result = viewModel.hallucinationResult {
                    let _ = viewModel.combinedSOAP() // keeps logic consistent, even if we don't display it here

                    if result.issues.isEmpty {
                        Text("No hallucinations found ✅")
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Review: Unsupported Claims")
                                .font(.headline)

                            ForEach(result.issues) { issue in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Issue").font(.subheadline).bold()
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
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black.opacity(0.08))
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Export button for SOAP PDF
                if viewModel.soReport != nil, viewModel.apReport != nil {
                    Button {
                        onExportSOAP()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up.on.square")
                            Text("Export PDF")
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
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // Share sheet
                if let url = pdfURL {
                    ShareLink(
                        item: url,
                        preview: SharePreview("SOAP Report", image: Image(systemName: "doc.richtext"))
                    )
                    .onAppear { isExportingPDF = true }
                }
            }
            .padding(.vertical, 20)
        }
    }
}
