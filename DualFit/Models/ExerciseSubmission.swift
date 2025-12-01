//
//  ExerciseSubmission.swift
//  DualFit
//
//  Represents a user's video submission for an exercise on a specific day.
//

import Foundation
import CloudKit

/// CloudKit record type name for ExerciseSubmission
let ExerciseSubmissionRecordType = "ExerciseSubmission"

/// Submission review status
enum SubmissionStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
    
    var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .approved: return "✅"
        case .rejected: return "❌"
        }
    }
}

/// Represents a video submission for an exercise
struct ExerciseSubmission: Identifiable, Equatable, Hashable {
    let id: String                    // CloudKit record name
    let challengeRef: String          // Reference to Challenge record ID
    let exerciseRef: String           // Reference to ChallengeExercise record ID
    let userRef: String               // Reference to AppUser record ID (who submitted)
    let date: Date                    // The day this submission is for (date only)
    var videoAssetURL: URL?           // Local URL to video asset (from CKAsset)
    var status: SubmissionStatus
    var reviewerRef: String?          // Reference to AppUser who reviewed
    var reviewedAt: Date?
    var videoDeleted: Bool
    var pointsAwarded: Int
    let createdAt: Date
    var updatedAt: Date
    
    // MARK: - Computed Properties
    
    /// Whether the video is available for playback
    var isVideoAvailable: Bool {
        !videoDeleted && videoAssetURL != nil
    }
    
    /// Formatted date string for display
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - CloudKit Field Keys
    
    enum FieldKey: String {
        case challengeRef
        case exerciseRef
        case userRef
        case date
        case videoAsset
        case status
        case reviewerRef
        case reviewedAt
        case videoDeleted
        case pointsAwarded
        case createdAt
        case updatedAt
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        challengeRef: String,
        exerciseRef: String,
        userRef: String,
        date: Date,
        videoAssetURL: URL? = nil,
        status: SubmissionStatus = .pending,
        reviewerRef: String? = nil,
        reviewedAt: Date? = nil,
        videoDeleted: Bool = false,
        pointsAwarded: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.challengeRef = challengeRef
        self.exerciseRef = exerciseRef
        self.userRef = userRef
        // Normalize date to start of day
        self.date = Calendar.current.startOfDay(for: date)
        self.videoAssetURL = videoAssetURL
        self.status = status
        self.reviewerRef = reviewerRef
        self.reviewedAt = reviewedAt
        self.videoDeleted = videoDeleted
        self.pointsAwarded = pointsAwarded
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - CloudKit Conversion
    
    /// Initialize from a CloudKit record
    init?(from record: CKRecord) {
        guard record.recordType == ExerciseSubmissionRecordType else { return nil }
        
        self.id = record.recordID.recordName
        
        // Handle challenge reference
        if let ref = record[FieldKey.challengeRef.rawValue] as? CKRecord.Reference {
            self.challengeRef = ref.recordID.recordName
        } else {
            self.challengeRef = ""
        }
        
        // Handle exercise reference
        if let ref = record[FieldKey.exerciseRef.rawValue] as? CKRecord.Reference {
            self.exerciseRef = ref.recordID.recordName
        } else {
            self.exerciseRef = ""
        }
        
        // Handle user reference
        if let ref = record[FieldKey.userRef.rawValue] as? CKRecord.Reference {
            self.userRef = ref.recordID.recordName
        } else {
            self.userRef = ""
        }
        
        self.date = record[FieldKey.date.rawValue] as? Date ?? Date()
        
        // Handle video asset
        if let asset = record[FieldKey.videoAsset.rawValue] as? CKAsset {
            self.videoAssetURL = asset.fileURL
        } else {
            self.videoAssetURL = nil
        }
        
        let statusString = record[FieldKey.status.rawValue] as? String ?? "pending"
        self.status = SubmissionStatus(rawValue: statusString) ?? .pending
        
        // Handle reviewer reference
        if let ref = record[FieldKey.reviewerRef.rawValue] as? CKRecord.Reference {
            self.reviewerRef = ref.recordID.recordName
        } else {
            self.reviewerRef = nil
        }
        
        self.reviewedAt = record[FieldKey.reviewedAt.rawValue] as? Date
        self.videoDeleted = record[FieldKey.videoDeleted.rawValue] as? Bool ?? false
        self.pointsAwarded = record[FieldKey.pointsAwarded.rawValue] as? Int ?? 0
        self.createdAt = record[FieldKey.createdAt.rawValue] as? Date ?? record.creationDate ?? Date()
        self.updatedAt = record[FieldKey.updatedAt.rawValue] as? Date ?? record.modificationDate ?? Date()
    }
    
    /// Convert to a CloudKit record (for new submissions)
    func toRecord(videoFileURL: URL? = nil) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: ExerciseSubmissionRecordType, recordID: recordID)
        
        // Create references
        let challengeRecordID = CKRecord.ID(recordName: challengeRef)
        record[FieldKey.challengeRef.rawValue] = CKRecord.Reference(recordID: challengeRecordID, action: .deleteSelf)
        
        let exerciseRecordID = CKRecord.ID(recordName: exerciseRef)
        record[FieldKey.exerciseRef.rawValue] = CKRecord.Reference(recordID: exerciseRecordID, action: .deleteSelf)
        
        let userRecordID = CKRecord.ID(recordName: userRef)
        record[FieldKey.userRef.rawValue] = CKRecord.Reference(recordID: userRecordID, action: .none)
        
        record[FieldKey.date.rawValue] = date
        
        // Handle video asset
        if let url = videoFileURL {
            record[FieldKey.videoAsset.rawValue] = CKAsset(fileURL: url)
        }
        
        record[FieldKey.status.rawValue] = status.rawValue
        
        // Handle reviewer reference
        if let reviewer = reviewerRef {
            let reviewerRecordID = CKRecord.ID(recordName: reviewer)
            record[FieldKey.reviewerRef.rawValue] = CKRecord.Reference(recordID: reviewerRecordID, action: .none)
        }
        
        record[FieldKey.reviewedAt.rawValue] = reviewedAt
        record[FieldKey.videoDeleted.rawValue] = videoDeleted
        record[FieldKey.pointsAwarded.rawValue] = pointsAwarded
        record[FieldKey.createdAt.rawValue] = createdAt
        record[FieldKey.updatedAt.rawValue] = updatedAt
        
        return record
    }
    
    /// Update an existing CloudKit record after review
    func updateRecordForReview(_ record: CKRecord) -> CKRecord {
        record[FieldKey.status.rawValue] = status.rawValue
        
        if let reviewer = reviewerRef {
            let reviewerRecordID = CKRecord.ID(recordName: reviewer)
            record[FieldKey.reviewerRef.rawValue] = CKRecord.Reference(recordID: reviewerRecordID, action: .none)
        }
        
        record[FieldKey.reviewedAt.rawValue] = reviewedAt
        record[FieldKey.videoDeleted.rawValue] = videoDeleted
        record[FieldKey.pointsAwarded.rawValue] = pointsAwarded
        record[FieldKey.updatedAt.rawValue] = Date()
        
        // Remove video asset to delete it
        if videoDeleted {
            record[FieldKey.videoAsset.rawValue] = nil
        }
        
        return record
    }
}

// MARK: - Sample Data

extension ExerciseSubmission {
    static let sample = ExerciseSubmission(
        challengeRef: Challenge.sample.id,
        exerciseRef: ChallengeExercise.samples[0].id,
        userRef: AppUser.sample.id,
        date: Date(),
        status: .pending
    )
}

