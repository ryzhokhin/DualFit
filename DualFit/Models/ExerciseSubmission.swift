//
//  ExerciseSubmission.swift
//  DualFit
//
//  Represents a user's video submission for an exercise on a specific day.
//

import Foundation
import FirebaseFirestore

/// Firestore subcollection name for submissions
let SubmissionsSubcollection = "submissions"

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
struct ExerciseSubmission: Identifiable, Equatable, Hashable, Codable {
    let id: String                    // Firestore document ID
    let challengeId: String           // Parent challenge ID
    let exerciseId: String            // Exercise ID
    let userId: String                // User ID (who submitted)
    let date: Date                    // The day this submission is for (date only)
    var videoUrl: String?             // Firebase Storage URL
    var status: SubmissionStatus
    var reviewerUserId: String?       // User ID who reviewed
    var reviewedAt: Date?
    var videoDeleted: Bool
    var pointsAwarded: Int
    let createdAt: Date
    var updatedAt: Date
    
    // MARK: - Computed Properties
    
    /// Whether the video is available for playback
    var isVideoAvailable: Bool {
        !videoDeleted && videoUrl != nil && !(videoUrl?.isEmpty ?? true)
    }
    
    /// Formatted date string for display
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Video URL as URL type
    var videoURL: URL? {
        guard let urlString = videoUrl, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case challengeId
        case exerciseId
        case userId
        case date
        case videoUrl
        case status
        case reviewerUserId
        case reviewedAt
        case videoDeleted
        case pointsAwarded
        case createdAt
        case updatedAt
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        challengeId: String,
        exerciseId: String,
        userId: String,
        date: Date,
        videoUrl: String? = nil,
        status: SubmissionStatus = .pending,
        reviewerUserId: String? = nil,
        reviewedAt: Date? = nil,
        videoDeleted: Bool = false,
        pointsAwarded: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.challengeId = challengeId
        self.exerciseId = exerciseId
        self.userId = userId
        // Normalize date to start of day
        self.date = Calendar.current.startOfDay(for: date)
        self.videoUrl = videoUrl
        self.status = status
        self.reviewerUserId = reviewerUserId
        self.reviewedAt = reviewedAt
        self.videoDeleted = videoDeleted
        self.pointsAwarded = pointsAwarded
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert to Firestore data dictionary
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "challengeId": challengeId,
            "exerciseId": exerciseId,
            "userId": userId,
            "date": Timestamp(date: date),
            "status": status.rawValue,
            "videoDeleted": videoDeleted,
            "pointsAwarded": pointsAwarded,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
        
        if let videoUrl = videoUrl {
            data["videoUrl"] = videoUrl
        }
        
        if let reviewerUserId = reviewerUserId {
            data["reviewerUserId"] = reviewerUserId
        }
        
        if let reviewedAt = reviewedAt {
            data["reviewedAt"] = Timestamp(date: reviewedAt)
        }
        
        return data
    }
    
    /// Initialize from Firestore document
    init?(from document: DocumentSnapshot, challengeId: String) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.challengeId = challengeId
        self.exerciseId = data["exerciseId"] as? String ?? ""
        self.userId = data["userId"] as? String ?? ""
        
        if let timestamp = data["date"] as? Timestamp {
            self.date = timestamp.dateValue()
        } else {
            self.date = Date()
        }
        
        self.videoUrl = data["videoUrl"] as? String
        
        let statusString = data["status"] as? String ?? "pending"
        self.status = SubmissionStatus(rawValue: statusString) ?? .pending
        
        self.reviewerUserId = data["reviewerUserId"] as? String
        
        if let timestamp = data["reviewedAt"] as? Timestamp {
            self.reviewedAt = timestamp.dateValue()
        } else {
            self.reviewedAt = nil
        }
        
        self.videoDeleted = data["videoDeleted"] as? Bool ?? false
        self.pointsAwarded = data["pointsAwarded"] as? Int ?? 0
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        if let timestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = Date()
        }
    }
}

// MARK: - Sample Data

extension ExerciseSubmission {
    static let sample = ExerciseSubmission(
        challengeId: Challenge.sample.id,
        exerciseId: ChallengeExercise.samples[0].id,
        userId: AppUser.sample.id,
        date: Date(),
        status: .pending
    )
}
