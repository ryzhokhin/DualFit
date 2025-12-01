//
//  SubmissionService.swift
//  DualFit
//
//  Handles exercise submission Firestore and Storage operations.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

/// Errors specific to submission operations
enum SubmissionError: LocalizedError {
    case submissionNotFound
    case alreadySubmitted
    case cannotReviewOwnSubmission
    case videoUploadFailed(Error)
    case invalidVideoFile
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .submissionNotFound:
            return "Submission not found."
        case .alreadySubmitted:
            return "You have already submitted for this exercise today."
        case .cannotReviewOwnSubmission:
            return "You cannot review your own submission."
        case .videoUploadFailed(let error):
            return "Failed to upload video: \(error.localizedDescription)"
        case .invalidVideoFile:
            return "Invalid video file. Please select a different video."
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
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
class SubmissionService {
    // MARK: - Singleton
    
    static let shared = SubmissionService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private func submissionsCollection(forChallengeId challengeId: String) -> CollectionReference {
        db.collection(ChallengesCollection)
            .document(challengeId)
            .collection(SubmissionsSubcollection)
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Video Upload
    
    /// Upload a video to Firebase Storage
    func uploadVideo(
        challengeId: String,
        exerciseId: String,
        userId: String,
        date: Date,
        videoFileURL: URL
    ) async throws -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Create storage path: videos/{challengeId}/{userId}/{date}/{exerciseId}.mp4
        let storagePath = "videos/\(challengeId)/\(userId)/\(dateString)/\(exerciseId).mp4"
        let storageRef = storage.reference().child(storagePath)
        
        do {
            // Read video data
            let videoData = try Data(contentsOf: videoFileURL)
            
            // Upload with metadata
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            
            _ = try await storageRef.putDataAsync(videoData, metadata: metadata)
            
            // Get download URL
            let downloadURL = try await storageRef.downloadURL()
            return downloadURL.absoluteString
        } catch {
            throw SubmissionError.videoUploadFailed(error)
        }
    }
    
    /// Delete a video from Firebase Storage
    func deleteVideo(videoUrl: String) async throws {
        guard !videoUrl.isEmpty else { return }
        
        do {
            // Create reference from URL
            let storageRef = storage.reference(forURL: videoUrl)
            try await storageRef.delete()
        } catch {
            // Ignore "object not found" errors
            let nsError = error as NSError
            if nsError.domain == StorageErrorDomain && nsError.code == StorageErrorCode.objectNotFound.rawValue {
                return
            }
            throw SubmissionError.deleteFailed(error)
        }
    }
    
    // MARK: - Submission CRUD
    
    /// Create a new exercise submission with video
    func createSubmission(
        challengeId: String,
        exerciseId: String,
        userId: String,
        date: Date,
        videoFileURL: URL
    ) async throws -> ExerciseSubmission {
        // Check if submission already exists for this exercise/date
        let existing = try await fetchSubmission(
            challengeId: challengeId,
            exerciseId: exerciseId,
            userId: userId,
            date: date
        )
        
        if let existing = existing, existing.status != .rejected {
            throw SubmissionError.alreadySubmitted
        }
        
        // Upload video first
        let videoUrl = try await uploadVideo(
            challengeId: challengeId,
            exerciseId: exerciseId,
            userId: userId,
            date: date,
            videoFileURL: videoFileURL
        )
        
        // Create submission record
        let submission = ExerciseSubmission(
            challengeId: challengeId,
            exerciseId: exerciseId,
            userId: userId,
            date: date,
            videoUrl: videoUrl,
            status: .pending
        )
        
        do {
            try await submissionsCollection(forChallengeId: challengeId)
                .document(submission.id)
                .setData(submission.toFirestore())
            
            return submission
        } catch {
            // If Firestore save fails, try to delete the uploaded video
            try? await deleteVideo(videoUrl: videoUrl)
            throw SubmissionError.saveFailed(error)
        }
    }
    
    /// Fetch a specific submission
    func fetchSubmission(
        challengeId: String,
        exerciseId: String,
        userId: String,
        date: Date
    ) async throws -> ExerciseSubmission? {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: normalizedDate)!
        
