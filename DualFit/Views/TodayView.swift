//
//  TodayView.swift
//  DualFit
//
//  View showing today's exercises and submission status.
//

import SwiftUI
import PhotosUI

/// View for today's exercises
struct TodayView: View {
    @ObservedObject var viewModel: TodayViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date header
                dateHeader
                
                // Progress summary
                progressSummary
                
                // Exercises list
                exercisesList
            }
            .padding()
        }
        .overlay {
            if viewModel.isUploading {
                uploadingOverlay
            }
        }
        .onChange(of: viewModel.selectedVideoItem) { _, _ in
            Task {
                await viewModel.handleVideoSelection()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Date Header
    
    private var dateHeader: some View {
        HStack {
            Button {
                Task {
                    await viewModel.previousDay()
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color("AccentColor"))
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(viewModel.selectedDate.isToday ? "Today" : viewModel.selectedDate.relativeDateString)
                    .font(.custom("Avenir-Heavy", size: 20))
                    .foregroundColor(.primary)
                
                Text(viewModel.selectedDate.fullDateString)
                    .font(.custom("Avenir-Medium", size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                Task {
                    await viewModel.nextDay()
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color("AccentColor"))
            }
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    // MARK: - Progress Summary
    
    private var progressSummary: some View {
        HStack(spacing: 16) {
            progressItem(
                icon: "checkmark.circle.fill",
                count: viewModel.completedCount,
                label: "Approved",
                color: .green
            )
            
            progressItem(
                icon: "clock.fill",
                count: viewModel.pendingCount,
                label: "Pending",
                color: .orange
            )
            
            progressItem(
                icon: "figure.run",
                count: viewModel.totalCount - viewModel.completedCount - viewModel.pendingCount,
                label: "Remaining",
                color: .secondary
            )
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    private func progressItem(icon: String, count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.custom("Avenir-Heavy", size: 20))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.custom("Avenir-Medium", size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Exercises List
    
    private var exercisesList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.custom("Avenir-Heavy", size: 18))
                .foregroundColor(.primary)
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if viewModel.exerciseItems.isEmpty {
                emptyExercisesView
            } else {
                ForEach(viewModel.exerciseItems) { item in
                    ExerciseRow(item: item, viewModel: viewModel)
                }
            }
        }
    }
    
    private var emptyExercisesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No exercises found")
                .font(.custom("Avenir-Medium", size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    // MARK: - Uploading Overlay
    
    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(viewModel.uploadProgress ?? "Uploading...")
                    .font(.custom("Avenir-Medium", size: 16))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color("CardBackground"))
            .cornerRadius(16)
        }
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let item: TodayExerciseItem
    @ObservedObject var viewModel: TodayViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            statusIcon
            
            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.exercise.name)
                    .font(.custom("Avenir-Heavy", size: 16))
                    .foregroundColor(.primary)
                
                Text("\(item.exercise.dailyRequiredReps) reps")
                    .font(.custom("Avenir-Medium", size: 13))
                    .foregroundColor(.secondary)
                
                // Status text
                statusText
            }
            
            Spacer()
            
            // Action button
            if item.canSubmit {
                PhotosPicker(
                    selection: $viewModel.selectedVideoItem,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                        Text("Upload")
                    }
                    .font(.custom("Avenir-Heavy", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color("AccentColor"))
                    .cornerRadius(10)
                }
                .onChange(of: viewModel.selectedVideoItem) { _, newValue in
                    if newValue != nil {
                        viewModel.prepareUpload(for: item.exercise)
                    }
                }
            }
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    private var statusIcon: some View {
        Group {
            switch item.status {
            case .approved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            case .pending:
                Image(systemName: "clock.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            case .rejected:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
            case .none:
                Image(systemName: "circle")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
    }
    
    private var statusText: some View {
        Group {
            switch item.status {
            case .approved:
                Text("Approved ✅")
                    .font(.custom("Avenir-Heavy", size: 12))
                    .foregroundColor(.green)
            case .pending:
                Text("Pending review...")
                    .font(.custom("Avenir-Medium", size: 12))
                    .foregroundColor(.orange)
            case .rejected:
                Text("Rejected - Please resubmit")
                    .font(.custom("Avenir-Medium", size: 12))
                    .foregroundColor(.red)
            case .none:
                Text("Not submitted yet")
                    .font(.custom("Avenir-Medium", size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TodayView(viewModel: TodayViewModel(challengeId: "test", currentUserId: "user"))
}

