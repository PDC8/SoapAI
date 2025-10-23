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


// Hallucination Models
struct HallucinationIssue: Codable, Identifiable {
    let id: UUID
    let start: Int   // inclusive char offset in soapNote
    let end: Int     // exclusive char offset in soapNote
    let explanation: String
    let supportingTranscriptQuote: String? // null if not found
    
    init(start: Int, end: Int, explanation: String, supportingTranscriptQuote: String?) {
        self.id = UUID()
        self.start = start
        self.end = end
        self.explanation = explanation
        self.supportingTranscriptQuote = supportingTranscriptQuote
    }
}

struct HallucinationCheckResult: Codable {
    let issues: [HallucinationIssue]
}

extension ClinicalReasoningService {

    func checkHallucinations(soapNote: String, transcriptMessages: [ChatMessage]) async throws -> HallucinationCheckResult {
        // Join transcript as a plain text source-of-truth
        let transcript = transcriptMessages
            .map { "\($0.role.capitalized): \($0.content)" }
            .joined(separator: "\n")

        let system = [
            "role": "system",
            "content":
            """
            You are a clinical fact-checker. Compare a SOAP note against the original doctor–patient transcript.
            Task: For each sentence in the SOAP note, find a direct or near-direct supporting quote from the transcript.
            If a sentence cannot be supported or is contradicted by the transcript then return an issue with:
            
            - soap_span.start: integer (inclusive character offset in soapNote)
            - soap_span.end: integer (exclusive character offset in soapNote)
            - explanation: short reason why it is unsupported or contradicted
            - supporting_transcript_quote: exact quote from the transcript that contradicts or disproves the SOAP statement, or null if no relevant quote exists (i.e., hallucinated content)
            
            Goal: Ensure every SOAP sentence is either directly traceable to the transcript or flagged as unsupported/contradicted.
            
            Rules:
            - Output JSON only, no markdown or commentary.
            - Do not include code fences (```json or ```). 
            - Use character offsets over the provided soapNote string exactly as given.
            - If everything is supported, return {"issues": []}.
            """
        ]

        let user = [
            "role": "user",
            "content":
            """
            TRANSCRIPT:
            \(transcript)

            SOAP_NOTE:
            \(soapNote)
            """
        ]

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [system, user]
        ]

        let requestData = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: URL(string: chatEndpoint)!)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.addValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("checkHallucinations - HTTP Status Code: \(httpResponse.statusCode)")
        }
        if let raw = String(data: data, encoding: .utf8) {
            print("checkHallucinations - Raw response: \(raw)")
        }

        // The assistant returns JSON as a string inside choices[0].message.content, same as other methods.
        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let messageContent = chatResponse.choices.first?.message.content,
              let jsonData = messageContent.data(using: .utf8) else {
            throw NSError(domain: "ClinicalReasoningService", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Missing or invalid response content"])
        }

        // Decode to an intermediate shape that matches the tool’s schema
        struct RawIssue: Codable {
            struct Span: Codable { let start: Int; let end: Int }
            let soap_span: Span
            let explanation: String
            let supporting_transcript_quote: String?
        }
        struct RawResult: Codable { let issues: [RawIssue] }

        let raw = try JSONDecoder().decode(RawResult.self, from: jsonData)
        let mapped = HallucinationCheckResult(issues: raw.issues.map {
            HallucinationIssue(start: $0.soap_span.start,
                               end: $0.soap_span.end,
                               explanation: $0.explanation,
                               supportingTranscriptQuote: $0.supporting_transcript_quote)
        })
        return mapped
    }
}
