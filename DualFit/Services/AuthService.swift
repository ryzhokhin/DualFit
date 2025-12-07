//
//  AuthService.swift
//  DualFit
//
//  Handles Firebase Authentication (anonymous sign-in).
//

import Foundation
import FirebaseAuth

/// Errors that can occur during authentication
enum AuthError: LocalizedError {
    case notSignedIn
    case signInFailed(Error)
    case signOutFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You are not signed in. Please restart the app."
        case .signInFailed(let error):
            return "Sign in failed: \(error.localizedDescription)"
        case .signOutFailed(let error):
            return "Sign out failed: \(error.localizedDescription)"
        }
    }
}

/// Service for managing Firebase Authentication
class AuthService: ObservableObject {
    // MARK: - Singleton
    
    static let shared = AuthService()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentUserId: String?
    @Published private(set) var isSignedIn: Bool = false
    
    // MARK: - Properties
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Initialization
    
    private init() {
        // Listen for auth state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUserId = user?.uid
                self?.isSignedIn = user != nil
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the current user's ID (synchronous)
    var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    /// Check if user is currently signed in
    var hasCurrentUser: Bool {
        Auth.auth().currentUser != nil
    }
    
    /// Sign in anonymously
    func signInAnonymously() async throws -> String {
        do {
            let result = try await Auth.auth().signInAnonymously()
            let uid = result.user.uid
            
            await MainActor.run {
                self.currentUserId = uid
                self.isSignedIn = true
            }
            
            return uid
        } catch {
            throw AuthError.signInFailed(error)
        }
    }
    
    /// Sign out
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            
            DispatchQueue.main.async {
                self.currentUserId = nil
                self.isSignedIn = false
            }
        } catch {
            throw AuthError.signOutFailed(error)
        }
    }
    
    /// Ensure user is signed in, sign in anonymously if not
    func ensureSignedIn() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }
        
        return try await signInAnonymously()
    }
}

