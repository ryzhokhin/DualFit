//
//  HomeViewModel.swift
//  DualFit
//
//  View model for the home screen showing user's challenges.
//

import Foundation
import SwiftUI

/// Summary data for a challenge on the home screen
struct ChallengeSummary: Identifiable, Equatable {
    let id: String
    let challenge: Challenge
    var totalPoints: Int
    var completedDays: Int
    var totalDays: Int
    var participantCount: Int
    
    var completionPercentage: Double {
        guard totalDays > 0 else { return 0 }
        return Double(completedDays) / Double(totalDays) * 100
    }
}

/// View model for the home screen
@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var challenges: [ChallengeSummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showCreateChallenge: Bool = false
    @Published var showJoinChallenge: Bool = false
    
    // MARK: - Properties
    
    private let challengeService = ChallengeService.shared
    private let submissionService = SubmissionService.shared
    
    private var currentUserID: String?
    
    // MARK: - Public Methods
    
    /// Load challenges for the current user
    func loadChallenges(userID: String) async {
        currentUserID = userID
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedChallenges = try await challengeService.fetchChallenges(forUserID: userID)
            
            // Build summaries with stats
            var summaries: [ChallengeSummary] = []
            
            for challenge in fetchedChallenges {
                // Get participant count
                let participants = try await challengeService.fetchParticipants(forChallengeID: challenge.id)
                
                // Get exercises
                let exercises = try await challengeService.fetchExercises(forChallengeID: challenge.id)
                let exerciseCount = exercises.count
                
                // Get completion status
                let statuses = try await submissionService.getCompletionStatus(
                    challengeID: challenge.id,
                    userID: userID,
                    exerciseCount: exerciseCount,
                    startDate: challenge.startDate,
                    endDate: min(challenge.endDate, Date())
                )
                
                // Count completed days and total points
                let completedDays = statuses.filter { $0.status == .complete }.count
                
                // Calculate total points
                let submissions = try await submissionService.fetchAllSubmissions(forChallengeID: challenge.id)
                let userSubmissions = submissions.filter { $0.userRef == userID && $0.status == .approved }
                let totalPoints = userSubmissions.reduce(0) { $0 + $1.pointsAwarded }
                
                let summary = ChallengeSummary(
                    id: challenge.id,
                    challenge: challenge,
                    totalPoints: totalPoints,
                    completedDays: completedDays,
                    totalDays: challenge.daysElapsed,
                    participantCount: participants.count
                )
                
                summaries.append(summary)
            }
            
            challenges = summaries
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Refresh challenges
    func refresh() async {
        guard let userID = currentUserID else { return }
        await loadChallenges(userID: userID)
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

