//
//  TodayViewModel.swift
//  DualFit
//
//  View model for the "Today" tab showing daily exercises.
//

import Foundation
import SwiftUI
import PhotosUI

/// Represents an exercise and its submission status for today
struct TodayExerciseItem: Identifiable, Equatable {
    let id: String
    let exercise: ChallengeExercise
    var submission: ExerciseSubmission?
    
    var status: SubmissionStatus? {
        submission?.status
    }
    
    var hasSubmission: Bool {
        submission != nil
    }
    
    var canSubmit: Bool {
        submission == nil || submission?.status == .rejected
    }
}

/// View model for the today tab
@MainActor
class TodayViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var exerciseItems: [TodayExerciseItem] = []
    @Published var selectedDate: Date = Date().startOfDay
    @Published var isLoading: Bool = false
    @Published var isUploading: Bool = false
    @Published var errorMessage: String?
    @Published var uploadProgress: String?
    
    // For video picker
    @Published var selectedVideoItem: PhotosPickerItem?
    @Published var currentExerciseForUpload: ChallengeExercise?
    
    // MARK: - Properties
    
    private let challengeId: String
    private let currentUserId: String
    private var exercises: [ChallengeExercise] = []
    
    private let submissionService = SubmissionService.shared
    
    // MARK: - Computed Properties
    
    var dateString: String {
        if selectedDate.isToday {
            return "Today: \(selectedDate.fullDateString)"
        } else {
            return selectedDate.fullDateString
        }
    }
    
    var completedCount: Int {
        exerciseItems.filter { $0.submission?.status == .approved }.count
    }
    
    var pendingCount: Int {
        exerciseItems.filter { $0.submission?.status == .pending }.count
    }
    
    var totalCount: Int {
        exerciseItems.count
    }
    
    // MARK: - Initialization
    
    init(challengeId: String, currentUserId: String) {
        self.challengeId = challengeId
        self.currentUserId = currentUserId
    }
    
    // MARK: - Public Methods
    
    /// Set exercises (called from parent view model)
    func setExercises(_ exercises: [ChallengeExercise]) {
        self.exercises = exercises
    }
    
    /// Load submissions for the selected date
    func loadSubmissions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let submissions = try await submissionService.fetchSubmissions(
                challengeId: challengeId,
                userId: currentUserId,
                date: selectedDate
            )
            
            // Map exercises to items with submissions
            exerciseItems = exercises.map { exercise in
                let submission = submissions.first { $0.exerciseId == exercise.id }
                return TodayExerciseItem(
                    id: exercise.id,
                    exercise: exercise,
                    submission: submission
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Handle video selection from picker
    func handleVideoSelection() async {
        guard let item = selectedVideoItem,
              let exercise = currentExerciseForUpload else {
            return
        }
        
        isUploading = true
        uploadProgress = "Loading video..."
        errorMessage = nil
        
        do {
            // Load video data
            guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
                throw SubmissionError.invalidVideoFile
            }
            
            uploadProgress = "Compressing video..."
            
            // Validate and compress
            try await VideoCompressor.validate(videoAt: movie.url)
            let compressedURL = try await VideoCompressor.compress(videoAt: movie.url)
            
            uploadProgress = "Uploading..."
            
            // Create submission
            let submission = try await submissionService.createSubmission(
                challengeId: challengeId,
                exerciseId: exercise.id,
                userId: currentUserId,
                date: selectedDate,
                videoFileURL: compressedURL
            )
            
            // Update local state
            if let index = exerciseItems.firstIndex(where: { $0.exercise.id == exercise.id }) {
                exerciseItems[index].submission = submission
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: compressedURL)
            
            uploadProgress = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isUploading = false
        selectedVideoItem = nil
        currentExerciseForUpload = nil
    }
    
    /// Prepare to upload video for an exercise
    func prepareUpload(for exercise: ChallengeExercise) {
        currentExerciseForUpload = exercise
    }
    
    /// Change the selected date
    func selectDate(_ date: Date) async {
        selectedDate = date.startOfDay
        await loadSubmissions()
    }
    
    /// Go to previous day
    func previousDay() async {
        if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            await selectDate(newDate)
        }
    }
    
    /// Go to next day
    func nextDay() async {
        if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            await selectDate(newDate)
        }
    }
    
    /// Go to today
    func goToToday() async {
        await selectDate(Date())
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Video Transferable

/// Wrapper for transferring video files from PhotosPicker
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copy to temp location
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}
