//
//  ChallengeParticipant.swift
//  DualFit
//
//  Links users to challenges they participate in.
//

import Foundation
import FirebaseFirestore

/// Firestore subcollection name for participants
let ParticipantsSubcollection = "participants"

/// Represents a user's participation in a challenge
struct ChallengeParticipant: Identifiable, Equatable, Hashable, Codable {
    let id: String                    // Firestore document ID
    let challengeId: String           // Parent challenge ID
    let userId: String                // User ID who joined
    let joinedAt: Date
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case challengeId
        case userId
        case joinedAt
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        challengeId: String,
        userId: String,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.challengeId = challengeId
        self.userId = userId
        self.joinedAt = joinedAt
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert to Firestore data dictionary
    func toFirestore() -> [String: Any] {
        return [
            "id": id,
            "challengeId": challengeId,
            "userId": userId,
            "joinedAt": Timestamp(date: joinedAt)
        ]
    }
    
    /// Initialize from Firestore document
    init?(from document: DocumentSnapshot, challengeId: String) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.challengeId = challengeId
        self.userId = data["userId"] as? String ?? ""
        
        if let timestamp = data["joinedAt"] as? Timestamp {
            self.joinedAt = timestamp.dateValue()
        } else {
            self.joinedAt = Date()
        }
    }
}

// MARK: - Sample Data

extension ChallengeParticipant {
    static let sample = ChallengeParticipant(
        challengeId: Challenge.sample.id,
        userId: AppUser.sample.id
    )
}
