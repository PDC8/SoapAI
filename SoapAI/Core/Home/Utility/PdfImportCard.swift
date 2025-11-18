//
//  FileImporter.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/17/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ImportedPDF {
    let fileName: String
    let data: Data
}

struct PdfImportCard: View {
    @ObservedObject var viewModel: HomeViewModel

    @State private var isImporterPresented = false
    private let pdfType = UTType.pdf

    var body: some View {
        VStack(spacing: 16) {
            if let patient = viewModel.patientData,
               let name = patient.fullName ?? patient.notes {
                Text("Presheet imported")
                    .font(.subheadline)
                    .bold()
            }

            Button {
                isImporterPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import Presheet (PDF)")
                            .font(.headline)
                        Text("Tap to choose a PDF")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [pdfType],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }

                do {
                    let canAccess = url.startAccessingSecurityScopedResource()
                    defer { if canAccess { url.stopAccessingSecurityScopedResource() } }

                    let data = try Data(contentsOf: url)

                    // 🔗 Push into the view model
                    viewModel.handlePresheetPDFData(data)

                } catch {
                    print("Failed to read PDF data:", error)
                }

            case .failure(let error):
                print("File import failed:", error)
            }
        }
    }
}


func extractTextFromPDF(data: Data) -> String? {
    guard let pdfDocument = PDFDocument(data: data) else {
        print("Could not create PDFDocument")
        return nil
    }

    var fullText = ""

    for pageIndex in 0..<pdfDocument.pageCount {
        guard let page = pdfDocument.page(at: pageIndex),
              let pageText = page.string
        else { continue }

        fullText += pageText + "\n\n"
    }

    return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
}

