//
//  ChallengeService.swift
//  DualFit
//
//  Handles challenge-related Firestore operations.
//

import Foundation
import FirebaseFirestore

/// Errors specific to challenge operations
enum ChallengeError: LocalizedError {
    case challengeNotFound
    case challengeFull
    case alreadyJoined
    case invalidJoinCode
    case notParticipant
    case saveFailed(Error)
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .challengeNotFound:
            return "Challenge not found. Please check the join code."
        case .challengeFull:
            return "This challenge is full (max 10 participants)."
        case .alreadyJoined:
            return "You have already joined this challenge."
        case .invalidJoinCode:
            return "Invalid join code. Please check and try again."
        case .notParticipant:
            return "You are not a participant in this challenge."
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        }
    }
}

/// Service for managing challenges in Firestore
class ChallengeService {
    // MARK: - Singleton
    
    static let shared = ChallengeService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    
    private var challengesCollection: CollectionReference {
        db.collection(ChallengesCollection)
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Challenge CRUD
    
    /// Create a new challenge with exercises
    func createChallenge(
        name: String,
        description: String,
        startDate: Date,
        endDate: Date,
        exercises: [(name: String, reps: Int)],
        creatorUserId: String
    ) async throws -> (challenge: Challenge, exercises: [ChallengeExercise]) {
        let challengeId = UUID().uuidString
        
        // Create the challenge
        let challenge = Challenge(
            id: challengeId,
            name: name,
            description: description,
            createdByUserId: creatorUserId,
            startDate: startDate,
            endDate: endDate
        )
        
        // Create exercises
        var exerciseRecords: [ChallengeExercise] = []
        for (index, exercise) in exercises.enumerated() {
            let challengeExercise = ChallengeExercise(
                challengeId: challengeId,
                name: exercise.name,
                dailyRequiredReps: exercise.reps,
                order: index
            )
            exerciseRecords.append(challengeExercise)
        }
        
        // Create participant record for creator
        let participant = ChallengeParticipant(
            challengeId: challengeId,
            userId: creatorUserId
        )
        
        // Use a batch write for atomicity
        let batch = db.batch()
        
        // Add challenge
        let challengeRef = challengesCollection.document(challengeId)
        batch.setData(challenge.toFirestore(), forDocument: challengeRef)
        
        // Add exercises
        for exercise in exerciseRecords {
            let exerciseRef = challengeRef.collection(ExercisesSubcollection).document(exercise.id)
            batch.setData(exercise.toFirestore(), forDocument: exerciseRef)
        }
        
        // Add creator as participant
        let participantRef = challengeRef.collection(ParticipantsSubcollection).document(participant.id)
        batch.setData(participant.toFirestore(), forDocument: participantRef)
        
        do {
            try await batch.commit()
            return (challenge, exerciseRecords)
        } catch {
            throw ChallengeError.saveFailed(error)
        }
    }
    
    /// Fetch a challenge by its ID
    func fetchChallenge(byId challengeId: String) async throws -> Challenge? {
        do {
            let document = try await challengesCollection.document(challengeId).getDocument()
            guard document.exists else { return nil }
            return Challenge(from: document)
        } catch {
            throw ChallengeError.fetchFailed(error)
        }
    }
    
    /// Fetch a challenge by join code (first 8 chars of ID)
    func fetchChallenge(byJoinCode joinCode: String) async throws -> Challenge? {
        let normalizedCode = joinCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard normalizedCode.count >= 6 else {
            throw ChallengeError.invalidJoinCode
        }
        
        do {
            // Fetch all challenges and find the one matching the code
            // Note: For production, consider adding a 'joinCode' field to index
            let snapshot = try await challengesCollection.getDocuments()
            
            for document in snapshot.documents {
                let recordId = document.documentID
                let recordCode = String(recordId.prefix(8)).uppercased()
                if recordCode == normalizedCode {
                    return Challenge(from: document)
                }
            }
            
            return nil
        } catch {
            throw ChallengeError.fetchFailed(error)
        }
    }
    
    /// Fetch all challenges a user participates in
    func fetchChallenges(forUserId userId: String) async throws -> [Challenge] {
        do {
            // Query all challenges and check participation
            // Note: For production scale, consider a different data model
            let challengesSnapshot = try await challengesCollection.getDocuments()
            
            var userChallenges: [Challenge] = []
            
            for challengeDoc in challengesSnapshot.documents {
                guard let challenge = Challenge(from: challengeDoc) else { continue }
                
                // Check if user is a participant
                let participantsSnapshot = try await challengesCollection
                    .document(challenge.id)
                    .collection(ParticipantsSubcollection)
                    .whereField("userId", isEqualTo: userId)
                    .getDocuments()
                
                if !participantsSnapshot.documents.isEmpty {
                    userChallenges.append(challenge)
                }
            }
            
            // Sort by start date, most recent first
            return userChallenges.sorted { $0.startDate > $1.startDate }
        } catch {
            throw ChallengeError.fetchFailed(error)
        }
    }
    
    // MARK: - Exercises
    
    /// Fetch exercises for a challenge
    func fetchExercises(forChallengeId challengeId: String) async throws -> [ChallengeExercise] {
        do {
            let snapshot = try await challengesCollection
                .document(challengeId)
                .collection(ExercisesSubcollection)
                .order(by: "order")
                .getDocuments()
            
            return snapshot.documents.compactMap { ChallengeExercise(from: $0, challengeId: challengeId) }
        } catch {
            throw ChallengeError.fetchFailed(error)
        }
    }
    
    // MARK: - Participants
    
    /// Join a challenge
    func joinChallenge(challengeId: String, userId: String) async throws -> ChallengeParticipant {
        // Check if challenge exists
        guard let challenge = try await fetchChallenge(byId: challengeId) else {
            throw ChallengeError.challengeNotFound
        }
        
        // Check if already joined
        let participants = try await fetchParticipants(forChallengeId: challengeId)
        if participants.contains(where: { $0.userId == userId }) {
            throw ChallengeError.alreadyJoined
        }
        
        // Check if challenge is full
        if participants.count >= challenge.maxParticipants {
            throw ChallengeError.challengeFull
        }
        
        // Create participant record
        let participant = ChallengeParticipant(
            challengeId: challengeId,
            userId: userId
        )
        
        do {
            try await challengesCollection
                .document(challengeId)
                .collection(ParticipantsSubcollection)
                .document(participant.id)
                .setData(participant.toFirestore())
            
            return participant
        } catch {
            throw ChallengeError.saveFailed(error)
        }
    }
    
    /// Fetch participants for a challenge
    func fetchParticipants(forChallengeId challengeId: String) async throws -> [ChallengeParticipant] {
        do {
            let snapshot = try await challengesCollection
                .document(challengeId)
                .collection(ParticipantsSubcollection)
                .getDocuments()
            
            return snapshot.documents.compactMap { ChallengeParticipant(from: $0, challengeId: challengeId) }
        } catch {
            throw ChallengeError.fetchFailed(error)
        }
    }
    
    /// Fetch participant users for a challenge (with user details)
    func fetchParticipantUsers(forChallengeId challengeId: String) async throws -> [AppUser] {
        let participants = try await fetchParticipants(forChallengeId: challengeId)
        let userIds = participants.map { $0.userId }
        return try await UserService.shared.fetchUsers(byIds: userIds)
    }
    
    /// Check if a user is a participant in a challenge
    func isUserParticipant(userId: String, challengeId: String) async throws -> Bool {
        let participants = try await fetchParticipants(forChallengeId: challengeId)
        return participants.contains { $0.userId == userId }
    }
}
