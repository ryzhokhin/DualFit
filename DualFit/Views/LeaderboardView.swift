//
//  LeaderboardView.swift
//  DualFit
//
//  Leaderboard view showing participant rankings.
//

import SwiftUI

/// Leaderboard view showing rankings
struct LeaderboardView: View {
    @ObservedObject var viewModel: LeaderboardViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Winner banner
                if viewModel.hasWinner {
                    winnerBanner
                }
                
                // Current user position
                if let entry = viewModel.currentUserEntry {
                    yourPosition(entry: entry)
                }
                
                // Full leaderboard
                leaderboardList
            }
            .padding()
        }
    }
    
    // MARK: - Winner Banner
    
    private var winnerBanner: some View {
        VStack(spacing: 16) {
            if let winner = viewModel.winner {
                Text("🏆")
                    .font(.system(size: 60))
                
                if viewModel.isTied {
                    Text("It's a Tie!")
                        .font(.custom("Avenir-Heavy", size: 24))
                        .foregroundColor(.primary)
                } else {
                    Text("Leader")
                        .font(.custom("Avenir-Heavy", size: 14))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Text(winner.user.avatarEmoji)
                            .font(.system(size: 36))
                        
                        Text(winner.user.displayName)
                            .font(.custom("Avenir-Heavy", size: 24))
                            .foregroundColor(.primary)
                    }
                }
                
                Text("\(winner.totalPoints) points")
                    .font(.custom("Avenir-Heavy", size: 18))
                    .foregroundColor(Color("AccentColor"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 2)
        )
    }
    
    // MARK: - Your Position
    
    private func yourPosition(entry: LeaderboardEntry) -> some View {
        HStack(spacing: 16) {
            // Rank
            VStack {
                Text("#\(entry.rank)")
                    .font(.custom("Avenir-Heavy", size: 24))
                    .foregroundColor(Color("AccentColor"))
                
                Text("Your Rank")
                    .font(.custom("Avenir-Medium", size: 11))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            // Points
            VStack {
                Text("\(entry.totalPoints)")
                    .font(.custom("Avenir-Heavy", size: 24))
                    .foregroundColor(.primary)
                
                Text("Points")
                    .font(.custom("Avenir-Medium", size: 11))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            // Submissions
            VStack {
                Text("\(entry.approvedSubmissions)")
                    .font(.custom("Avenir-Heavy", size: 24))
                    .foregroundColor(.green)
                
                Text("Approved")
                    .font(.custom("Avenir-Medium", size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("AccentColor").opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("AccentColor").opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Leaderboard List
    
    private var leaderboardList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rankings")
                .font(.custom("Avenir-Heavy", size: 18))
                .foregroundColor(.primary)
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if viewModel.entries.isEmpty {
                emptyView
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.entries) { entry in
                        LeaderboardRow(
                            entry: entry,
                            isCurrentUser: viewModel.isCurrentUser(entry),
                            badge: viewModel.rankBadge(for: entry.rank)
                        )
                    }
                }
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No points yet")
                .font(.custom("Avenir-Medium", size: 16))
                .foregroundColor(.secondary)
            
            Text("Complete exercises and get approved to earn points!")
                .font(.custom("Avenir-Medium", size: 14))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool
    let badge: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                if !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 24))
                } else {
                    Text("#\(entry.rank)")
                        .font(.custom("Avenir-Heavy", size: 16))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40)
            
            // Avatar
            Text(entry.user.avatarEmoji)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(Color("AccentColor").opacity(0.2))
                .cornerRadius(12)
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.user.displayName)
                        .font(.custom("Avenir-Heavy", size: 16))
                        .foregroundColor(.primary)
                    
                    if isCurrentUser {
                        Text("YOU")
                            .font(.custom("Avenir-Heavy", size: 10))
                            .foregroundColor(Color("AccentColor"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color("AccentColor").opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text("\(entry.approvedSubmissions) approved")
                    .font(.custom("Avenir-Medium", size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Points
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.totalPoints)")
                    .font(.custom("Avenir-Heavy", size: 20))
                    .foregroundColor(.primary)
                
                Text("pts")
                    .font(.custom("Avenir-Medium", size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            isCurrentUser
                ? Color("AccentColor").opacity(0.08)
                : Color("CardBackground")
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isCurrentUser ? Color("AccentColor").opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Preview

#Preview {
    LeaderboardView(viewModel: LeaderboardViewModel(challengeID: "test", currentUserID: "user"))
}

