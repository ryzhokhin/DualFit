//
//  OnboardingView.swift
//  DualFit
//
//  Onboarding flow for new users to set up their profile.
//

import SwiftUI

/// Onboarding view for new users
struct OnboardingView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    @State private var displayName: String = ""
    @State private var selectedEmoji: String = "💪"
    
    let emojiOptions = ["💪", "🏋️", "🏃", "🧘", "🚴", "🏊", "⚡️", "🔥", "🌟", "🎯", "👊", "🦾"]
    
    var isValid: Bool {
        displayName.trimmingCharacters(in: .whitespaces).count >= 2
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color("AccentDark"), Color("AccentLight")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Header
                    VStack(spacing: 16) {
                        Text("Welcome to")
                            .font(.custom("Avenir-Medium", size: 20))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("DualFit")
                            .font(.custom("Avenir-Heavy", size: 42))
                            .foregroundColor(.white)
                        
                        Text("Challenge friends • Stay accountable")
                            .font(.custom("Avenir-Medium", size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Form card
                    VStack(spacing: 24) {
                        Text("Create Your Profile")
                            .font(.custom("Avenir-Heavy", size: 22))
                            .foregroundColor(.primary)
                        
                        // Name input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Name")
                                .font(.custom("Avenir-Medium", size: 14))
                                .foregroundColor(.secondary)
                            
                            TextField("Enter your name", text: $displayName)
                                .font(.custom("Avenir-Medium", size: 18))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .autocorrectionDisabled()
                        }
                        
                        // Avatar emoji picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose Your Avatar")
                                .font(.custom("Avenir-Medium", size: 14))
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                ForEach(emojiOptions, id: \.self) { emoji in
                                    Button {
                                        selectedEmoji = emoji
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                            .frame(width: 50, height: 50)
                                            .background(
                                                selectedEmoji == emoji
                                                    ? Color("AccentColor").opacity(0.3)
                                                    : Color.clear
                                            )
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        selectedEmoji == emoji
                                                            ? Color("AccentColor")
                                                            : Color.clear,
                                                        lineWidth: 2
                                                    )
                                            )
                                    }
                                }
                            }
                        }
                        
                        // Error message
                        if let error = appViewModel.errorMessage {
                            Text(error)
                                .font(.custom("Avenir-Medium", size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Continue button
                        Button {
                            Task {
                                await appViewModel.completeOnboarding(
                                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                                    avatarEmoji: selectedEmoji
                                )
                            }
                        } label: {
                            HStack {
                                if appViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Get Started")
                                    Image(systemName: "arrow.right")
                                }
                            }
                            .font(.custom("Avenir-Heavy", size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                isValid
                                    ? Color("AccentColor")
                                    : Color.gray
                            )
                            .cornerRadius(14)
                        }
                        .disabled(!isValid || appViewModel.isLoading)
                    }
                    .padding(24)
                    .background(Color("CardBackground"))
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AppViewModel())
}

