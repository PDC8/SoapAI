//
//  RecordingPaneView.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/15/25.
//

import SwiftUI

struct RecordingPaneView: View {
    @ObservedObject var viewModel: HomeViewModel
    let appColor: Color
    
    @State private var importedPdfText: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            Button {
                viewModel.toggleRecording()
            } label: {
                ZStack {
                    // Fill background
                    Circle()
                        .fill(
                            viewModel.isRecording
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

            Text(viewModel.formatTime(viewModel.timeElapsed))
                .font(.title2)
                .padding(.top, 8)

            if viewModel.isTranscribing {
                ProgressView("Transcribing…")
                    .padding(.top, 16)
            }

            if !viewModel.isRecording,
               viewModel.hasAudioFile,
               viewModel.dividedMessages.isEmpty
            {
                Button {
                    Task {
                        await viewModel.handleTranscribeTapped()
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
                .disabled(viewModel.isTranscribing)
            }

            Spacer()

            PdfImportCard(viewModel: viewModel)
        }
        .padding()
    }
}
