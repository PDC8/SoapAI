//
//  EmotionModel.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/18/25.
//

import Foundation

struct EmotionMoment: Codable, Identifiable {
    let id: UUID
    let phase: String         // "entering", "shift", or "ending"
    let emotion: String       // one of the allowed labels
    let description: String   // 1–2 sentence holistic summary

    init(phase: String, emotion: String, description: String) {
        self.id = UUID()
        self.phase = phase
        self.emotion = emotion
        self.description = description
    }
}

struct EmotionAnalysisResult: Codable {
    let summaryBullets: [String]  // 4–6 holistic bullet points
    let moments: [EmotionMoment]  // distilled emotional trajectory
}
