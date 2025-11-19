//
//  SubjectiveCard.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/18/25.
//

import SwiftUI

struct SubjectiveCard: View {
    let soReport: SOReport
    let patientData: PatientDataModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subjective:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(soReport.subjective)
                .font(.body)

            if let patientData = patientData {

                if let pmh = patientData.pastMedicalHistory, !pmh.isEmpty {
                    Text("Past Medical History:")
                        .font(.headline)
                    ForEach(pmh, id: \.self) { item in
                        Text("• \(item)")
                    }
                }

                if let allergies = patientData.allergies, !allergies.isEmpty {
                    Text("Allergies:")
                        .font(.headline)
                    ForEach(allergies, id: \.self) { item in
                        Text("• \(item)")
                    }
                }

                if let meds = patientData.medications, !meds.isEmpty {
                    Text("Medications:")
                        .font(.headline)
                    ForEach(meds, id: \.self) { item in
                        Text("• \(item)")
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
