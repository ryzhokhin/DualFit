//
//  UserService.swift
//  DualFit
//
//  Handles user-related operations.
//

import Foundation
import CloudKit

/// Service for managing app users
actor UserService {
    // MARK: - Singleton
    
    static let shared = UserService()
    
    // MARK: - Properties
    
    private let cloudKit = CloudKitManager.shared
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - iCloud Account
    
    /// Check if the user is signed into iCloud
    func checkiCloudAvailability() async throws -> Bool {
        let status = try await cloudKit.checkiCloudStatus()
        
        switch status {
        case .available:
            return true
        case .noAccount:
            throw CloudKitError.userNotAuthenticated
        case .restricted, .couldNotDetermine, .temporarilyUnavailable:
            throw CloudKitError.iCloudNotAvailable
        @unknown default:
            throw CloudKitError.iCloudNotAvailable
        }
    }
    
    /// Get the current user's iCloud identity string
    func getCurrentiCloudUserID() async throws -> String {
        let recordID = try await cloudKit.getCurrentUserRecordID()
        return recordID.recordName
    }
    
    // MARK: - User CRUD
    
    /// Create a new AppUser record
    func createUser(displayName: String, avatarEmoji: String) async throws -> AppUser {
        let icloudUserID = try await getCurrentiCloudUserID()
        
        // Check if user already exists
        if let existingUser = try await fetchUserByiCloudID(icloudUserID) {
            // Update existing user instead
            var updatedUser = existingUser
            updatedUser.displayName = displayName
            updatedUser.avatarEmoji = avatarEmoji
            return try await updateUser(updatedUser)
        }
        
        // Create new user
        let user = AppUser(
            icloudUserRecordID: icloudUserID,
            displayName: displayName,
            avatarEmoji: avatarEmoji
        )
        
        let record = user.toRecord()
        _ = try await cloudKit.save(record: record)
        
        return user
    }
    
    /// Fetch the current logged-in user's AppUser record
    func fetchCurrentUser() async throws -> AppUser? {
        let icloudUserID = try await getCurrentiCloudUserID()
        return try await fetchUserByiCloudID(icloudUserID)
    }
    
    /// Fetch a user by their iCloud record ID
    func fetchUserByiCloudID(_ icloudUserID: String) async throws -> AppUser? {
        let predicate = NSPredicate(
            format: "%K == %@",
            AppUser.FieldKey.icloudUserRecordID.rawValue,
            icloudUserID
        )
        
        let records = try await cloudKit.fetch(
            recordType: AppUserRecordType,
            predicate: predicate,
            resultsLimit: 1
        )
        
        guard let record = records.first else { return nil }
        return AppUser(from: record)
    }
    
    /// Fetch a user by their AppUser record ID
    func fetchUser(byID userID: String) async throws -> AppUser? {
        let recordID = CKRecord.ID(recordName: userID)
        
        do {
            let record = try await cloudKit.fetch(recordID: recordID)
            return AppUser(from: record)
        } catch CloudKitError.recordNotFound {
            return nil
        }
    }
    
    /// Fetch multiple users by their IDs
    func fetchUsers(byIDs userIDs: [String]) async throws -> [AppUser] {
        guard !userIDs.isEmpty else { return [] }
        
        var users: [AppUser] = []
        
        // Fetch users in parallel
        await withTaskGroup(of: AppUser?.self) { group in
            for userID in userIDs {
                group.addTask {
                    try? await self.fetchUser(byID: userID)
                }
            }
            
            for await user in group {
                if let user = user {
                    users.append(user)
                }
            }
        }
        
        return users
    }
    
    /// Update an existing user
    func updateUser(_ user: AppUser) async throws -> AppUser {
        let recordID = CKRecord.ID(recordName: user.id)
        let existingRecord = try await cloudKit.fetch(recordID: recordID)
        let updatedRecord = user.updateRecord(existingRecord)
        _ = try await cloudKit.save(record: updatedRecord)
        return user
    }
}

