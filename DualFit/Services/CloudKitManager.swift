//
//  CloudKitManager.swift
//  DualFit
//
//  Generic CloudKit wrapper for CRUD operations.
//

import Foundation
import CloudKit

/// Errors that can occur during CloudKit operations
enum CloudKitError: LocalizedError {
    case iCloudNotAvailable
    case userNotAuthenticated
    case recordNotFound
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case invalidRecord
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        case .userNotAuthenticated:
            return "You are not signed into iCloud. Please sign in to continue."
        case .recordNotFound:
            return "The requested record was not found."
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
        case .invalidRecord:
            return "The record data is invalid."
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}

/// Manages all CloudKit operations for the app
actor CloudKitManager {
    // MARK: - Singleton
    
    static let shared = CloudKitManager()
    
    // MARK: - Properties
    
    /// The CloudKit container for the app
    private let container: CKContainer
    
    /// The public database (shared across all users)
    private var publicDatabase: CKDatabase {
        container.publicCloudDatabase
    }
    
    // MARK: - Initialization
    
    private init() {
        // Use the default container defined in entitlements
        self.container = CKContainer.default()
    }
    
    // MARK: - iCloud Status
    
    /// Check if the user is signed into iCloud
    func checkiCloudStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
    
    /// Get the current user's iCloud record ID
    func getCurrentUserRecordID() async throws -> CKRecord.ID {
        try await container.userRecordID()
    }
    
    // MARK: - Generic CRUD Operations
    
    /// Save a record to CloudKit
    func save(record: CKRecord) async throws -> CKRecord {
        do {
            return try await publicDatabase.save(record)
        } catch {
            throw CloudKitError.saveFailed(error)
        }
    }
    
    /// Save multiple records to CloudKit
    func saveMultiple(records: [CKRecord]) async throws -> [CKRecord] {
        guard !records.isEmpty else { return [] }
        
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        
        return try await withCheckedThrowingContinuation { continuation in
            var savedRecords: [CKRecord] = []
            
            operation.perRecordSaveBlock = { _, result in
                if case .success(let record) = result {
                    savedRecords.append(record)
                }
            }
            
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: savedRecords)
                case .failure(let error):
                    continuation.resume(throwing: CloudKitError.saveFailed(error))
                }
            }
            
            publicDatabase.add(operation)
        }
    }
    
    /// Fetch a single record by ID
    func fetch(recordID: CKRecord.ID) async throws -> CKRecord {
        do {
            return try await publicDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            throw CloudKitError.recordNotFound
        } catch {
            throw CloudKitError.fetchFailed(error)
        }
    }
    
    /// Fetch records matching a query
    func fetch(query: CKQuery, resultsLimit: Int = 100) async throws -> [CKRecord] {
        do {
            let (matchResults, _) = try await publicDatabase.records(matching: query, resultsLimit: resultsLimit)
            
            var records: [CKRecord] = []
            for (_, result) in matchResults {
                if case .success(let record) = result {
                    records.append(record)
                }
            }
            return records
        } catch {
            throw CloudKitError.fetchFailed(error)
        }
    }
    
    /// Fetch records with a predicate
    func fetch(
        recordType: String,
        predicate: NSPredicate = NSPredicate(value: true),
        sortDescriptors: [NSSortDescriptor]? = nil,
        resultsLimit: Int = 100
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        return try await fetch(query: query, resultsLimit: resultsLimit)
    }
    
    /// Delete a record by ID
    func delete(recordID: CKRecord.ID) async throws {
        do {
            try await publicDatabase.deleteRecord(withID: recordID)
        } catch {
            throw CloudKitError.deleteFailed(error)
        }
    }
    
    /// Delete multiple records
    func deleteMultiple(recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }
        
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: CloudKitError.deleteFailed(error))
                }
            }
            
            publicDatabase.add(operation)
        }
    }
    
    // MARK: - Asset Operations
    
    /// Update a record to remove its video asset (after review)
    func deleteVideoAsset(recordID: CKRecord.ID, assetKey: String) async throws -> CKRecord {
        // Fetch the current record
        let record = try await fetch(recordID: recordID)
        
        // Remove the asset
        record[assetKey] = nil
        
        // Save the updated record
        return try await save(record: record)
    }
    
    // MARK: - Helpers
    
    /// Create a record ID from a string
    func recordID(from string: String) -> CKRecord.ID {
        CKRecord.ID(recordName: string)
    }
    
    /// Create a reference to a record
    func reference(to recordID: CKRecord.ID, action: CKRecord.ReferenceAction = .none) -> CKRecord.Reference {
        CKRecord.Reference(recordID: recordID, action: action)
    }
}

