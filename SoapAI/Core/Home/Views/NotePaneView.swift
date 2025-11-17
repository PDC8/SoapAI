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
                // SO card
                if let so = viewModel.soReport {
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
                if viewModel.soReport != nil && viewModel.apReport == nil {
                    if viewModel.isGeneratingAP {
                        ProgressView("Generating AP…")
                    }

                    Button("Generate Assessment & Plan") {
                        Task {
                            await viewModel.generateAPReport()
                        }
                    }
                    .disabled(viewModel.isGeneratingAP)
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
                if let ap = viewModel.apReport {
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
                        .padding(.horizontal)
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
