//
//  AppViewModel.swift
//  DualFit
//
//  Global app state and current user management.
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
    
    private let userService = UserService.shared
    
    // MARK: - Initialization
    
    init() {
        // Check status on init
        Task {
            await checkInitialState()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check iCloud availability and load user
    func checkInitialState() async {
        appState = .loading
        
        do {
            // Check iCloud availability
            let isAvailable = try await userService.checkiCloudAvailability()
            
            guard isAvailable else {
                appState = .error("iCloud is not available. Please sign in to iCloud in Settings.")
                return
            }
            
            // Try to load existing user
            if let user = try await userService.fetchCurrentUser() {
                currentUser = user
                appState = .ready
            } else {
                // User needs to complete onboarding
                appState = .needsOnboarding
            }
        } catch let error as CloudKitError {
            appState = .error(error.localizedDescription)
        } catch {
            appState = .error(error.localizedDescription)
        }
    }
    
    /// Complete onboarding by creating user profile
    func completeOnboarding(displayName: String, avatarEmoji: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await userService.createUser(
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
        do {
            if let user = try await userService.fetchCurrentUser() {
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

