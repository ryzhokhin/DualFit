//
//  ChallengeExercise.swift
//  DualFit
//
//  Represents an exercise within a challenge.
//

import Foundation
import CloudKit

/// CloudKit record type name for ChallengeExercise
let ChallengeExerciseRecordType = "ChallengeExercise"

/// Represents an exercise within a fitness challenge
struct ChallengeExercise: Identifiable, Equatable, Hashable {
    let id: String                    // CloudKit record name
    let challengeRef: String          // Reference to Challenge record ID
    var name: String
    var dailyRequiredReps: Int
    var order: Int                    // For sorting exercises in UI
    
    // MARK: - CloudKit Field Keys
    
    enum FieldKey: String {
        case challengeRef
        case name
        case dailyRequiredReps
        case order
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        challengeRef: String,
        name: String,
        dailyRequiredReps: Int = 10,
        order: Int = 0
    ) {
        self.id = id
        self.challengeRef = challengeRef
        self.name = name
        self.dailyRequiredReps = dailyRequiredReps
        self.order = order
    }
    
    // MARK: - CloudKit Conversion
    
    /// Initialize from a CloudKit record
    init?(from record: CKRecord) {
        guard record.recordType == ChallengeExerciseRecordType else { return nil }
        
        self.id = record.recordID.recordName
        
        // Handle reference field
        if let ref = record[FieldKey.challengeRef.rawValue] as? CKRecord.Reference {
            self.challengeRef = ref.recordID.recordName
        } else {
            self.challengeRef = ""
        }
        
        self.name = record[FieldKey.name.rawValue] as? String ?? "Unknown Exercise"
        self.dailyRequiredReps = record[FieldKey.dailyRequiredReps.rawValue] as? Int ?? 10
        self.order = record[FieldKey.order.rawValue] as? Int ?? 0
    }
    
    /// Convert to a CloudKit record
    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: ChallengeExerciseRecordType, recordID: recordID)
        
        // Create reference to challenge
        let challengeRecordID = CKRecord.ID(recordName: challengeRef)
        record[FieldKey.challengeRef.rawValue] = CKRecord.Reference(recordID: challengeRecordID, action: .deleteSelf)
        
        record[FieldKey.name.rawValue] = name
        record[FieldKey.dailyRequiredReps.rawValue] = dailyRequiredReps
        record[FieldKey.order.rawValue] = order
        
        return record
    }
}

// MARK: - Sample Data

extension ChallengeExercise {
    static let samples: [ChallengeExercise] = [
        ChallengeExercise(challengeRef: Challenge.sample.id, name: "Push-ups", dailyRequiredReps: 10, order: 0),
        ChallengeExercise(challengeRef: Challenge.sample.id, name: "Squats", dailyRequiredReps: 15, order: 1),
        ChallengeExercise(challengeRef: Challenge.sample.id, name: "Planks", dailyRequiredReps: 1, order: 2),
        ChallengeExercise(challengeRef: Challenge.sample.id, name: "Burpees", dailyRequiredReps: 5, order: 3)
    ]
}

