//
//  ChallengeService.swift
//  DualFit
//
//  Handles challenge-related operations.
//

import Foundation
import CloudKit

/// Errors specific to challenge operations
enum ChallengeError: LocalizedError {
    case challengeNotFound
    case challengeFull
    case alreadyJoined
    case invalidJoinCode
    case notParticipant
    
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
        }
    }
}

/// Service for managing challenges
actor ChallengeService {
    // MARK: - Singleton
    
    static let shared = ChallengeService()
    
    // MARK: - Properties
    
    private let cloudKit = CloudKitManager.shared
    
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
        creatorUserID: String
    ) async throws -> (challenge: Challenge, exercises: [ChallengeExercise]) {
        // Create the challenge
        let challenge = Challenge(
            name: name,
            description: description,
            createdByUserRef: creatorUserID,
            startDate: startDate,
            endDate: endDate
        )
        
        // Create exercises
        var exerciseRecords: [ChallengeExercise] = []
        for (index, exercise) in exercises.enumerated() {
            let challengeExercise = ChallengeExercise(
                challengeRef: challenge.id,
                name: exercise.name,
                dailyRequiredReps: exercise.reps,
                order: index
            )
            exerciseRecords.append(challengeExercise)
        }
        
        // Create participant record for creator
        let participant = ChallengeParticipant(
            challengeRef: challenge.id,
            userRef: creatorUserID
        )
        
        // Save all records
        var allRecords: [CKRecord] = [challenge.toRecord()]
        allRecords.append(contentsOf: exerciseRecords.map { $0.toRecord() })
        allRecords.append(participant.toRecord())
        
        _ = try await cloudKit.saveMultiple(records: allRecords)
        
        return (challenge, exerciseRecords)
    }
    
    /// Fetch a challenge by its ID
    func fetchChallenge(byID challengeID: String) async throws -> Challenge? {
        let recordID = CKRecord.ID(recordName: challengeID)
        
        do {
            let record = try await cloudKit.fetch(recordID: recordID)
            return Challenge(from: record)
        } catch CloudKitError.recordNotFound {
            return nil
        }
    }
    
    /// Fetch a challenge by join code (first 8 chars of ID)
    func fetchChallenge(byJoinCode joinCode: String) async throws -> Challenge? {
        // The join code is the first 8 characters of the challenge ID (uppercased)
        let normalizedCode = joinCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard normalizedCode.count >= 6 else {
            throw ChallengeError.invalidJoinCode
        }
        
        // Fetch all challenges and find the one matching the code
        // In production, you might want a separate indexed field for this
        let records = try await cloudKit.fetch(
            recordType: ChallengeRecordType,
            resultsLimit: 200
        )
        
        for record in records {
            let recordName = record.recordID.recordName
            let recordCode = String(recordName.prefix(8)).uppercased()
            if recordCode == normalizedCode {
                return Challenge(from: record)
            }
        }
        
        return nil
    }
    
    /// Fetch all challenges a user participates in
    func fetchChallenges(forUserID userID: String) async throws -> [Challenge] {
        // First, get all participant records for this user
        let userRecordID = CKRecord.ID(recordName: userID)
        let userRef = CKRecord.Reference(recordID: userRecordID, action: .none)
        
        let participantPredicate = NSPredicate(
            format: "%K == %@",
            ChallengeParticipant.FieldKey.userRef.rawValue,
            userRef
        )
        
        let participantRecords = try await cloudKit.fetch(
            recordType: ChallengeParticipantRecordType,
            predicate: participantPredicate,
            resultsLimit: 100
        )
        
        // Extract challenge IDs
        let challengeIDs = participantRecords.compactMap { record -> String? in
            guard let ref = record[ChallengeParticipant.FieldKey.challengeRef.rawValue] as? CKRecord.Reference else {
                return nil
            }
            return ref.recordID.recordName
        }
        
        // Fetch all challenges
        var challenges: [Challenge] = []
        for challengeID in challengeIDs {
            if let challenge = try await fetchChallenge(byID: challengeID) {
                challenges.append(challenge)
            }
        }
        
        // Sort by start date, most recent first
        return challenges.sorted { $0.startDate > $1.startDate }
    }
    
    // MARK: - Exercises
    
    /// Fetch exercises for a challenge
    func fetchExercises(forChallengeID challengeID: String) async throws -> [ChallengeExercise] {
        let challengeRecordID = CKRecord.ID(recordName: challengeID)
        let challengeRef = CKRecord.Reference(recordID: challengeRecordID, action: .none)
        
        let predicate = NSPredicate(
            format: "%K == %@",
            ChallengeExercise.FieldKey.challengeRef.rawValue,
            challengeRef
        )
        
        let sortDescriptor = NSSortDescriptor(key: ChallengeExercise.FieldKey.order.rawValue, ascending: true)
        
        let records = try await cloudKit.fetch(
            recordType: ChallengeExerciseRecordType,
            predicate: predicate,
            sortDescriptors: [sortDescriptor],
            resultsLimit: 20
        )
        
        return records.compactMap { ChallengeExercise(from: $0) }
    }
    
    // MARK: - Participants
    
    /// Join a challenge
    func joinChallenge(challengeID: String, userID: String) async throws -> ChallengeParticipant {
        // Check if challenge exists
        guard let challenge = try await fetchChallenge(byID: challengeID) else {
            throw ChallengeError.challengeNotFound
        }
        
        // Check if already joined
        let participants = try await fetchParticipants(forChallengeID: challengeID)
        if participants.contains(where: { $0.userRef == userID }) {
            throw ChallengeError.alreadyJoined
        }
        
        // Check if challenge is full
        if participants.count >= challenge.maxParticipants {
            throw ChallengeError.challengeFull
        }
        
        // Create participant record
        let participant = ChallengeParticipant(
            challengeRef: challengeID,
            userRef: userID
        )
        
        _ = try await cloudKit.save(record: participant.toRecord())
        
        return participant
    }
    
    /// Fetch participants for a challenge
    func fetchParticipants(forChallengeID challengeID: String) async throws -> [ChallengeParticipant] {
        let challengeRecordID = CKRecord.ID(recordName: challengeID)
        let challengeRef = CKRecord.Reference(recordID: challengeRecordID, action: .none)
        
        let predicate = NSPredicate(
            format: "%K == %@",
            ChallengeParticipant.FieldKey.challengeRef.rawValue,
            challengeRef
        )
        
        let records = try await cloudKit.fetch(
            recordType: ChallengeParticipantRecordType,
            predicate: predicate,
            resultsLimit: 15
        )
        
        return records.compactMap { ChallengeParticipant(from: $0) }
    }
    
    /// Fetch participant users for a challenge (with user details)
    func fetchParticipantUsers(forChallengeID challengeID: String) async throws -> [AppUser] {
        let participants = try await fetchParticipants(forChallengeID: challengeID)
        let userIDs = participants.map { $0.userRef }
        return try await UserService.shared.fetchUsers(byIDs: userIDs)
    }
    
    /// Check if a user is a participant in a challenge
    func isUserParticipant(userID: String, challengeID: String) async throws -> Bool {
        let participants = try await fetchParticipants(forChallengeID: challengeID)
        return participants.contains { $0.userRef == userID }
    }
}

