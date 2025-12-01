//
//  SubmissionService.swift
//  DualFit
//
//  Handles exercise submission operations.
//

import Foundation
import CloudKit

/// Errors specific to submission operations
enum SubmissionError: LocalizedError {
    case submissionNotFound
    case alreadySubmitted
    case cannotReviewOwnSubmission
    case videoUploadFailed
    case invalidVideoFile
    
    var errorDescription: String? {
        switch self {
        case .submissionNotFound:
            return "Submission not found."
        case .alreadySubmitted:
            return "You have already submitted for this exercise today."
        case .cannotReviewOwnSubmission:
            return "You cannot review your own submission."
        case .videoUploadFailed:
            return "Failed to upload video. Please try again."
        case .invalidVideoFile:
            return "Invalid video file. Please select a different video."
        }
    }
}

/// Leaderboard entry for a user
struct LeaderboardEntry: Identifiable, Equatable {
    let id: String
    let user: AppUser
    var totalPoints: Int
    var approvedSubmissions: Int
    var rank: Int
}

/// Daily completion status for calendar view
struct DayCompletionStatus: Identifiable, Equatable {
    let id: String
    let date: Date
    let totalExercises: Int
    var approvedCount: Int
    var pendingCount: Int
    var rejectedCount: Int
    
    var status: CompletionLevel {
        if approvedCount == totalExercises && totalExercises > 0 {
            return .complete
        } else if approvedCount > 0 || pendingCount > 0 {
            return .partial
        } else {
            return .none
        }
    }
    
    enum CompletionLevel {
        case complete   // All exercises approved (green)
        case partial    // Some approved or pending (yellow)
        case none       // No submissions (empty/red)
    }
}

