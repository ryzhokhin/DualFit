//
//  ReviewViewModel.swift
//  DualFit
//
//  View model for reviewing other participants' submissions.
//

import Foundation
import SwiftUI

/// A pending submission to review with user and exercise details
struct PendingReviewItem: Identifiable, Equatable {
    let id: String
    let submission: ExerciseSubmission
    var user: AppUser?
    var exercise: ChallengeExercise?
    
    var userName: String {
        user?.displayName ?? "Unknown"
    }
    
    var userEmoji: String {
        user?.avatarEmoji ?? "👤"
    }
    
    var exerciseName: String {
        exercise?.name ?? "Unknown Exercise"
    }
    
    var exerciseReps: Int {
        exercise?.dailyRequiredReps ?? 0
    }
}

/// View model for the review tab
@MainActor
class ReviewViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var pendingItems: [PendingReviewItem] = []
    @Published var isLoading: Bool = false
    @Published var isReviewing: Bool = false
    @Published var errorMessage: String?
    @Published var selectedItem: PendingReviewItem?
    @Published var showVideoPlayer: Bool = false
    
    // MARK: - Properties
    
    private let challengeID: String
    private let currentUserID: String
    private var exercises: [ChallengeExercise] = []
    private var participants: [AppUser] = []
    
    private let submissionService = SubmissionService.shared
    
    // MARK: - Computed Properties
    
    var pendingCount: Int {
        pendingItems.count
    }
    
    var isEmpty: Bool {
        pendingItems.isEmpty && !isLoading
    }
    
    // MARK: - Initialization
    
    init(challengeID: String, currentUserID: String) {
        self.challengeID = challengeID
        self.currentUserID = currentUserID
    }
    
    // MARK: - Public Methods
    
    /// Set exercises (called from parent view model)
    func setExercises(_ exercises: [ChallengeExercise]) {
        self.exercises = exercises
    }
    
    /// Set participants (called from parent view model)
    func setParticipants(_ participants: [AppUser]) {
        self.participants = participants
    }
    
    /// Load pending submissions to review
    func loadPendingSubmissions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let submissions = try await submissionService.fetchPendingSubmissionsToReview(
                challengeID: challengeID,
                currentUserID: currentUserID
            )
            
            // Map to review items with user and exercise details
            pendingItems = submissions.map { submission in
                let user = participants.first { $0.id == submission.userRef }
                let exercise = exercises.first { $0.id == submission.exerciseRef }
                
                return PendingReviewItem(
                    id: submission.id,
                    submission: submission,
                    user: user,
                    exercise: exercise
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Select an item to review
    func selectItem(_ item: PendingReviewItem) {
        selectedItem = item
        showVideoPlayer = true
    }
    
    /// Approve the selected submission
    func approveSelected() async {
        guard let item = selectedItem else { return }
        await approve(item)
    }
    
    /// Reject the selected submission
    func rejectSelected() async {
        guard let item = selectedItem else { return }
        await reject(item)
    }
    
    /// Approve a submission
    func approve(_ item: PendingReviewItem) async {
        isReviewing = true
        errorMessage = nil
        
        do {
            _ = try await submissionService.approveSubmission(
                submissionID: item.submission.id,
                reviewerID: currentUserID
            )
            
            // Remove from pending list
            pendingItems.removeAll { $0.id == item.id }
            
            // Clear selection if this was the selected item
            if selectedItem?.id == item.id {
                selectedItem = nil
                showVideoPlayer = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isReviewing = false
    }
    
    /// Reject a submission
    func reject(_ item: PendingReviewItem) async {
        isReviewing = true
        errorMessage = nil
        
        do {
            _ = try await submissionService.rejectSubmission(
                submissionID: item.submission.id,
                reviewerID: currentUserID
            )
            
            // Remove from pending list
            pendingItems.removeAll { $0.id == item.id }
            
            // Clear selection if this was the selected item
            if selectedItem?.id == item.id {
                selectedItem = nil
                showVideoPlayer = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isReviewing = false
    }
    
    /// Close video player
    func closeVideoPlayer() {
        showVideoPlayer = false
        selectedItem = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

