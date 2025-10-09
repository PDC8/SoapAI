//
//  CRService.swift
//  SoapAI
//
//  Created by Cem Kupeli on 4/7/25.
//

import Foundation

// MARK: - Models for Structured Output

/// Represents a single message in a conversation (either from the doctor or the patient).
struct ChatMessage: Codable {
    let role: String   // Expected values: "doctor" or "patient"
    let content: String
}

/// Expected structure for the SO report output.
struct SOReport: Codable {
    let subjective: String
    let objective: String
}

/// Expected structure for the AP report output.
struct APReport: Codable {
    let assessment: String
    let plan: String
}

/// Model for decoding the overall chat completion response.
struct OpenAIChatResponse: Codable {
    let choices: [Choice]
    
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let role: String
            let content: String
        }
    }
}

class ClinicalReasoningService {
    private let openAIAPIKey: String
    private let session = URLSession.shared
    private let chatEndpoint = "https://api.openai.com/v1/chat/completions"
    
    init() {
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String {
            openAIAPIKey = apiKey
        } else {
            openAIAPIKey = ""
        }
    }
    
    func divideConversation(_ conversationText: String) async throws -> [ChatMessage] {
        let systemMessage = ChatMessage(
            role: "system",
            content: """
                You are an assistant that processes a transcript of a conversation between a doctor and a patient. 
                Your task is to divide the transcript into individual messages. 
                Each message should be an object with two keys: 'role' (either 'doctor' or 'patient') and 'content'. 
                Respond with a JSON array ONLY. 
                Do NOT wrap the output in code fences. 
                Do NOT include any additional text. 
                The response must begin with `[` and end with `]`.
            """
        )
        let transcriptMessage = ChatMessage(role: "user", content: "Here is the conversation: " + conversationText)
        let messages = [systemMessage, transcriptMessage]
        
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        
        let requestData = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: URL(string: chatEndpoint)!)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.addValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("divideConversation - HTTP Status Code: \(httpResponse.statusCode)")
        }
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("divideConversation - Raw response: \(rawResponse)")
        }
        
        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let messageContent = chatResponse.choices.first?.message.content,
              let jsonData = messageContent.data(using: .utf8) else {
            throw NSError(domain: "ClinicalReasoningService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid response content"])
        }
        let messagesArray = try JSONDecoder().decode([ChatMessage].self, from: jsonData)
        return messagesArray
    }
    
    func generateSOReport(from conversationMessages: [ChatMessage]) async throws -> SOReport {
        let systemMessage = ChatMessage(
            role: "system",
            content: """
                    You are an assistant that generates the Subjective and Objective sections of a doctor's report based on a conversation between a doctor and a patient. 
                    Analyze the conversation and return a JSON object only in the following format:

                    { 
                      "subjective": "<string describing patient's reported symptoms and concerns>", 
                      "objective": "<string describing doctor's clinical findings>" 
                    }

                    The response must be valid JSON. 
                    Do not include Markdown formatting. 
                    Do not include code fences (```json or ```). 
                    Do not add any extra text, explanation, or annotations. 
                    The output must begin with { and end with }.
            """
        )
        
        let concatenatedContent = conversationMessages.map { message in
            "\(message.role.capitalized): \(message.content)"
        }.joined(separator: "\n")
        
        let conversationMessage = ChatMessage(role: "user", content: concatenatedContent)
        
        let messages = [systemMessage, conversationMessage]
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        
        let requestData = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: URL(string: chatEndpoint)!)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.addValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("generateSOReport - HTTP Status Code: \(httpResponse.statusCode)")
        }
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("generateSOReport - Raw response: \(rawResponse)")
        }
        
        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let messageContent = chatResponse.choices.first?.message.content,
              let jsonData = messageContent.data(using: .utf8) else {
            throw NSError(domain: "ClinicalReasoningService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid response content"])
        }
        let SO = try JSONDecoder().decode(SOReport.self, from: jsonData)
        return SO
    }
    
    func generateAPReport(from conversationMessages: [ChatMessage]) async throws -> APReport {
        let systemMessage = ChatMessage(
            role: "system",
            content:"""
                    You are an assistant that generates the Assessment and Plan sections of a doctor's report based on a conversation between a doctor and a patient. 
                    Analyze the conversation and return a JSON object only in the following format:

                    { 
                      "assessment": "<string describing your clinical interpretation>", 
                      "plan": "<string describing your recommended next steps>" 
                    }

                    The response must be valid JSON. 
                    Do not include Markdown formatting. 
                    Do not include code fences (```json or ```). 
                    Do not add any extra text, explanation, or annotations. 
                    The output must begin with { and end with }.
                    """
        )
        
        let concatenatedContent = conversationMessages.map { message in
            "\(message.role.capitalized): \(message.content)"
        }.joined(separator: "\n")
        
        let conversationMessage = ChatMessage(role: "user", content: concatenatedContent)
        
        let messages = [systemMessage, conversationMessage]
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        
        let requestData = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: URL(string: chatEndpoint)!)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.addValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("generateAPReport - HTTP Status Code: \(httpResponse.statusCode)")
        }
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("generateAPReport - Raw response: \(rawResponse)")
        }
        
        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let messageContent = chatResponse.choices.first?.message.content,
              let jsonData = messageContent.data(using: .utf8) else {
            throw NSError(domain: "ClinicalReasoningService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid response content"])
        }
        let AP = try JSONDecoder().decode(APReport.self, from: jsonData)
        return AP
    }
}
