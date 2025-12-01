//
//  AppViewModel.swift
//  DualFit
//
//  Global app state and current user management with Firebase Auth.
//

import Foundation
import SwiftUI

/// The current state of the app
enum AppState: Equatable {
    case loading
    case needsOnboarding
    case ready
    case error(String)
}

/// Global app view model managing authentication and user state
@MainActor
class AppViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var appState: AppState = .loading
    @Published var currentUser: AppUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Services
    
    private let authService = AuthService.shared
    private let userService = UserService.shared
    
    // MARK: - Initialization
    
    init() {
        // Check status on init
        Task {
            await checkInitialState()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check Firebase Auth and load user
    func checkInitialState() async {
        appState = .loading
        
        do {
            // Sign in anonymously if not already signed in
            let userId = try await authService.ensureSignedIn()
            
            // Try to load existing user profile
            if let user = try await userService.fetchUser(byId: userId) {
                currentUser = user
                appState = .ready
            } else {
                // User needs to complete onboarding (set display name)
                appState = .needsOnboarding
            }
        } catch {
            appState = .error(error.localizedDescription)
        }
    }
    
    /// Complete onboarding by creating user profile
    func completeOnboarding(displayName: String, avatarEmoji: String) async {
        guard let userId = authService.userId else {
            errorMessage = "Not signed in. Please restart the app."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await userService.createUser(
                userId: userId,
                displayName: displayName,
                avatarEmoji: avatarEmoji
            )
            
            currentUser = user
            appState = .ready
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Update user profile
    func updateProfile(displayName: String, avatarEmoji: String) async {
        guard var user = currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        
        user.displayName = displayName
        user.avatarEmoji = avatarEmoji
        
        do {
            let updatedUser = try await userService.updateUser(user)
            currentUser = updatedUser
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Refresh user data
    func refreshUser() async {
        guard let userId = authService.userId else { return }
        
        do {
            if let user = try await userService.fetchUser(byId: userId) {
                currentUser = user
            }
        } catch {
            print("Failed to refresh user: \(error)")
        }
    }
    
    /// Clear any displayed error
    func clearError() {
        errorMessage = nil
    }
    
    /// Retry after an error
    func retry() async {
        await checkInitialState()
    }
}
