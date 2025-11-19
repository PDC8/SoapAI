//
//  ObjectiveCard.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/18/25.
//

import SwiftUI

struct ObjectiveCard: View {
    let soReport: SOReport
    let patientData: PatientDataModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Objective:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            if let vitals = patientData?.vitals, !vitals.isEmpty {
                Text("Vitals:")
                    .font(.headline)
                ForEach(vitals, id: \.self) { v in
                    Text("• \(v)")
                }
            }

            Text("Physical Exam")
                .font(.headline)

            let o = soReport.objective
            VStack(alignment: .leading, spacing: 6) {
                Text("HEENT: \(o.HEENT)")
                Text("Lungs: \(o.lungs)")
                Text("Heart: \(o.heart)")
                Text("Abdomen: \(o.abdomen)")
                Text("Extremities: \(o.extremities)")
                Text("Neuro: \(o.neuro)")
                Text("Other: \(o.other)")
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
