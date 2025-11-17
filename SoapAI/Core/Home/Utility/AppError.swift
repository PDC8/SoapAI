//
//  AppError.swift
//  SoapAI
//
//  Created by Peidong Chen on 10/1/25.
//
import Foundation

enum AppError: LocalizedError, Identifiable {
    var id: String { localizedDescription }

    case recordingPermissionDenied
    case openAIKeyMissing
    case networkTimeout
    case httpStatus(Int, String)
    case decoding(String)
    case file(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .recordingPermissionDenied:
            return "Microphone permission not granted. Please enable it in Settings."
        case .openAIKeyMissing:
            return "Missing OpenAI API Key. Add OPENAI_API_KEY to your Info.plist."
        case .networkTimeout:
            return "Network is slow or timed out. Please try again or switch networks."
        case .httpStatus(let code, let msg):
            return "Server error (\(code)). \(msg)"
        case .decoding(let msg):
            return "I couldn’t read the server response. \(msg)"
        case .file(let msg):
            return "Audio file issue: \(msg)"
        case .unknown(let msg):
            return msg
        }
    }
}

