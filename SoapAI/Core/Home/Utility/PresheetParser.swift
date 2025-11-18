//
//  PresheetParser.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/17/25.
//

// PresheetParser.swift
import Foundation

enum PresheetParser {
    static func parse(from text: String) -> PatientDataModel {
        var patient = PatientDataModel()

        // Scalars
        var fullName: String?
        var age: Int?
        var sex: String?
        var setting: String?

        // List-like sections
        var pmh: [String] = []
        var allergyList: [String] = []
        var medList: [String] = []
        var vitals: String?
        var studyList: [String] = []
        
        enum Section {
            case none
            case pastMedicalHistory
            case allergies
            case medications
            case vitalsAndStudies
        }
        
        var currentSection: Section = .none
        var vitalsAlreadyCaptured = false
        
        // Normalize into lines and trim whitespace
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        for rawLine in lines {
            let line = rawLine
            if line.isEmpty {
                // blank line ends list sections (optional, but helps)
                currentSection = .none
                continue
            }

            let lower = line.lowercased()

            // ---------- Single-line key/value fields ----------

            if lower.hasPrefix("name:") {
                fullName = value(after: ":", in: line)
                currentSection = .none
                continue
            }

            if lower.hasPrefix("age:") {
                if let ageString = value(after: ":", in: line) {
                    let digits = ageString.filter { $0.isNumber }
                    if let parsedAge = Int(digits) {
                        age = parsedAge
                    }
                }
                currentSection = .none
                continue
            }

            if lower.hasPrefix("sex:") {
                sex = value(after: ":", in: line)
                currentSection = .none
                continue
            }

            if lower.hasPrefix("setting:") {
                setting = value(after: ":", in: line)
                currentSection = .none
                continue
            }

            // ---------- Section headers ----------

            if lower.hasPrefix("past medical history") {
                currentSection = .pastMedicalHistory
                continue
            }

            if lower.hasPrefix("allergies") {
                currentSection = .allergies
                continue
            }

            if lower.hasPrefix("medications") {
                currentSection = .medications
                continue
            }

            if lower.contains("pertinent vitals") {
                currentSection = .vitalsAndStudies
                vitalsAlreadyCaptured = false
                continue
            }

            // ---------- Section contents (bullets) ----------

            switch currentSection {
            case .pastMedicalHistory:
                if let item = cleanBulletLine(line) {
                    pmh.append(item)
                }

            case .allergies:
                if let item = cleanBulletLine(line) {
                    allergyList.append(item)
                }

            case .medications:
                if let item = cleanBulletLine(line) {
                    medList.append(item)
                }

            case .vitalsAndStudies:
                if let item = cleanBulletLine(line) {
                    if !vitalsAlreadyCaptured {
                        vitals = item
                        vitalsAlreadyCaptured = true
                    } else {
                        studyList.append(item)
                    }
                }

            case .none:
                // ignore stray lines for now (or log them if you want)
                break
            }
        }

        patient.fullName = fullName
        patient.age = age
        patient.sex = sex
        patient.setting = setting

        if !pmh.isEmpty {
            patient.pastMedicalHistory = pmh
        }
        if !allergyList.isEmpty {
            patient.allergies = allergyList
        }
        if !medList.isEmpty {
            patient.medications = medList
        }

        patient.vitals = vitals

        if !studyList.isEmpty {
            patient.studies = studyList
        }

        // Keep raw text if you want full context
        patient.notes = text

        return patient
    }
    
    /// Extracts everything after the first `delimiter` and trims.
    private static func value(after delimiter: Character, in line: String) -> String? {
        guard let idx = line.firstIndex(of: delimiter) else { return nil }
        let start = line.index(after: idx)
        let substring = line[start...]
        let trimmed = substring.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Strips common bullet prefixes (•, -, *, numbers.) and returns a clean text line.
    private static func cleanBulletLine(_ line: String) -> String? {
        var result = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common bullet characters at the start
        let bulletPrefixes = [
            "•", "◦", "▪", "‣", "●", "○", "⦿", "⦾",
            "–", "—", "-", "*", "·", "• ", "◦ ", "● ",
            "→", "⇒", "►", "▸", "▹"
        ]

        for prefix in bulletPrefixes {
            if result.hasPrefix(prefix) {
                result.removeFirst(prefix.count)
                break
            }
        }

        // Also handle patterns like "1. Something" or "1) Something"
        if let firstSpace = result.firstIndex(of: " ") {
            let firstToken = String(result[..<firstSpace])
            if firstToken.last == "." || firstToken.last == ")" {
                // try to see if token before . or ) is numeric
                let numberPart = firstToken.dropLast()
                if Int(numberPart) != nil {
                    result = String(result[result.index(after: firstSpace)...])
                }
            }
        }

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
