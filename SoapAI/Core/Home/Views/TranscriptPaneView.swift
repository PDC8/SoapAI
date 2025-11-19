//
//  TranscriptPaneView.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/15/25.
//

import SwiftUI

struct TranscriptPaneView: View {
    @ObservedObject var viewModel: HomeViewModel
    let appColor: Color

    @Binding var transcriptPDFURL: URL?
    let onExportTranscript: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            TranscriptionView(messages: viewModel.dividedMessages)

            // Export Transcript PDF
            if !viewModel.dividedMessages.isEmpty {
                Button {
                    onExportTranscript()
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
                    ShareLink(
                        item: tURL,
                        preview: SharePreview("Transcript", image: Image(systemName: "doc.text"))
                    ) {
                        Label("Share Transcript PDF", systemImage: "square.and.arrow.up")
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
                }
            }

            // Generate SO report
            if !viewModel.dividedMessages.isEmpty && viewModel.soReport == nil {
                if viewModel.isGeneratingSO {
                    ProgressView("Generating report…")
                        .padding(.top, 16)
                }

                Button {
                    Task {
                        await viewModel.generateVisitSummary()
                        await viewModel.generateSOReport()
                        await viewModel.generateAPReport()
                    }
                } label: {
                    Text("Generate SOAP Note")
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
                .disabled(viewModel.isGeneratingSO)
            }

            Spacer()
        }
        .padding()
    }
}
