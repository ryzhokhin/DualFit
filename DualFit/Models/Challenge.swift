//
//  Challenge.swift
//  DualFit
//
//  Represents a fitness challenge that users can participate in.
//

import Foundation
import FirebaseFirestore

/// Firestore collection name for challenges
let ChallengesCollection = "challenges"

/// Represents a fitness challenge
struct Challenge: Identifiable, Equatable, Hashable, Codable {
    let id: String                    // Firestore document ID
    var name: String
    var description: String
    let createdByUserId: String       // User ID who created this
    var startDate: Date
    var endDate: Date
    var maxParticipants: Int
    let createdAt: Date
    
    // MARK: - Computed Properties
    
    /// The join code for this challenge (uses first 8 chars of ID)
    var joinCode: String {
        String(id.prefix(8)).uppercased()
    }
    
    /// Whether the challenge is currently active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    /// Whether the challenge has ended
    var hasEnded: Bool {
        Date() > endDate
    }
    
    /// Total number of days in the challenge
    var totalDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
    
    /// Days elapsed since start (capped at total days)
    var daysElapsed: Int {
        let calendar = Calendar.current
        let now = Date()
        let effectiveDate = min(now, endDate)
        let components = calendar.dateComponents([.day], from: startDate, to: effectiveDate)
        return max(0, min((components.day ?? 0) + 1, totalDays))
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdByUserId
        case startDate
        case endDate
        case maxParticipants
        case createdAt
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        createdByUserId: String,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
        maxParticipants: Int = 10,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdByUserId = createdByUserId
        self.startDate = startDate
        self.endDate = endDate
        self.maxParticipants = min(maxParticipants, 10) // Enforce max 10
        self.createdAt = createdAt
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert to Firestore data dictionary
    func toFirestore() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "description": description,
            "createdByUserId": createdByUserId,
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),
            "maxParticipants": maxParticipants,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    /// Initialize from Firestore document
    init?(from document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.name = data["name"] as? String ?? "Unnamed Challenge"
        self.description = data["description"] as? String ?? ""
        self.createdByUserId = data["createdByUserId"] as? String ?? ""
        
        if let timestamp = data["startDate"] as? Timestamp {
            self.startDate = timestamp.dateValue()
        } else {
            self.startDate = Date()
        }
        
        if let timestamp = data["endDate"] as? Timestamp {
            self.endDate = timestamp.dateValue()
        } else {
            self.endDate = Date()
        }
        
        self.maxParticipants = data["maxParticipants"] as? Int ?? 10
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}

// MARK: - Sample Data

extension Challenge {
    static let sample = Challenge(
        name: "November Pushup Duel",
        description: "30 days of push-ups with friends!",
        createdByUserId: AppUser.sample.id,
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    )
}
