//
//  APCard.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/18/25.
//

import SwiftUI

struct APCard: View {
    let apReport: APReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assessment:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(apReport.assessment)
                .font(.body)

            Divider()

            Text("Plan:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(apReport.plan, id: \.self) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.problem + ":")
                            .font(.subheadline)
                            .bold()

                        ForEach(entry.actions, id: \.self) { action in
                            Text("• \(action)")
                        }
                    }
                }
            }
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
