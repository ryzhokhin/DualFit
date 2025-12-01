//
//  AppUser.swift
//  DualFit
//
//  Represents a user of the app, linked to their iCloud identity.
//

import Foundation
import CloudKit

/// CloudKit record type name for AppUser
let AppUserRecordType = "AppUser"

/// Represents a user in the DualFit app
struct AppUser: Identifiable, Equatable, Hashable {
    let id: String                    // CloudKit record name
    let icloudUserRecordID: String    // The user's iCloud identity
    var displayName: String
    var avatarEmoji: String
    let createdAt: Date
    
    // MARK: - CloudKit Field Keys
    
    enum FieldKey: String {
        case icloudUserRecordID
        case displayName
        case avatarEmoji
        case createdAt
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        icloudUserRecordID: String,
        displayName: String,
        avatarEmoji: String = "💪",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.icloudUserRecordID = icloudUserRecordID
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.createdAt = createdAt
    }
    
    // MARK: - CloudKit Conversion
    
    /// Initialize from a CloudKit record
    init?(from record: CKRecord) {
        guard record.recordType == AppUserRecordType else { return nil }
        
        self.id = record.recordID.recordName
        self.icloudUserRecordID = record[FieldKey.icloudUserRecordID.rawValue] as? String ?? ""
        self.displayName = record[FieldKey.displayName.rawValue] as? String ?? "Unknown"
        self.avatarEmoji = record[FieldKey.avatarEmoji.rawValue] as? String ?? "💪"
        self.createdAt = record[FieldKey.createdAt.rawValue] as? Date ?? record.creationDate ?? Date()
    }
    
    /// Convert to a CloudKit record
    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: AppUserRecordType, recordID: recordID)
        
        record[FieldKey.icloudUserRecordID.rawValue] = icloudUserRecordID
        record[FieldKey.displayName.rawValue] = displayName
        record[FieldKey.avatarEmoji.rawValue] = avatarEmoji
        record[FieldKey.createdAt.rawValue] = createdAt
        
        return record
    }
    
    /// Update an existing CloudKit record with current values
    func updateRecord(_ record: CKRecord) -> CKRecord {
        record[FieldKey.displayName.rawValue] = displayName
        record[FieldKey.avatarEmoji.rawValue] = avatarEmoji
        return record
    }
}

// MARK: - Sample Data

extension AppUser {
    static let sample = AppUser(
        icloudUserRecordID: "sample-icloud-id",
        displayName: "Andrii",
        avatarEmoji: "🏋️"
    )
}

