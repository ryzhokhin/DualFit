//
//  ChallengeDetailView.swift
//  DualFit
//
//  Main challenge detail view with tabs for Today, Review, Calendar, Leaderboard.
//

import SwiftUI

/// Challenge detail view with tabbed navigation
struct ChallengeDetailView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel: ChallengeDetailViewModel
    
    init(challenge: Challenge) {
        // We need to initialize with a placeholder that will be replaced
        let userID = "" // Will be set properly in task
        _viewModel = StateObject(wrappedValue: ChallengeDetailViewModel(
            challenge: challenge,
            currentUserId: userID
        ))
    }
    
    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tab bar
                tabBar
                
                // Tab content
                TabView(selection: $viewModel.selectedTab) {
                    // Only include TodayView if challenge hasn't ended
                    if !viewModel.challenge.hasEnded {
                        TodayView(viewModel: viewModel.todayViewModel)
                            .tag(ChallengeTab.today)
                    }
                    
                    ReviewView(viewModel: viewModel.reviewViewModel)
                        .tag(ChallengeTab.review)
                    
                    CalendarView(viewModel: viewModel.calendarViewModel)
                        .tag(ChallengeTab.calendar)
                    
                    LeaderboardView(viewModel: viewModel.leaderboardViewModel)
                        .tag(ChallengeTab.leaderboard)
                    
                    // Always include settings view, but tab bar will only show it for creators
                    SettingsView(viewModel: viewModel.settingsViewModel)
                        .tag(ChallengeTab.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle(viewModel.challenge.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
        .task {
            // Set the correct user ID
            if let userID = appViewModel.currentUser?.id {
                // Update current user ID in view model
                await MainActor.run {
                    viewModel.currentUserId = userID
                    
                    // Reinitialize view model with proper user ID
                    viewModel.todayViewModel = TodayViewModel(
                        challengeId: viewModel.challenge.id,
                        currentUserId: userID
                    )
                    viewModel.reviewViewModel = ReviewViewModel(
                        challengeId: viewModel.challenge.id,
                        currentUserId: userID
                    )
                    viewModel.calendarViewModel = CalendarViewModel(
                        challengeId: viewModel.challenge.id,
                        currentUserId: userID
                    )
                    viewModel.leaderboardViewModel = LeaderboardViewModel(
                        challengeId: viewModel.challenge.id,
                        currentUserId: userID
                    )
                    viewModel.settingsViewModel = SettingsViewModel(challenge: viewModel.challenge)
                }
                await viewModel.loadData()
            }
        }
        .onChange(of: viewModel.selectedTab) { _, _ in
            Task {
                await viewModel.refreshCurrentTab()
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
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.visibleTabs, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color("CardBackground"))
    }
    
    private func tabButton(for tab: ChallengeTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20))
                    
                    // Badge for review tab
                    if tab == .review && viewModel.pendingReviewCount > 0 {
                        Text("\(viewModel.pendingReviewCount)")
                            .font(.custom("Avenir-Heavy", size: 10))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
                
                Text(tab.rawValue)
                    .font(.custom("Avenir-Heavy", size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(viewModel.selectedTab == tab ? Color("AccentColor") : .secondary)
            .background(
                viewModel.selectedTab == tab
                    ? Color("AccentColor").opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(10)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChallengeDetailView(challenge: Challenge.sample)
            .environmentObject(AppViewModel())
    }
}

