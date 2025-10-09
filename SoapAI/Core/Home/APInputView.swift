//
//  APInputView.swift
//  SoapAI
//
//  Created by Peidong Chen on 3/26/25.
//

import SwiftUI

struct APInputView: View {
    @State private var assessmentText: String = ""
    @State private var planText: String = ""

    var body: some View {
        ZStack {
            Color(red: 245/255, green: 235/255, blue: 220/255)
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Spacer(minLength: 20)

                    Group {
                        Text("Assessment")
                            .font(.headline)
                            .foregroundColor(.black)
                        TextEditor(text: $assessmentText)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 0.5)
                            )
                            .foregroundColor(.black)
                            .font(.body)
                    }

                    Group {
                        Text("Plan")
                            .font(.headline)
                            .foregroundColor(.black)
                        TextEditor(text: $planText)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 0.5)
                            )
                            .foregroundColor(.black)
                            .font(.body)
                    }

                    Button(action: {
                        print("Assessment: \(assessmentText)")
                        print("Plan: \(planText)")
                    }) {
                        Text("Approve")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 16)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    APInputView()
}
