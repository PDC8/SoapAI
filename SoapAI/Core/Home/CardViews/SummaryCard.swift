//
//  SummaryCard.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/18/25.
//

import SwiftUI

struct SummaryCard: View {
    let summary: VisitSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Visit Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(summary.oneLine)
                .font(.body)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
}
