//
//  TranscriptionView.swift
//  SoapAI
//
//  Created by Shomari Smith on 4/16/25.
//

import SwiftUI

struct TranscriptionView: View {

    let messages: [ChatMessage]
    
    var body: some View {
        ZStack {
            Color(red: 245/255, green: 235/255, blue: 220/255)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages.indices, id: \.self) { index in
                        MessageBubble(message: messages[index])
                    }
                }
                .padding()
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == "doctor" {
                Spacer()
            }
            
            Text(message.content)
                .padding(12)
                .background(message.role == "doctor" ? Color.orange.opacity(0.28) : Color.blue.opacity(0.2))
                .cornerRadius(16)
                .foregroundColor(.primary)
            
            if message.role == "patient" {
                Spacer()
            }
        }
    }
}

#Preview {
    TranscriptionView(messages: [
        ChatMessage(role: "doctor", content: "Hey Mr.Toledo, what brings you in today?"),
        ChatMessage(role: "patient", content: "Hey Doc, to tell you the truth I've been having some headaches recently. They're getting pretty bad."),
        ChatMessage(role: "doctor", content: "I'm sorry to hear about that. Could you tell me a bit more about this pain. Does it feel localized anywhere?")
    ])
}
