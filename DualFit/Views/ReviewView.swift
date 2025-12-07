//
//  ReviewView.swift
//  DualFit
//
//  View for reviewing other participants' submissions.
//

import SwiftUI
import AVKit

/// View for reviewing submissions
struct ReviewView: View {
    @ObservedObject var viewModel: ReviewViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                reviewHeader
                
                // Pending list
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.isEmpty {
                    emptyView
                } else {
                    pendingList
                }
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showVideoPlayer) {
            if let item = viewModel.selectedItem {
                VideoReviewSheet(item: item, viewModel: viewModel)
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
    
    // MARK: - Header
    
    private var reviewHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pending Reviews")
                    .font(.custom("Avenir-Heavy", size: 20))
                    .foregroundColor(.primary)
                
                Text("\(viewModel.pendingCount) submissions waiting")
                    .font(.custom("Avenir-Medium", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Refresh button
            Button {
                Task {
                    await viewModel.loadPendingSubmissions()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18))
                    .foregroundColor(Color("AccentColor"))
            }
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.green.opacity(0.5))
            
            Text("All caught up!")
                .font(.custom("Avenir-Heavy", size: 20))
                .foregroundColor(.primary)
            
            Text("No pending submissions to review.\nCheck back later!")
                .font(.custom("Avenir-Medium", size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    // MARK: - Pending List
    
    private var pendingList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.pendingItems) { item in
                PendingSubmissionRow(item: item) {
                    viewModel.selectItem(item)
                }
            }
        }
    }
}

// MARK: - Pending Submission Row

struct PendingSubmissionRow: View {
    let item: PendingReviewItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // User avatar
                Text(item.userEmoji)
                    .font(.system(size: 32))
                    .frame(width: 50, height: 50)
                    .background(Color("AccentColor").opacity(0.2))
                    .cornerRadius(14)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.userName)
                        .font(.custom("Avenir-Heavy", size: 16))
                        .foregroundColor(.primary)
                    
                    Text(item.exerciseName)
                        .font(.custom("Avenir-Medium", size: 14))
                        .foregroundColor(Color("AccentColor"))
                    
                    Text(item.submission.date.relativeDateString)
                        .font(.custom("Avenir-Medium", size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Play icon
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color("AccentColor"))
            }
            .padding()
            .background(Color("CardBackground"))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Video Review Sheet

struct VideoReviewSheet: View {
    let item: PendingReviewItem
    @ObservedObject var viewModel: ReviewViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Video player
                    if let videoURL = item.submission.videoURL {
                        VideoPlayer(player: AVPlayer(url: videoURL))
                            .aspectRatio(9/16, contentMode: .fit)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            
                            Text("Video not available")
                                .font(.custom("Avenir-Medium", size: 16))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Info and actions
                    VStack(spacing: 16) {
                        // Submission info
                        HStack {
                            Text(item.userEmoji)
                                .font(.system(size: 28))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.userName)
                                    .font(.custom("Avenir-Heavy", size: 16))
                                    .foregroundColor(.white)
                                
                                Text("\(item.exerciseName) • \(item.exerciseReps) reps")
                                    .font(.custom("Avenir-Medium", size: 13))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            // Reject button
                            Button {
                                Task {
                                    await viewModel.rejectSelected()
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Reject")
                                }
                                .font(.custom("Avenir-Heavy", size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red)
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.isReviewing)
                            
                            // Approve button
                            Button {
                                Task {
                                    await viewModel.approveSelected()
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    if viewModel.isReviewing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Approve")
                                    }
                                }
                                .font(.custom("Avenir-Heavy", size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.isReviewing)
                        }
                    }
                    .padding()
                    .background(Color(white: 0.1))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.closeVideoPlayer()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReviewView(viewModel: ReviewViewModel(challengeId: "test", currentUserId: "user"))
}
