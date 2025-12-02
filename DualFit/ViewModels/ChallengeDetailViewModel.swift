//
//  ChallengeDetailViewModel.swift
//  DualFit
//
//  View model for challenge detail screen (coordinates sub-views).
//

import Foundation
import SwiftUI

/// Tabs available in the challenge detail view
enum ChallengeTab: String, CaseIterable {
    case today = "Today"
    case review = "Review"
    case calendar = "Calendar"
    case leaderboard = "Leaderboard"
    
    var icon: String {
        switch self {
        case .today: return "calendar.day.timeline.left"
        case .review: return "checkmark.circle"
        case .calendar: return "calendar"
        case .leaderboard: return "trophy"
        }
    }
}

/// View model for the challenge detail screen
@MainActor
class ChallengeDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var challenge: Challenge
    @Published var exercises: [ChallengeExercise] = []
    @Published var participants: [AppUser] = []
    @Published var selectedTab: ChallengeTab = .today
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var pendingReviewCount: Int = 0
    
    // MARK: - Child ViewModels
    
    @Published var todayViewModel: TodayViewModel
    @Published var reviewViewModel: ReviewViewModel
    @Published var calendarViewModel: CalendarViewModel
    @Published var leaderboardViewModel: LeaderboardViewModel
    
    // MARK: - Properties
    
    private let challengeService = ChallengeService.shared
    private let submissionService = SubmissionService.shared
    
    let currentUserId: String
    
    // MARK: - Initialization
    
    init(challenge: Challenge, currentUserId: String) {
        self.challenge = challenge
        self.currentUserId = currentUserId
        
        // Initialize child view models
        self.todayViewModel = TodayViewModel(challengeId: challenge.id, currentUserId: currentUserId)
        self.reviewViewModel = ReviewViewModel(challengeId: challenge.id, currentUserId: currentUserId)
        self.calendarViewModel = CalendarViewModel(challengeId: challenge.id, currentUserId: currentUserId)
        self.leaderboardViewModel = LeaderboardViewModel(challengeId: challenge.id, currentUserId: currentUserId)
    }
    
    // MARK: - Public Methods
    
    /// Load all challenge data
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load exercises
            exercises = try await challengeService.fetchExercises(forChallengeId: challenge.id)
            
            // Load participants
            participants = try await challengeService.fetchParticipantUsers(forChallengeId: challenge.id)
            
            // Update child view models with shared data
            todayViewModel.setExercises(exercises)
            reviewViewModel.setExercises(exercises)
            reviewViewModel.setParticipants(participants)
            calendarViewModel.setExercises(exercises)
            calendarViewModel.setChallenge(challenge)
            leaderboardViewModel.setParticipants(participants)
            
            // Load data for each tab
            await loadTabData()
            
            // Update pending review count
            await updatePendingReviewCount()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Refresh current tab data
    func refreshCurrentTab() async {
        switch selectedTab {
        case .today:
            await todayViewModel.loadSubmissions()
        case .review:
            await reviewViewModel.loadPendingSubmissions()
            await updatePendingReviewCount()
        case .calendar:
            await calendarViewModel.loadCompletionStatus()
        case .leaderboard:
            await leaderboardViewModel.loadLeaderboard()
        }
    }
    
    /// Load data for all tabs
    private func loadTabData() async {
        await todayViewModel.loadSubmissions()
        await reviewViewModel.loadPendingSubmissions()
        await calendarViewModel.loadCompletionStatus()
        await leaderboardViewModel.loadLeaderboard()
    }
    
    /// Update the pending review count badge
    func updatePendingReviewCount() async {
        do {
            let pending = try await submissionService.fetchPendingSubmissionsToReview(
                challengeId: challenge.id,
                currentUserId: currentUserId
            )
            pendingReviewCount = pending.count
        } catch {
            pendingReviewCount = 0
        }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

