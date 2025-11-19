//
//  PatientDataModel.swift
//  SoapAI
//
//  Created by Vinni Yu on 11/17/25.
//

// PatientDataModel.swift
import Foundation

struct PatientDataModel: Identifiable {
    let id = UUID()

    var fullName: String?
    var age: Int?
    var sex: String?
    var setting: String?
    
    var pastMedicalHistory: [String]?
    var allergies: [String]?
    var medications: [String]?
    var vitals: [String]?
    var testResults: [String]?
    
    var notes: String?          // catch-all / debug
}
