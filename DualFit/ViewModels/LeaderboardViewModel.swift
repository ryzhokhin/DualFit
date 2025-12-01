//
//  LeaderboardViewModel.swift
//  DualFit
//
//  View model for the leaderboard showing participant rankings.
//

import Foundation
import SwiftUI

/// View model for the leaderboard tab
@MainActor
class LeaderboardViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var entries: [LeaderboardEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Properties
    
    private let challengeID: String
    private let currentUserID: String
    private var participants: [AppUser] = []
    
    private let submissionService = SubmissionService.shared
    
    // MARK: - Computed Properties
    
    var winner: LeaderboardEntry? {
        entries.first
    }
    
    var hasWinner: Bool {
        guard let first = entries.first else { return false }
        return first.totalPoints > 0
    }
    
    var currentUserEntry: LeaderboardEntry? {
        entries.first { $0.user.id == currentUserID }
    }
    
    var currentUserRank: Int {
        currentUserEntry?.rank ?? 0
    }
    
    var isTied: Bool {
        guard entries.count >= 2 else { return false }
        return entries[0].totalPoints == entries[1].totalPoints && entries[0].totalPoints > 0
    }
    
    // MARK: - Initialization
    
    init(challengeID: String, currentUserID: String) {
        self.challengeID = challengeID
        self.currentUserID = currentUserID
    }
    
    // MARK: - Public Methods
    
    /// Set participants (called from parent view model)
    func setParticipants(_ participants: [AppUser]) {
        self.participants = participants
    }
    
    /// Load leaderboard data
    func loadLeaderboard() async {
        guard !participants.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            entries = try await submissionService.calculateLeaderboard(
                forChallengeID: challengeID,
                participants: participants
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Get rank badge for position
    func rankBadge(for rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }
    
    /// Check if entry is current user
    func isCurrentUser(_ entry: LeaderboardEntry) -> Bool {
        entry.user.id == currentUserID
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

