//
//  ChallengeExercise.swift
//  DualFit
//
//  Represents an exercise within a challenge.
//

import Foundation
import FirebaseFirestore

/// Firestore subcollection name for exercises
let ExercisesSubcollection = "exercises"

/// Represents an exercise within a fitness challenge
struct ChallengeExercise: Identifiable, Equatable, Hashable, Codable {
    let id: String                    // Firestore document ID
    let challengeId: String           // Parent challenge ID
    var name: String
    var dailyRequiredReps: Int
    var order: Int                    // For sorting exercises in UI
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case challengeId
        case name
        case dailyRequiredReps
        case order
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        challengeId: String,
        name: String,
        dailyRequiredReps: Int = 10,
        order: Int = 0
    ) {
        self.id = id
        self.challengeId = challengeId
        self.name = name
        self.dailyRequiredReps = dailyRequiredReps
        self.order = order
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert to Firestore data dictionary
    func toFirestore() -> [String: Any] {
        return [
            "id": id,
            "challengeId": challengeId,
            "name": name,
            "dailyRequiredReps": dailyRequiredReps,
            "order": order
        ]
    }
    
    /// Initialize from Firestore document
    init?(from document: DocumentSnapshot, challengeId: String) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.challengeId = challengeId
        self.name = data["name"] as? String ?? "Unknown Exercise"
        self.dailyRequiredReps = data["dailyRequiredReps"] as? Int ?? 10
        self.order = data["order"] as? Int ?? 0
    }
}

// MARK: - Sample Data

extension ChallengeExercise {
    static let samples: [ChallengeExercise] = [
        ChallengeExercise(challengeId: Challenge.sample.id, name: "Push-ups", dailyRequiredReps: 10, order: 0),
        ChallengeExercise(challengeId: Challenge.sample.id, name: "Squats", dailyRequiredReps: 15, order: 1),
        ChallengeExercise(challengeId: Challenge.sample.id, name: "Planks", dailyRequiredReps: 1, order: 2),
        ChallengeExercise(challengeId: Challenge.sample.id, name: "Burpees", dailyRequiredReps: 5, order: 3)
    ]
}
