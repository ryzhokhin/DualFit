//
//  RootView.swift
//  DualFit
//
//  Root view that handles app state and navigation.
//

import SwiftUI

/// The root view of the app that handles state-based navigation
struct RootView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        Group {
            switch appViewModel.appState {
            case .loading:
                LoadingView()
                
            case .needsOnboarding:
                OnboardingView()
                
            case .ready:
                if appViewModel.currentUser != nil {
                    HomeView()
                } else {
                    LoadingView()
                }
                
            case .error(let message):
                ErrorView(message: message) {
                    Task {
                        await appViewModel.retry()
                    }
                }
            }
        }
        .animation(.easeInOut, value: appViewModel.appState)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("AccentDark"), Color("AccentLight")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App logo/icon
                Text("💪")
                    .font(.system(size: 80))
                
                Text("DualFit")
                    .font(.custom("Avenir-Heavy", size: 36))
                    .foregroundColor(.white)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text("Loading...")
                    .font(.custom("Avenir-Medium", size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Oops!")
                    .font(.custom("Avenir-Heavy", size: 28))
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.custom("Avenir-Medium", size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.custom("Avenir-Heavy", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color("AccentColor"))
                    .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environmentObject(AppViewModel())
}

