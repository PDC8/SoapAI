//
//  ClinicianReport.swift
//  SoapAI
//
//  Created by Jessi Avila-Shah on 5/1/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ClinicianReport: View {
    @State private var isShowingDocumentPicker = false
    @State private var uploadedText: String = ""
    @State private var manualText: String = ""
    @State private var useManualEntry = false
    @State private var showSaveAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                // Beige background
                Color(red: 245/255, green: 235/255, blue: 220/255)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    
                    Picker("Input Method", selection: $useManualEntry) {
                        Text("Upload Report").tag(false)
                        Text("Manual Entry").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()

                    if useManualEntry {
                        ScrollView {
                            TextEditor(text: $manualText)
                                .padding()
                                .frame(minHeight: 200)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
                        }
                        .frame(maxHeight: 300)

                        Button(action: {
                            showSaveAlert = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save")
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        .alert(isPresented: $showSaveAlert) {
                            Alert(
                                title: Text("Report Saved"),
                                message: Text("Your manual report has been saved successfully."),
                                dismissButton: .default(Text("OK"))
                            )
                        }

                    } else {
                        Button(action: {
                            isShowingDocumentPicker = true
                        }) {
                            HStack {
                                Image(systemName: "doc.fill.badge.plus")
                                Text("Upload Report")
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }

                        ScrollView {
                            Text(uploadedText.isEmpty ? "No file uploaded yet." : uploadedText)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        .frame(maxHeight: 300)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Clinician Report")
            .fileImporter(
                isPresented: $isShowingDocumentPicker,
                allowedContentTypes: [.plainText, .pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
        }
    }

    func handleFileImport(result: Result<[URL], Error>) {
        do {
            let selectedFile: URL = try result.get().first!
            if selectedFile.startAccessingSecurityScopedResource() {
                defer { selectedFile.stopAccessingSecurityScopedResource() }

                if selectedFile.pathExtension == "txt" {
                    uploadedText = try String(contentsOf: selectedFile)
                } else {
                    uploadedText = "File uploaded: \(selectedFile.lastPathComponent)"
                }
            }
        } catch {
            uploadedText = "Failed to read file: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ClinicianReport()
}

