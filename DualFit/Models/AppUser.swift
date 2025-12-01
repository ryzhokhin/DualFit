//
//  AppUser.swift
//  DualFit
//
//  Represents a user of the app, linked to their Firebase Auth identity.
//

import Foundation
import FirebaseFirestore

/// Firestore collection name for users
let UsersCollection = "users"

/// Represents a user in the DualFit app
struct AppUser: Identifiable, Equatable, Hashable, Codable {
    let id: String                    // Firebase Auth UID
    var displayName: String
    var avatarEmoji: String
    let createdAt: Date
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case avatarEmoji
        case createdAt
    }
    
    // MARK: - Initialization
    
    init(
        id: String,
        displayName: String,
        avatarEmoji: String = "💪",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.createdAt = createdAt
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert to Firestore data dictionary
    func toFirestore() -> [String: Any] {
        return [
            "id": id,
            "displayName": displayName,
            "avatarEmoji": avatarEmoji,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    /// Initialize from Firestore document
    init?(from document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.displayName = data["displayName"] as? String ?? "Unknown"
        self.avatarEmoji = data["avatarEmoji"] as? String ?? "💪"
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}

// MARK: - Sample Data

extension AppUser {
    static let sample = AppUser(
        id: "sample-user-id",
        displayName: "Andrii",
        avatarEmoji: "🏋️"
    )
}
