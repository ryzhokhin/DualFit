//
//  SettingsViewModel.swift
//  DualFit
//
//  View model for challenge settings screen.
//

import Foundation
import UIKit

/// Represents an editable exercise in settings
struct EditableExercise: Identifiable, Equatable {
    let id: String
    var name: String
    var dailyRequiredReps: Int
    var order: Int
    
    init(id: String, name: String, dailyRequiredReps: Int, order: Int) {
        self.id = id
        self.name = name
        self.dailyRequiredReps = dailyRequiredReps
        self.order = order
    }
    
    init(from exercise: ChallengeExercise) {
        self.id = exercise.id
        self.name = exercise.name
        self.dailyRequiredReps = exercise.dailyRequiredReps
        self.order = exercise.order
    }
    
    func toChallengeExercise(challengeId: String) -> ChallengeExercise {
        ChallengeExercise(
            id: id,
            challengeId: challengeId,
            name: name,
            dailyRequiredReps: dailyRequiredReps,
            order: order
        )
    }
}

/// View model for the settings tab
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var challenge: Challenge
    @Published var copiedToClipboard: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var saveSuccess: Bool = false
    
    // Editable properties
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var exercises: [EditableExercise] = []
    
    // MARK: - Properties
    
    private let challengeService = ChallengeService.shared
    
    // MARK: - Computed Properties
    
    /// The join code for this challenge
    var joinCode: String {
        challenge.joinCode
    }
    
    /// Whether there are unsaved changes
    var hasChanges: Bool {
        startDate != challenge.startDate.startOfDay ||
        endDate != challenge.endDate.startOfDay ||
        exercisesChanged
    }
    
    /// Whether exercises have changed
    private var exercisesChanged: Bool {
        // This will be checked when saving
        true // Simplified - could compare with original
    }
    
    // MARK: - Initialization
    
    init(challenge: Challenge) {
        self.challenge = challenge
        self.startDate = challenge.startDate.startOfDay
        self.endDate = challenge.endDate.startOfDay
        self.exercises = []
    }
    
    // MARK: - Public Methods
    
    /// Update the challenge (when it's refreshed)
    func updateChallenge(_ challenge: Challenge) {
        self.challenge = challenge
        self.startDate = challenge.startDate.startOfDay
        self.endDate = challenge.endDate.startOfDay
    }
    
    /// Set exercises (called from parent)
    func setExercises(_ exercises: [ChallengeExercise]) {
        self.exercises = exercises
            .sorted { $0.order < $1.order }
            .map { EditableExercise(from: $0) }
    }
    
    /// Copy join code to clipboard
    func copyJoinCode() {
        UIPasteboard.general.string = joinCode
        copiedToClipboard = true
        
        // Reset the copied state after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copiedToClipboard = false
        }
    }
    
    // MARK: - Exercise Management
    
    /// Add a new exercise
    func addExercise() {
        guard exercises.count < 10 else { return }
        let newOrder = exercises.count
        let newExercise = EditableExercise(
            id: UUID().uuidString,
            name: "",
            dailyRequiredReps: 10,
            order: newOrder
        )
        exercises.append(newExercise)
    }
    
    /// Remove an exercise
    func removeExercise(at index: Int) {
        guard exercises.count > 1 else {
            errorMessage = "Challenge must have at least one exercise."
            return
        }
        exercises.remove(at: index)
        // Reorder remaining exercises
        for i in 0..<exercises.count {
            exercises[i].order = i
        }
    }
    
    /// Move exercise
    func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
        // Reorder
        for i in 0..<exercises.count {
            exercises[i].order = i
        }
    }
    
    // MARK: - Save Operations
    
    /// Save all changes
    func saveChanges() async {
        guard hasChanges else { return }
        
        isLoading = true
        errorMessage = nil
        saveSuccess = false
        
        do {
            // Validate dates
            guard endDate > startDate else {
                throw ChallengeError.saveFailed(NSError(domain: "Settings", code: 1, userInfo: [NSLocalizedDescriptionKey: "End date must be after start date."]))
            }
            
            // Validate exercises
            let invalidExercises = exercises.filter { $0.name.trimmingCharacters(in: .whitespaces).isEmpty || $0.dailyRequiredReps <= 0 }
            guard invalidExercises.isEmpty else {
                throw ChallengeError.saveFailed(NSError(domain: "Settings", code: 2, userInfo: [NSLocalizedDescriptionKey: "All exercises must have a name and at least 1 rep."]))
            }
            
            // Update dates if changed
            if startDate != challenge.startDate.startOfDay || endDate != challenge.endDate.startOfDay {
                try await challengeService.updateChallengeDates(
                    challengeId: challenge.id,
                    startDate: startDate,
                    endDate: endDate
                )
            }
            
            // Update exercises
            let challengeExercises = exercises.map { $0.toChallengeExercise(challengeId: challenge.id) }
            try await challengeService.updateExercises(challengeExercises)
            
            // Update local challenge
            var updatedChallenge = challenge
            updatedChallenge.startDate = startDate
            updatedChallenge.endDate = endDate
            challenge = updatedChallenge
            
            saveSuccess = true
            
            // Reset success message after 2 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                saveSuccess = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

