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
    
    let currentUserID: String
    
    // MARK: - Initialization
    
    init(challenge: Challenge, currentUserID: String) {
        self.challenge = challenge
        self.currentUserID = currentUserID
        
        // Initialize child view models
        self.todayViewModel = TodayViewModel(challengeID: challenge.id, currentUserID: currentUserID)
        self.reviewViewModel = ReviewViewModel(challengeID: challenge.id, currentUserID: currentUserID)
        self.calendarViewModel = CalendarViewModel(challengeID: challenge.id, currentUserID: currentUserID)
        self.leaderboardViewModel = LeaderboardViewModel(challengeID: challenge.id, currentUserID: currentUserID)
    }
    
    // MARK: - Public Methods
    
    /// Load all challenge data
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load exercises
            exercises = try await challengeService.fetchExercises(forChallengeID: challenge.id)
            
            // Load participants
            participants = try await challengeService.fetchParticipantUsers(forChallengeID: challenge.id)
            
            // Update child view models with shared data
            await todayViewModel.setExercises(exercises)
            await reviewViewModel.setExercises(exercises)
            await reviewViewModel.setParticipants(participants)
            await calendarViewModel.setExercises(exercises)
            await calendarViewModel.setChallenge(challenge)
            await leaderboardViewModel.setParticipants(participants)
            
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
                challengeID: challenge.id,
                currentUserID: currentUserID
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

