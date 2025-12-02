//
//  JoinChallengeView.swift
//  DualFit
//
//  View for joining an existing challenge with a code.
//

import SwiftUI

/// View for joining a challenge using a join code
struct JoinChallengeView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel = JoinChallengeViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background")
                    .ignoresSafeArea()
                
                if viewModel.joinedSuccessfully {
                    successView
                } else {
                    formView
                }
            }
            .navigationTitle("Join Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Form View
    
    private var formView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(Color("AccentColor"))
            
            // Instructions
            VStack(spacing: 8) {
                Text("Join a Challenge")
                    .font(.custom("Avenir-Heavy", size: 24))
                    .foregroundColor(.primary)
                
                Text("Enter the join code shared by your friend")
                    .font(.custom("Avenir-Medium", size: 15))
                    .foregroundColor(.secondary)
            }
            
            // Code input
            VStack(spacing: 16) {
                TextField("Enter join code", text: $viewModel.joinCode)
                    .font(.custom("Avenir-Heavy", size: 24))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color("CardBackground"))
                    .cornerRadius(16)
                
                // Search button
                Button {
                    Task {
                        await viewModel.searchChallenge()
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "magnifyingglass")
                            Text("Find Challenge")
                        }
                    }
                    .font(.custom("Avenir-Heavy", size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        viewModel.isValidCode
                            ? Color("AccentColor")
                            : Color.gray
                    )
                    .cornerRadius(12)
                }
                .disabled(!viewModel.isValidCode || viewModel.isLoading)
            }
            .padding(.horizontal)
            
            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.custom("Avenir-Medium", size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Found challenge preview
            if let challenge = viewModel.foundChallenge {
                challengePreview(challenge)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Challenge Preview
    
    private func challengePreview(_ challenge: Challenge) -> some View {
        VStack(spacing: 16) {
            // Challenge info
            VStack(spacing: 8) {
                Text("Found Challenge!")
                    .font(.custom("Avenir-Heavy", size: 14))
                    .foregroundColor(.green)
                
                Text(challenge.name)
                    .font(.custom("Avenir-Heavy", size: 20))
                    .foregroundColor(.primary)
                
                if !challenge.description.isEmpty {
                    Text(challenge.description)
                        .font(.custom("Avenir-Medium", size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Text("\(challenge.startDate.shortDateString) – \(challenge.endDate.shortDateString)")
                    .font(.custom("Avenir-Medium", size: 13))
                    .foregroundColor(.secondary)
            }
            
            // Join button
            Button {
                guard let userID = appViewModel.currentUser?.id else { return }
                Task {
                    await viewModel.joinChallenge(userId: userID)
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Join Challenge")
                        Image(systemName: "arrow.right.circle.fill")
                    }
                }
                .font(.custom("Avenir-Heavy", size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color("AccentColor"))
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("You're In!")
                    .font(.custom("Avenir-Heavy", size: 28))
                    .foregroundColor(.primary)
                
                Text("Successfully joined the challenge")
                    .font(.custom("Avenir-Medium", size: 16))
                    .foregroundColor(.secondary)
                
                if let challenge = viewModel.foundChallenge {
                    Text(challenge.name)
                        .font(.custom("Avenir-Heavy", size: 18))
                        .foregroundColor(Color("AccentColor"))
                        .padding(.top, 8)
                }
            }
            
            Spacer()
            
            // Done button
            Button {
                dismiss()
            } label: {
                Text("Let's Go!")
                    .font(.custom("Avenir-Heavy", size: 18))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("AccentColor"))
                    .cornerRadius(14)
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    JoinChallengeView()
        .environmentObject(AppViewModel())
}

