//
//  UserService.swift
//  DualFit
//
//  Handles user-related Firestore operations.
//

import Foundation
import FirebaseFirestore

/// Errors specific to user operations
enum UserServiceError: LocalizedError {
    case userNotFound
    case saveFailed(Error)
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found."
        case .saveFailed(let error):
            return "Failed to save user: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch user: \(error.localizedDescription)"
        }
    }
}

/// Service for managing app users in Firestore
class UserService {
    // MARK: - Singleton
    
    static let shared = UserService()
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let authService = AuthService.shared
    
    private var usersCollection: CollectionReference {
        db.collection(UsersCollection)
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - User CRUD
    
    /// Create a new user or update existing
    func createUser(userId: String, displayName: String, avatarEmoji: String) async throws -> AppUser {
        // Check if user already exists
        if let existingUser = try await fetchUser(byId: userId) {
            // Update existing user
            var updatedUser = existingUser
            updatedUser.displayName = displayName
            updatedUser.avatarEmoji = avatarEmoji
            return try await updateUser(updatedUser)
        }
        
        // Create new user
        let user = AppUser(
            id: userId,
            displayName: displayName,
            avatarEmoji: avatarEmoji
        )
        
        do {
            try await usersCollection.document(userId).setData(user.toFirestore())
            return user
        } catch {
            throw UserServiceError.saveFailed(error)
        }
    }
    
    /// Fetch the current logged-in user's AppUser record
    func fetchCurrentUser() async throws -> AppUser? {
        guard let userId = authService.userId else {
            return nil
        }
        return try await fetchUser(byId: userId)
    }
    
    /// Fetch a user by their ID
    func fetchUser(byId userId: String) async throws -> AppUser? {
        do {
            let document = try await usersCollection.document(userId).getDocument()
            
            guard document.exists else { return nil }
            
            return AppUser(from: document)
        } catch {
            throw UserServiceError.fetchFailed(error)
        }
    }
    
    /// Fetch multiple users by their IDs
    func fetchUsers(byIds userIds: [String]) async throws -> [AppUser] {
        guard !userIds.isEmpty else { return [] }
        
        var users: [AppUser] = []
        
        // Firestore 'in' query supports up to 10 items, so we batch
        let batches = userIds.chunked(into: 10)
        
        for batch in batches {
            do {
                let snapshot = try await usersCollection
                    .whereField(FieldPath.documentID(), in: batch)
                    .getDocuments()
                
                let batchUsers = snapshot.documents.compactMap { AppUser(from: $0) }
                users.append(contentsOf: batchUsers)
            } catch {
                throw UserServiceError.fetchFailed(error)
            }
        }
        
        return users
    }
    
    /// Update an existing user
    func updateUser(_ user: AppUser) async throws -> AppUser {
        do {
            try await usersCollection.document(user.id).setData(user.toFirestore(), merge: true)
            return user
        } catch {
            throw UserServiceError.saveFailed(error)
        }
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
