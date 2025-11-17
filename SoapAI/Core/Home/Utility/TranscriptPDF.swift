//
//  TranscriptPDFView.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/15/25.
//

import SwiftUI

struct TranscriptPDFView: View {
    let messages: [ChatMessage]

    var body: some View {
        let generatedOn = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .medium,
            timeStyle: .short
        )

        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Transcript")
                    .font(.title).bold()
                Text("Generated \(generatedOn)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Divider()

            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages.indices, id: \.self) { idx in
                    let m = messages[idx]

                    HStack {
                        if m.role == "doctor" { Spacer(minLength: 0) }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.role.capitalized)
                                .font(.caption).bold()
                                .foregroundColor(.secondary)
                            Text(m.content)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(
                            (m.role == "doctor"
                             ? Color.orange.opacity(0.20)
                             : Color.blue.opacity(0.18))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if m.role == "patient" { Spacer(minLength: 0) }
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }
}
