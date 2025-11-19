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
                                ? Color(red: 60/255, green: 136/255, blue: 140/255)
                                : Color(red: 60/255, green: 136/255, blue: 140/255)
                        )
                    // Stroke on top
                    Circle()
                        .stroke(Color(red: 86/255, green: 157/255, blue: 161/255), lineWidth: 7)
                }
                .frame(width: 140, height: 140)
                .overlay(
                    viewModel.isRecording
                        ? Image(systemName: "pause")
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                        : Image(systemName: "play.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                    
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
