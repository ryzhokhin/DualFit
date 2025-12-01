//
//  HomeView.swift
//  DualFit
//
//  Main home screen showing user's challenges.
//

import SwiftUI

/// Home view showing user's challenges
struct HomeView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel = HomeViewModel()
    
    @State private var showCreateChallenge = false
    @State private var showJoinChallenge = false
    @State private var selectedChallenge: Challenge?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // User header
                        userHeader
                        
                        // Quick actions
                        quickActions
                        
                        // Challenges list
                        challengesList
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .navigationTitle("DualFit")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCreateChallenge) {
                CreateChallengeView()
                    .environmentObject(appViewModel)
                    .onDisappear {
                        Task {
                            await viewModel.refresh()
                        }
                    }
            }
            .sheet(isPresented: $showJoinChallenge) {
                JoinChallengeView()
                    .environmentObject(appViewModel)
                    .onDisappear {
                        Task {
                            await viewModel.refresh()
                        }
                    }
            }
            .navigationDestination(item: $selectedChallenge) { challenge in
                ChallengeDetailView(challenge: challenge)
                    .environmentObject(appViewModel)
            }
        }
        .task {
            if let user = appViewModel.currentUser {
                await viewModel.loadChallenges(userID: user.id)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var userHeader: some View {
        HStack(spacing: 16) {
            // Avatar
            Text(appViewModel.currentUser?.avatarEmoji ?? "💪")
                .font(.system(size: 44))
                .frame(width: 70, height: 70)
                .background(Color("AccentColor").opacity(0.2))
                .cornerRadius(20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.custom("Avenir-Medium", size: 14))
                    .foregroundColor(.secondary)
                
                Text(appViewModel.currentUser?.displayName ?? "Friend")
                    .font(.custom("Avenir-Heavy", size: 24))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(20)
    }
    
    private var quickActions: some View {
        HStack(spacing: 16) {
            // Create challenge button
            Button {
                showCreateChallenge = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                    Text("Create")
                        .font(.custom("Avenir-Heavy", size: 14))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [Color("AccentColor"), Color("AccentLight")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
            }
            
            // Join challenge button
            Button {
                showJoinChallenge = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 28))
                    Text("Join")
                        .font(.custom("Avenir-Heavy", size: 14))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .foregroundColor(Color("AccentColor"))
                .background(Color("AccentColor").opacity(0.15))
                .cornerRadius(16)
            }
        }
    }
    
    private var challengesList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Challenges")
                .font(.custom("Avenir-Heavy", size: 20))
                .foregroundColor(.primary)
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if viewModel.challenges.isEmpty {
                emptyChallengesView
            } else {
                ForEach(viewModel.challenges) { summary in
                    ChallengeCard(summary: summary)
                        .onTapGesture {
                            selectedChallenge = summary.challenge
                        }
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.custom("Avenir-Medium", size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var emptyChallengesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No challenges yet")
                .font(.custom("Avenir-Heavy", size: 18))
                .foregroundColor(.secondary)
            
            Text("Create a new challenge or join one using a code from a friend!")
                .font(.custom("Avenir-Medium", size: 14))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
}

// MARK: - Challenge Card

struct ChallengeCard: View {
    let summary: ChallengeSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.challenge.name)
                        .font(.custom("Avenir-Heavy", size: 18))
                        .foregroundColor(.primary)
                    
                    Text("\(summary.challenge.startDate.shortDateString) – \(summary.challenge.endDate.shortDateString)")
                        .font(.custom("Avenir-Medium", size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                if summary.challenge.isActive {
                    Text("Active")
                        .font(.custom("Avenir-Heavy", size: 12))
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                } else if summary.challenge.hasEnded {
                    Text("Ended")
                        .font(.custom("Avenir-Heavy", size: 12))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Stats
            HStack(spacing: 20) {
                statItem(
                    icon: "star.fill",
                    value: "\(summary.totalPoints)",
                    label: "Points",
                    color: .yellow
                )
                
                statItem(
                    icon: "checkmark.circle.fill",
                    value: "\(summary.completedDays)/\(summary.totalDays)",
                    label: "Days",
                    color: .green
                )
                
                statItem(
                    icon: "person.2.fill",
                    value: "\(summary.participantCount)",
                    label: "Friends",
                    color: .blue
                )
                
                Spacer()
                
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: summary.completionPercentage / 100)
                        .stroke(Color("AccentColor"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(summary.completionPercentage))%")
                        .font(.custom("Avenir-Heavy", size: 12))
                        .foregroundColor(.primary)
                }
                .frame(width: 50, height: 50)
            }
        }
        .padding(16)
        .background(Color("CardBackground"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.custom("Avenir-Heavy", size: 16))
                    .foregroundColor(.primary)
            }
            
            Text(label)
                .font(.custom("Avenir-Medium", size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(AppViewModel())
}