/// Service for managing exercise submissions
actor SubmissionService {
    // MARK: - Singleton
    
    static let shared = SubmissionService()
    
    // MARK: - Properties
    
    private let cloudKit = CloudKitManager.shared
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Submission CRUD
    
    /// Create a new exercise submission with video
    func createSubmission(
        challengeID: String,
        exerciseID: String,
        userID: String,
        date: Date,
        videoFileURL: URL
    ) async throws -> ExerciseSubmission {
        // Check if submission already exists for this exercise/date
        let existing = try await fetchSubmission(
            challengeID: challengeID,
            exerciseID: exerciseID,
            userID: userID,
            date: date
        )
        
        if let existing = existing, existing.status != .rejected {
            throw SubmissionError.alreadySubmitted
        }
        
        // Create submission record
        let submission = ExerciseSubmission(
            challengeRef: challengeID,
            exerciseRef: exerciseID,
            userRef: userID,
            date: date,
            status: .pending
        )
        
        let record = submission.toRecord(videoFileURL: videoFileURL)
        
        do {
            let savedRecord = try await cloudKit.save(record: record)
            guard let savedSubmission = ExerciseSubmission(from: savedRecord) else {
                throw SubmissionError.videoUploadFailed
            }
            return savedSubmission
        } catch {
            throw SubmissionError.videoUploadFailed
        }
    }
    
    /// Fetch a specific submission
    func fetchSubmission(
        challengeID: String,
        exerciseID: String,
        userID: String,
        date: Date
    ) async throws -> ExerciseSubmission? {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: normalizedDate)!
        
        let challengeRecordID = CKRecord.ID(recordName: challengeID)
        let challengeRef = CKRecord.Reference(recordID: challengeRecordID, action: .none)
        
        let exerciseRecordID = CKRecord.ID(recordName: exerciseID)
        let exerciseRef = CKRecord.Reference(recordID: exerciseRecordID, action: .none)
        
        let userRecordID = CKRecord.ID(recordName: userID)
        let userRef = CKRecord.Reference(recordID: userRecordID, action: .none)
        
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@ AND %K == %@ AND %K >= %@ AND %K < %@",
            ExerciseSubmission.FieldKey.challengeRef.rawValue, challengeRef,
            ExerciseSubmission.FieldKey.exerciseRef.rawValue, exerciseRef,
            ExerciseSubmission.FieldKey.userRef.rawValue, userRef,
            ExerciseSubmission.FieldKey.date.rawValue, normalizedDate as NSDate,
            ExerciseSubmission.FieldKey.date.rawValue, nextDay as NSDate
        )
        
        let records = try await cloudKit.fetch(
            recordType: ExerciseSubmissionRecordType,
            predicate: predicate,
            resultsLimit: 1
        )
        
        guard let record = records.first else { return nil }
        return ExerciseSubmission(from: record)
    }
    
    /// Fetch all submissions for a user on a specific date
    func fetchSubmissions(
        challengeID: String,
        userID: String,
        date: Date
    ) async throws -> [ExerciseSubmission] {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: normalizedDate)!
        
        let challengeRecordID = CKRecord.ID(recordName: challengeID)
        let challengeRef = CKRecord.Reference(recordID: challengeRecordID, action: .none)
        
        let userRecordID = CKRecord.ID(recordName: userID)
        let userRef = CKRecord.Reference(recordID: userRecordID, action: .none)
        
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@ AND %K >= %@ AND %K < %@",
            ExerciseSubmission.FieldKey.challengeRef.rawValue, challengeRef,
            ExerciseSubmission.FieldKey.userRef.rawValue, userRef,
            ExerciseSubmission.FieldKey.date.rawValue, normalizedDate as NSDate,
            ExerciseSubmission.FieldKey.date.rawValue, nextDay as NSDate
        )
        
        let records = try await cloudKit.fetch(
            recordType: ExerciseSubmissionRecordType,
            predicate: predicate,
            resultsLimit: 20
        )
        
        return records.compactMap { ExerciseSubmission(from: $0) }
    }
    
    /// Fetch pending submissions to review (from other users)
    func fetchPendingSubmissionsToReview(
        challengeID: String,
        currentUserID: String
    ) async throws -> [ExerciseSubmission] {
        let challengeRecordID = CKRecord.ID(recordName: challengeID)
        let challengeRef = CKRecord.Reference(recordID: challengeRecordID, action: .none)
        
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@",
            ExerciseSubmission.FieldKey.challengeRef.rawValue, challengeRef,
            ExerciseSubmission.FieldKey.status.rawValue, SubmissionStatus.pending.rawValue
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: ExerciseSubmission.FieldKey.createdAt.rawValue,
            ascending: true
        )
        
        let records = try await cloudKit.fetch(
            recordType: ExerciseSubmissionRecordType,
            predicate: predicate,
            sortDescriptors: [sortDescriptor],
            resultsLimit: 100
        )
        
        // Filter out current user's submissions (can't review your own)
        return records
            .compactMap { ExerciseSubmission(from: $0) }
            .filter { $0.userRef != currentUserID }
    }
    
    /// Fetch all submissions for a challenge (for leaderboard)
    func fetchAllSubmissions(forChallengeID challengeID: String) async throws -> [ExerciseSubmission] {
        let challengeRecordID = CKRecord.ID(recordName: challengeID)
        let challengeRef = CKRecord.Reference(recordID: challengeRecordID, action: .none)
        
        let predicate = NSPredicate(
            format: "%K == %@",
            ExerciseSubmission.FieldKey.challengeRef.rawValue,
            challengeRef
        )
        
        let records = try await cloudKit.fetch(
            recordType: ExerciseSubmissionRecordType,
            predicate: predicate,
            resultsLimit: 1000
        )
        
        return records.compactMap { ExerciseSubmission(from: $0) }
    }
    
    // MARK: - Review Operations
    
    /// Approve a submission
    func approveSubmission(
        submissionID: String,
        reviewerID: String
    ) async throws -> ExerciseSubmission {
        return try await reviewSubmission(
            submissionID: submissionID,
            reviewerID: reviewerID,
            approved: true
        )
    }
    
    /// Reject a submission
    func rejectSubmission(
        submissionID: String,
        reviewerID: String
    ) async throws -> ExerciseSubmission {
        return try await reviewSubmission(
            submissionID: submissionID,
            reviewerID: reviewerID,
            approved: false
        )
    }
    
    /// Review a submission (approve or reject) and delete the video
    private func reviewSubmission(
        submissionID: String,
        reviewerID: String,
        approved: Bool
    ) async throws -> ExerciseSubmission {
        let recordID = CKRecord.ID(recordName: submissionID)
        let record = try await cloudKit.fetch(recordID: recordID)
        
        guard var submission = ExerciseSubmission(from: record) else {
            throw SubmissionError.submissionNotFound
        }
        
        // Verify reviewer is not the submitter
        if submission.userRef == reviewerID {
            throw SubmissionError.cannotReviewOwnSubmission
        }
        
        // Update submission
        submission.status = approved ? .approved : .rejected
        submission.reviewerRef = reviewerID
        submission.reviewedAt = Date()
        submission.pointsAwarded = approved ? 1 : 0
        submission.videoDeleted = true
        submission.updatedAt = Date()
        
        // Update record and delete video asset
        let updatedRecord = submission.updateRecordForReview(record)
        _ = try await cloudKit.save(record: updatedRecord)
        
        return submission
    }
    
    // MARK: - Leaderboard
    
    /// Calculate leaderboard for a challenge
    func calculateLeaderboard(
        forChallengeID challengeID: String,
        participants: [AppUser]
    ) async throws -> [LeaderboardEntry] {
        let submissions = try await fetchAllSubmissions(forChallengeID: challengeID)
        
        // Group submissions by user and calculate points
        var userPoints: [String: (points: Int, submissions: Int)] = [:]
        
        for submission in submissions where submission.status == .approved {
            let userID = submission.userRef
            let current = userPoints[userID] ?? (points: 0, submissions: 0)
            userPoints[userID] = (
                points: current.points + submission.pointsAwarded,
                submissions: current.submissions + 1
            )
        }
        
        // Create leaderboard entries
        var entries: [LeaderboardEntry] = []
        
        for participant in participants {
            let stats = userPoints[participant.id] ?? (points: 0, submissions: 0)
            entries.append(LeaderboardEntry(
                id: participant.id,
                user: participant,
                totalPoints: stats.points,
                approvedSubmissions: stats.submissions,
                rank: 0
            ))
        }
        
        // Sort by points descending
        entries.sort { $0.totalPoints > $1.totalPoints }
        
        // Assign ranks (handling ties)
        var currentRank = 1
        var previousPoints = -1
        
        for i in 0..<entries.count {
            if entries[i].totalPoints != previousPoints {
                currentRank = i + 1
            }
            entries[i].rank = currentRank
            previousPoints = entries[i].totalPoints
        }
        
        return entries
    }
    
    // MARK: - Calendar Status
    
    /// Get completion status for a date range (for calendar view)
    func getCompletionStatus(
        challengeID: String,
        userID: String,
        exerciseCount: Int,
        startDate: Date,
        endDate: Date
    ) async throws -> [DayCompletionStatus] {
        let challengeRecordID = CKRecord.ID(recordName: challengeID)
        let challengeRef = CKRecord.Reference(recordID: challengeRecordID, action: .none)
        
        let userRecordID = CKRecord.ID(recordName: userID)
        let userRef = CKRecord.Reference(recordID: userRecordID, action: .none)
        
        let normalizedStart = Calendar.current.startOfDay(for: startDate)
        let normalizedEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
        
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@ AND %K >= %@ AND %K < %@",
            ExerciseSubmission.FieldKey.challengeRef.rawValue, challengeRef,
            ExerciseSubmission.FieldKey.userRef.rawValue, userRef,
            ExerciseSubmission.FieldKey.date.rawValue, normalizedStart as NSDate,
            ExerciseSubmission.FieldKey.date.rawValue, normalizedEnd as NSDate
        )
        
        let records = try await cloudKit.fetch(
            recordType: ExerciseSubmissionRecordType,
            predicate: predicate,
            resultsLimit: 500
        )
        
        let submissions = records.compactMap { ExerciseSubmission(from: $0) }
        
        // Group by date
        var statusByDate: [Date: DayCompletionStatus] = [:]
        
        // Initialize all dates in range
        var currentDate = normalizedStart
        while currentDate <= Calendar.current.startOfDay(for: endDate) {
            let dateID = ISO8601DateFormatter().string(from: currentDate)
            statusByDate[currentDate] = DayCompletionStatus(
                id: dateID,
                date: currentDate,
                totalExercises: exerciseCount,
                approvedCount: 0,
                pendingCount: 0,
                rejectedCount: 0
            )
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Count submissions by status
        for submission in submissions {
            let date = Calendar.current.startOfDay(for: submission.date)
            guard var status = statusByDate[date] else { continue }
            
            switch submission.status {
            case .approved:
                status.approvedCount += 1
            case .pending:
                status.pendingCount += 1
            case .rejected:
                status.rejectedCount += 1
            }
            
            statusByDate[date] = status
        }
        
        return Array(statusByDate.values).sorted { $0.date < $1.date }
    }
}

