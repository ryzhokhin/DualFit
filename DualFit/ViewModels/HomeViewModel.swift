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
    var userRank: Int? // User's rank in the leaderboard (nil if not calculated or challenge hasn't ended)
    
    var completionPercentage: Double {
        guard totalDays > 0 else { return 0 }
        // Progress = days elapsed / total challenge days
        return Double(challenge.daysElapsed) / Double(totalDays) * 100
    }
    
    /// Whether user got a top 3 place (only meaningful for ended challenges)
    var isTopThree: Bool {
        guard let rank = userRank else { return false }
        return rank >= 1 && rank <= 3
    }
    
    /// Emoji badge for user's place (1st, 2nd, 3rd)
    var placeBadge: String {
        guard let rank = userRank else { return "" }
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
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
    
    private var currentUserId: String?
    
    // MARK: - Public Methods
    
    /// Load challenges for the current user
    func loadChallenges(userId: String) async {
        currentUserId = userId
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedChallenges = try await challengeService.fetchChallenges(forUserId: userId)
            
            // Build summaries with stats
            var summaries: [ChallengeSummary] = []
            
            for challenge in fetchedChallenges {
                // Get participant count (using ChallengeParticipant for count)
                let participantRecords = try await challengeService.fetchParticipants(forChallengeId: challenge.id)
                let participantCount = participantRecords.count
                
                // Get participant users (AppUser objects) for leaderboard calculation
                let participantUsers = try await challengeService.fetchParticipantUsers(forChallengeId: challenge.id)
                
                // Get exercises
                let exercises = try await challengeService.fetchExercises(forChallengeId: challenge.id)
                let exerciseCount = exercises.count
                
                // Get completion status
                let statuses = try await submissionService.getCompletionStatus(
                    challengeId: challenge.id,
                    userId: userId,
                    exerciseCount: exerciseCount,
                    startDate: challenge.startDate,
                    endDate: min(challenge.endDate, Date())
                )
                
                // Count completed days and total points
                let completedDays = statuses.filter { $0.status == .complete }.count
                
                // Calculate total points
                let submissions = try await submissionService.fetchAllSubmissions(forChallengeId: challenge.id)
                let userSubmissions = submissions.filter { $0.userId == userId && $0.status == .approved }
                let totalPoints = userSubmissions.reduce(0) { $0 + $1.pointsAwarded }
                
                // Calculate user rank if challenge has ended
                var userRank: Int? = nil
                if challenge.hasEnded {
                    let leaderboardEntries = try await submissionService.calculateLeaderboard(
                        forChallengeId: challenge.id,
                        participants: participantUsers
                    )
                    userRank = leaderboardEntries.first { $0.user.id == userId }?.rank
                }
                
                let summary = ChallengeSummary(
                    id: challenge.id,
                    challenge: challenge,
                    totalPoints: totalPoints,
                    completedDays: completedDays,
                    totalDays: challenge.totalDays, // Total days in challenge (not elapsed)
                    participantCount: participantCount,
                    userRank: userRank
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
        guard let userId = currentUserId else { return }
        await loadChallenges(userId: userId)
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
