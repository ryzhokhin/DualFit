//
//  JoinChallengeViewModel.swift
//  DualFit
//
//  View model for joining an existing challenge.
//

import Foundation
import SwiftUI

/// View model for the join challenge screen
@MainActor
class JoinChallengeViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var joinCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var foundChallenge: Challenge?
    @Published var joinedSuccessfully: Bool = false
    
    // MARK: - Computed Properties
    
    var isValidCode: Bool {
        joinCode.trimmingCharacters(in: .whitespaces).count >= 6
    }
    
    // MARK: - Properties
    
    private let challengeService = ChallengeService.shared
    
    // MARK: - Public Methods
    
    /// Search for a challenge by join code
    func searchChallenge() async {
        guard isValidCode else {
            errorMessage = "Please enter a valid join code (at least 6 characters)."
            return
        }
        
        isLoading = true
        errorMessage = nil
        foundChallenge = nil
        
        do {
            let code = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
            
            if let challenge = try await challengeService.fetchChallenge(byJoinCode: code) {
                foundChallenge = challenge
            } else {
                errorMessage = "No challenge found with that code. Please check and try again."
            }
        } catch let error as ChallengeError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Join the found challenge
    func joinChallenge(userId: String) async {
        guard let challenge = foundChallenge else {
            errorMessage = "No challenge selected."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await challengeService.joinChallenge(
                challengeId: challenge.id,
                userId: userId
            )
            
            joinedSuccessfully = true
        } catch let error as ChallengeError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Reset the form
    func reset() {
        joinCode = ""
        foundChallenge = nil
        joinedSuccessfully = false
        errorMessage = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
