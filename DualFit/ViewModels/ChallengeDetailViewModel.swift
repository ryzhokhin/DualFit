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
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .today: return "calendar.day.timeline.left"
        case .review: return "checkmark.circle"
        case .calendar: return "calendar"
        case .leaderboard: return "trophy"
        case .settings: return "gearshape"
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
    @Published var selectedTab: ChallengeTab
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var pendingReviewCount: Int = 0
    
    // MARK: - Computed Properties
    
    /// Whether the current user is the creator of this challenge
    var isCreator: Bool {
        challenge.createdByUserId == currentUserId && !currentUserId.isEmpty
    }
    
    /// Tabs visible to the current user (settings only for creator, today hidden if ended)
    var visibleTabs: [ChallengeTab] {
        var tabs: [ChallengeTab] = []
        
        // Hide Today tab if challenge has ended
        if !challenge.hasEnded {
            tabs.append(.today)
        }
        
        tabs.append(contentsOf: [.review, .calendar, .leaderboard])
        
        if isCreator {
            tabs.append(.settings)
        }
        return tabs
    }
    
    // MARK: - Child ViewModels
    
    @Published var todayViewModel: TodayViewModel
    @Published var reviewViewModel: ReviewViewModel
    @Published var calendarViewModel: CalendarViewModel
    @Published var leaderboardViewModel: LeaderboardViewModel
    @Published var settingsViewModel: SettingsViewModel
    
    // MARK: - Properties
    
    private let challengeService = ChallengeService.shared
    private let submissionService = SubmissionService.shared
    
    var currentUserId: String
    
    // MARK: - Initialization
    
    init(challenge: Challenge, currentUserId: String) {
        self.challenge = challenge
        self.currentUserId = currentUserId
        
        // Set default tab: Leaderboard for ended challenges, Today for active challenges
        self.selectedTab = challenge.hasEnded ? .leaderboard : .today
        
        // Initialize child view models
        self.todayViewModel = TodayViewModel(challengeId: challenge.id, currentUserId: currentUserId)
        self.reviewViewModel = ReviewViewModel(challengeId: challenge.id, currentUserId: currentUserId)
        self.calendarViewModel = CalendarViewModel(challengeId: challenge.id, currentUserId: currentUserId)
        self.leaderboardViewModel = LeaderboardViewModel(challengeId: challenge.id, currentUserId: currentUserId)
        self.settingsViewModel = SettingsViewModel(challenge: challenge)
    }
    
    // MARK: - Public Methods
    
    /// Load all challenge data
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Refresh challenge data to get latest end date
            if let updatedChallenge = try await challengeService.fetchChallenge(byId: challenge.id) {
                challenge = updatedChallenge
                
                // If challenge has ended and we're on Today tab, switch to Leaderboard
                if challenge.hasEnded && selectedTab == .today {
                    selectedTab = .leaderboard
                }
            }
            
            // Load exercises
            exercises = try await challengeService.fetchExercises(forChallengeId: challenge.id)
            
            // Load participants
            participants = try await challengeService.fetchParticipantUsers(forChallengeId: challenge.id)
            
            // Update child view models with shared data
            todayViewModel.setExercises(exercises)
            todayViewModel.setChallenge(challenge)
            reviewViewModel.setExercises(exercises)
            reviewViewModel.setParticipants(participants)
            calendarViewModel.setExercises(exercises)
            calendarViewModel.setChallenge(challenge)
            leaderboardViewModel.setParticipants(participants)
            leaderboardViewModel.setChallenge(challenge)
            settingsViewModel.updateChallenge(challenge)
            settingsViewModel.setExercises(exercises)
            
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
        // Safety check: if challenge ended and somehow on Today tab, switch to Leaderboard
        if challenge.hasEnded && selectedTab == .today {
            selectedTab = .leaderboard
        }
        
        switch selectedTab {
        case .today:
            // Only load if challenge hasn't ended
            if !challenge.hasEnded {
                await todayViewModel.loadSubmissions()
            }
        case .review:
            await reviewViewModel.loadPendingSubmissions()
            await updatePendingReviewCount()
        case .calendar:
            await calendarViewModel.loadCompletionStatus()
        case .leaderboard:
            await leaderboardViewModel.loadLeaderboard()
        case .settings:
            // Refresh challenge and exercises when settings tab is viewed
            await refreshChallengeData()
        }
    }
    
    /// Load data for all tabs
    private func loadTabData() async {
        // Only load Today tab data if challenge hasn't ended
        if !challenge.hasEnded {
            await todayViewModel.loadSubmissions()
        }
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
    
    /// Refresh challenge data (for settings updates)
    private func refreshChallengeData() async {
        do {
            if let updatedChallenge = try await challengeService.fetchChallenge(byId: challenge.id) {
                challenge = updatedChallenge
                let updatedExercises = try await challengeService.fetchExercises(forChallengeId: challenge.id)
                exercises = updatedExercises
                
                // Update all child view models
                todayViewModel.setExercises(exercises)
                reviewViewModel.setExercises(exercises)
                calendarViewModel.setExercises(exercises)
                settingsViewModel.updateChallenge(challenge)
                settingsViewModel.setExercises(exercises)
            }
        } catch {
            // Silently fail - challenge might not have changed
        }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

