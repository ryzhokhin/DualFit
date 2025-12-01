//
//  ChallengeParticipant.swift
//  DualFit
//
//  Links users to challenges they participate in.
//

import Foundation
import CloudKit

/// CloudKit record type name for ChallengeParticipant
let ChallengeParticipantRecordType = "ChallengeParticipant"

/// Represents a user's participation in a challenge
struct ChallengeParticipant: Identifiable, Equatable, Hashable {
    let id: String                    // CloudKit record name
    let challengeRef: String          // Reference to Challenge record ID
    let userRef: String               // Reference to AppUser record ID
    let joinedAt: Date
    
    // MARK: - CloudKit Field Keys
    
    enum FieldKey: String {
        case challengeRef
        case userRef
        case joinedAt
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        challengeRef: String,
        userRef: String,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.challengeRef = challengeRef
        self.userRef = userRef
        self.joinedAt = joinedAt
    }
    
    // MARK: - CloudKit Conversion
    
    /// Initialize from a CloudKit record
    init?(from record: CKRecord) {
        guard record.recordType == ChallengeParticipantRecordType else { return nil }
        
        self.id = record.recordID.recordName
        
        // Handle challenge reference
        if let ref = record[FieldKey.challengeRef.rawValue] as? CKRecord.Reference {
            self.challengeRef = ref.recordID.recordName
        } else {
            self.challengeRef = ""
        }
        
        // Handle user reference
        if let ref = record[FieldKey.userRef.rawValue] as? CKRecord.Reference {
            self.userRef = ref.recordID.recordName
        } else {
            self.userRef = ""
        }
        
        self.joinedAt = record[FieldKey.joinedAt.rawValue] as? Date ?? record.creationDate ?? Date()
    }
    
    /// Convert to a CloudKit record
    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: ChallengeParticipantRecordType, recordID: recordID)
        
        // Create references
        let challengeRecordID = CKRecord.ID(recordName: challengeRef)
        record[FieldKey.challengeRef.rawValue] = CKRecord.Reference(recordID: challengeRecordID, action: .deleteSelf)
        
        let userRecordID = CKRecord.ID(recordName: userRef)
        record[FieldKey.userRef.rawValue] = CKRecord.Reference(recordID: userRecordID, action: .none)
        
        record[FieldKey.joinedAt.rawValue] = joinedAt
        
        return record
    }
}

// MARK: - Sample Data

extension ChallengeParticipant {
    static let sample = ChallengeParticipant(
        challengeRef: Challenge.sample.id,
        userRef: AppUser.sample.id
    )
}

