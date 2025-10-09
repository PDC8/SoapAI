//
//  TranscriptionService.swift
//  SoapAI
//
//  Created by Cem Kupeli on 4/7/25.
//

import Foundation

/// Models the JSON response returned by the Whisper API.
struct WhisperResponse: Codable {
    let text: String
}

class TranscriptionService {
    private let openAIAPIKey: String
    private let whisperEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    
    init() {
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String {
            openAIAPIKey = apiKey
        } else {
            openAIAPIKey = ""
        }
    }
    
    func transcribeAudioFile(url: URL) async throws -> String {
        var request = URLRequest(url: URL(string: whisperEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var formData = Data()
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        formData.append("whisper-1\r\n".data(using: .utf8)!)
        
        guard let fileData = try? Data(contentsOf: url) else {
            throw NSError(
                domain: "TranscriptionService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to load audio file data."]
            )
        }
        
        let filename = url.lastPathComponent
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        formData.append(fileData)
        formData.append("\r\n".data(using: .utf8)!)
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = formData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("TranscriptionService - HTTP Status Code: \(httpResponse.statusCode)")
            print("Headers: \(httpResponse.allHeaderFields)")
        }
        if let responseString = String(data: data, encoding: .utf8) {
            print("TranscriptionService - Response data string: \(responseString)")
        }
        
        let whisperResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return whisperResponse.text
    }
}
