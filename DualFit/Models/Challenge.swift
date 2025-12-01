//
//  Challenge.swift
//  DualFit
//
//  Represents a fitness challenge that users can participate in.
//

import Foundation
import CloudKit

/// CloudKit record type name for Challenge
let ChallengeRecordType = "Challenge"

/// Represents a fitness challenge
struct Challenge: Identifiable, Equatable, Hashable {
    let id: String                    // CloudKit record name (also serves as join code)
    var name: String
    var description: String
    let createdByUserRef: String      // Reference to AppUser record ID
    var startDate: Date
    var endDate: Date
    var maxParticipants: Int
    let createdAt: Date
    
    // MARK: - Computed Properties
    
    /// The join code for this challenge (uses the record ID)
    var joinCode: String {
        // Use first 8 characters of ID for a shorter code
        String(id.prefix(8)).uppercased()
    }
    
    /// Whether the challenge is currently active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    /// Whether the challenge has ended
    var hasEnded: Bool {
        Date() > endDate
    }
    
    /// Total number of days in the challenge
    var totalDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
    
    /// Days elapsed since start (capped at total days)
    var daysElapsed: Int {
        let calendar = Calendar.current
        let now = Date()
        let effectiveDate = min(now, endDate)
        let components = calendar.dateComponents([.day], from: startDate, to: effectiveDate)
        return max(0, min((components.day ?? 0) + 1, totalDays))
    }
    
    // MARK: - CloudKit Field Keys
    
    enum FieldKey: String {
        case name
        case description
        case createdByUserRef
        case startDate
        case endDate
        case maxParticipants
        case createdAt
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        createdByUserRef: String,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
        maxParticipants: Int = 10,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdByUserRef = createdByUserRef
        self.startDate = startDate
        self.endDate = endDate
        self.maxParticipants = min(maxParticipants, 10) // Enforce max 10
        self.createdAt = createdAt
    }
    
    // MARK: - CloudKit Conversion
    
    /// Initialize from a CloudKit record
    init?(from record: CKRecord) {
        guard record.recordType == ChallengeRecordType else { return nil }
        
        self.id = record.recordID.recordName
        self.name = record[FieldKey.name.rawValue] as? String ?? "Unnamed Challenge"
        self.description = record[FieldKey.description.rawValue] as? String ?? ""
        
        // Handle reference field
        if let ref = record[FieldKey.createdByUserRef.rawValue] as? CKRecord.Reference {
            self.createdByUserRef = ref.recordID.recordName
        } else {
            self.createdByUserRef = ""
        }
        
        self.startDate = record[FieldKey.startDate.rawValue] as? Date ?? Date()
        self.endDate = record[FieldKey.endDate.rawValue] as? Date ?? Date()
        self.maxParticipants = record[FieldKey.maxParticipants.rawValue] as? Int ?? 10
        self.createdAt = record[FieldKey.createdAt.rawValue] as? Date ?? record.creationDate ?? Date()
    }
    
    /// Convert to a CloudKit record
    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: ChallengeRecordType, recordID: recordID)
        
        record[FieldKey.name.rawValue] = name
        record[FieldKey.description.rawValue] = description
        
        // Create reference to user
        let userRecordID = CKRecord.ID(recordName: createdByUserRef)
        record[FieldKey.createdByUserRef.rawValue] = CKRecord.Reference(recordID: userRecordID, action: .none)
        
        record[FieldKey.startDate.rawValue] = startDate
        record[FieldKey.endDate.rawValue] = endDate
        record[FieldKey.maxParticipants.rawValue] = maxParticipants
        record[FieldKey.createdAt.rawValue] = createdAt
        
        return record
    }
}

// MARK: - Sample Data

extension Challenge {
    static let sample = Challenge(
        name: "November Pushup Duel",
        description: "30 days of push-ups with friends!",
        createdByUserRef: AppUser.sample.id,
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    )
}

