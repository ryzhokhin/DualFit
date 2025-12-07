//
//  CreateChallengeViewModel.swift
//  DualFit
//
//  View model for creating a new challenge.
//

import Foundation
import SwiftUI

/// Represents an exercise being added to a new challenge
struct ExerciseInput: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var reps: Int
}

/// View model for the create challenge screen
@MainActor
class CreateChallengeViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @Published var exercises: [ExerciseInput] = [
        ExerciseInput(name: "", reps: 10)
    ]
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var createdChallenge: Challenge?
    @Published var joinCode: String?
    
    // MARK: - Computed Properties
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        endDate > startDate &&
        !exercises.isEmpty &&
        exercises.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && $0.reps > 0 }
    }
    
    var durationDays: Int {
        let components = Calendar.current.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
    
    // MARK: - Properties
    
    private let challengeService = ChallengeService.shared
    
    // MARK: - Public Methods
    
    /// Add a new exercise input
    func addExercise() {
        guard exercises.count < 10 else { return } // Max 10 exercises
        exercises.append(ExerciseInput(name: "", reps: 10))
    }
    
    /// Remove an exercise at index
    func removeExercise(at index: Int) {
        guard exercises.count > 1 else { return } // Keep at least one
        exercises.remove(at: index)
    }
    
    /// Move exercise
    func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
    }
    
    /// Create the challenge
    func createChallenge(creatorUserId: String) async {
        guard isValid else {
            errorMessage = "Please fill in all required fields."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let exerciseData = exercises.map { (name: $0.name.trimmingCharacters(in: .whitespaces), reps: $0.reps) }
            
            let (challenge, _) = try await challengeService.createChallenge(
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                startDate: startDate.startOfDay,
                endDate: endDate.startOfDay,
                exercises: exerciseData,
                creatorUserId: creatorUserId
            )
            
            createdChallenge = challenge
            joinCode = challenge.joinCode
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Reset the form
    func reset() {
        name = ""
        description = ""
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        exercises = [ExerciseInput(name: "", reps: 10)]
        createdChallenge = nil
        joinCode = nil
        errorMessage = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