        do {
            let snapshot = try await submissionsCollection(forChallengeId: challengeId)
                .whereField("exerciseId", isEqualTo: exerciseId)
                .whereField("userId", isEqualTo: userId)
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: normalizedDate))
                .whereField("date", isLessThan: Timestamp(date: nextDay))
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first else { return nil }
            return ExerciseSubmission(from: document, challengeId: challengeId)
        } catch {
            throw SubmissionError.fetchFailed(error)
        }
    }
    
    /// Fetch all submissions for a user on a specific date
    func fetchSubmissions(
        challengeId: String,
        userId: String,
        date: Date
    ) async throws -> [ExerciseSubmission] {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: normalizedDate)!
        
        do {
            let snapshot = try await submissionsCollection(forChallengeId: challengeId)
                .whereField("userId", isEqualTo: userId)
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: normalizedDate))
                .whereField("date", isLessThan: Timestamp(date: nextDay))
                .getDocuments()
            
            return snapshot.documents.compactMap { ExerciseSubmission(from: $0, challengeId: challengeId) }
        } catch {
            throw SubmissionError.fetchFailed(error)
        }
    }
    
    /// Fetch pending submissions to review (from other users)
    func fetchPendingSubmissionsToReview(
        challengeId: String,
        currentUserId: String
    ) async throws -> [ExerciseSubmission] {
        do {
            let snapshot = try await submissionsCollection(forChallengeId: challengeId)
                .whereField("status", isEqualTo: SubmissionStatus.pending.rawValue)
                .order(by: "createdAt")
                .getDocuments()
            
            // Filter out current user's submissions (can't review your own)
            return snapshot.documents
                .compactMap { ExerciseSubmission(from: $0, challengeId: challengeId) }
                .filter { $0.userId != currentUserId }
        } catch {
            throw SubmissionError.fetchFailed(error)
        }
    }
    
    /// Fetch all submissions for a challenge (for leaderboard)
    func fetchAllSubmissions(forChallengeId challengeId: String) async throws -> [ExerciseSubmission] {
        do {
            let snapshot = try await submissionsCollection(forChallengeId: challengeId)
                .getDocuments()
            
            return snapshot.documents.compactMap { ExerciseSubmission(from: $0, challengeId: challengeId) }
        } catch {
            throw SubmissionError.fetchFailed(error)
        }
    }
    
    // MARK: - Review Operations
    
    /// Approve a submission
    func approveSubmission(
        submissionId: String,
        challengeId: String,
        reviewerUserId: String
    ) async throws -> ExerciseSubmission {
        return try await reviewSubmission(
            submissionId: submissionId,
            challengeId: challengeId,
            reviewerUserId: reviewerUserId,
            approved: true
        )
    }
    
    /// Reject a submission
    func rejectSubmission(
        submissionId: String,
        challengeId: String,
        reviewerUserId: String
    ) async throws -> ExerciseSubmission {
        return try await reviewSubmission(
            submissionId: submissionId,
            challengeId: challengeId,
            reviewerUserId: reviewerUserId,
            approved: false
        )
    }
    
    /// Review a submission (approve or reject) and delete the video
    private func reviewSubmission(
        submissionId: String,
        challengeId: String,
        reviewerUserId: String,
        approved: Bool
    ) async throws -> ExerciseSubmission {
        let docRef = submissionsCollection(forChallengeId: challengeId).document(submissionId)
        
        do {
            let document = try await docRef.getDocument()
            
            guard var submission = ExerciseSubmission(from: document, challengeId: challengeId) else {
                throw SubmissionError.submissionNotFound
            }
            
            // Verify reviewer is not the submitter
            if submission.userId == reviewerUserId {
                throw SubmissionError.cannotReviewOwnSubmission
            }
            
            // Delete the video from storage
            if let videoUrl = submission.videoUrl, !videoUrl.isEmpty {
                try? await deleteVideo(videoUrl: videoUrl)
            }
            
            // Update submission
            submission.status = approved ? .approved : .rejected
            submission.reviewerUserId = reviewerUserId
            submission.reviewedAt = Date()
            submission.pointsAwarded = approved ? 1 : 0
            submission.videoDeleted = true
            submission.videoUrl = nil
            submission.updatedAt = Date()
            
            // Save updated submission
            try await docRef.setData(submission.toFirestore())
            
            return submission
        } catch let error as SubmissionError {
            throw error
        } catch {
            throw SubmissionError.saveFailed(error)
        }
    }
    
    // MARK: - Leaderboard
    
    /// Calculate leaderboard for a challenge
    func calculateLeaderboard(
        forChallengeId challengeId: String,
        participants: [AppUser]
    ) async throws -> [LeaderboardEntry] {
        let submissions = try await fetchAllSubmissions(forChallengeId: challengeId)
        
        // Group submissions by user and calculate points
        var userPoints: [String: (points: Int, submissions: Int)] = [:]
        
        for submission in submissions where submission.status == .approved {
            let userId = submission.userId
            let current = userPoints[userId] ?? (points: 0, submissions: 0)
            userPoints[userId] = (
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
        challengeId: String,
        userId: String,
        exerciseCount: Int,
        startDate: Date,
        endDate: Date
    ) async throws -> [DayCompletionStatus] {
        let normalizedStart = Calendar.current.startOfDay(for: startDate)
        let normalizedEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
        
        do {
            let snapshot = try await submissionsCollection(forChallengeId: challengeId)
                .whereField("userId", isEqualTo: userId)
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: normalizedStart))
                .whereField("date", isLessThan: Timestamp(date: normalizedEnd))
                .getDocuments()
            
            let submissions = snapshot.documents.compactMap { ExerciseSubmission(from: $0, challengeId: challengeId) }
            
            // Group by date
            var statusByDate: [Date: DayCompletionStatus] = [:]
            
            // Initialize all dates in range
            var currentDate = normalizedStart
            while currentDate <= Calendar.current.startOfDay(for: endDate) {
                let dateId = ISO8601DateFormatter().string(from: currentDate)
                statusByDate[currentDate] = DayCompletionStatus(
                    id: dateId,
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
        } catch {
            throw SubmissionError.fetchFailed(error)
        }
    }
}
