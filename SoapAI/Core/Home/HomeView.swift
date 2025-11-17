//
//  HomeView.swift
//  SoapAI
//
//  Created by Cem Kupeli on 4/7/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()


    // PDF state (still view-only for now)
    @State private var pdfURL: URL? = nil
    @State private var isExportingPDF = false

    @State private var transcriptPDFURL: URL? = nil
    @State private var isExportingTranscriptPDF = false
    
    let appColor = Color(red: 245/255, green: 235/255, blue: 220/255)

    // MARK: - Safe tab selection wrapper
    private var safeSelection: Binding<Int> {
        Binding(
            get: { viewModel.selectedTab },
            set: { new in
                if (new == 1 && viewModel.dividedMessages.isEmpty)
                    || (new == 2 && viewModel.soReport == nil) {
                    return
                }
                viewModel.selectedTab = new
            }
        )
    }
    
    
    private func exportNotePDF() {
        guard viewModel.soReport != nil, viewModel.apReport != nil else { return }

        let soap = viewModel.combinedSOAP()
        let issues = viewModel.hallucinationResult?.issues ?? []

        do {
            pdfURL = try PDFExportService.shared.exportSOAP(soap: soap, issues: issues)
            isExportingPDF = true
        } catch {
            print("PDF export failed:", error.localizedDescription)
        }
    }

    private func exportTranscriptPDF() {
        guard !viewModel.dividedMessages.isEmpty else { return }

        do {
            transcriptPDFURL = try PDFExportService.shared.exportTranscript(
                messages: viewModel.dividedMessages
            )
            isExportingTranscriptPDF = true
        } catch {
            print("Transcript PDF export failed:", error.localizedDescription)
        }
    }




    var body: some View {
        ZStack {
            appColor
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                TabView(selection: safeSelection) {
                    
                    // pane 1 - recording
                    RecordingPaneView(viewModel: viewModel, appColor: appColor)
                        .tag(0)

                    // Pane 2 – Transcript & SO generation
                    if !viewModel.dividedMessages.isEmpty {
                        TranscriptPaneView(
                                viewModel: viewModel,
                                appColor: appColor,
                                transcriptPDFURL: $transcriptPDFURL,
                                onExportTranscript: exportTranscriptPDF
                            )
                            .tag(1)
                    }

                    // Pane 3 – SOAP, AP, hallucinations, SOAP PDF
                    if viewModel.soReport != nil {
                        NotePaneView(
                            viewModel: viewModel,
                            appColor: appColor,
                            pdfURL: $pdfURL,
                            isExportingPDF: $isExportingPDF,
                            onExportSOAP: exportNotePDF
                        )
                        .tag(2)
                    }


                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.selectedTab)

                Divider()
                    .background(Color.black)
                    .padding(.bottom, 10)

                // Bottom navbar
                HStack {
                    Spacer()
                    navButton(systemName: "microphone", index: 0)
                    Spacer()
                    Spacer()
                    navButton(systemName: "text.bubble", index: 1)
                    Spacer()
                    Spacer()
                    navButton(systemName: "doc.plaintext", index: 2)
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(appColor.ignoresSafeArea(edges: .bottom))
            }
        }
    }
    
    @ViewBuilder
    private func navButton(systemName: String, index: Int) -> some View {
        Button { viewModel.selectedTab = index } label: {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(viewModel.selectedTab == index ? .blue : .gray)
        }
        .disabled((index == 1 && viewModel.dividedMessages.isEmpty)
               || (index == 2 && viewModel.soReport == nil))
        .opacity(((index == 1 && viewModel.dividedMessages.isEmpty)
               || (index == 2 && viewModel.soReport == nil)) ? 0.5 : 1)
    }
}

#Preview {
    HomeView()
}
