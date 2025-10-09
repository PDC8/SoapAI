//
//  SOAPReportView.swift
//  SoapAI
//
//  Created by Jessi Avila-Shah on 4/16/25.
//

import SwiftUI

struct SOAPReportView: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: true) {
                    VStack {
                        Spacer(minLength: max((geometry.size.height - totalContentHeight) / 2, 0))
                        
                        VStack(spacing: 20) {
                            ForEach(1...4, id: \.self) { index in
                                TextBoxView(title: "Box \(index)")
                                    .id(index) // Assign ID for scrolling
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 20)
                    }
                    .frame(minHeight: geometry.size.height)
                }
                .scrollIndicators(.visible)
                .background(Color(red: 245/255, green: 235/255, blue: 220/255))
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        scrollProxy.scrollTo(1, anchor: .top)
                    }
                }
            }
        }
    }
    
    private var totalContentHeight: CGFloat {
        let boxHeight: CGFloat = 120
        let spacing: CGFloat = 20 * 3
        return (boxHeight * 4) + spacing
    }
}

struct TextBoxView: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text("This is some example content inside \(title). You can replace this with anything you'd like.")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    SOAPReportView()
}



