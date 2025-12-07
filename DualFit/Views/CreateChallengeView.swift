//
//  CreateChallengeView.swift
//  DualFit
//
//  View for creating a new challenge.
//

import SwiftUI

/// View for creating a new fitness challenge
struct CreateChallengeView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel = CreateChallengeViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background")
                    .ignoresSafeArea()
                
                if viewModel.createdChallenge != nil {
                    successView
                } else {
                    formView
                }
            }
            .navigationTitle("Create Challenge")
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
        ScrollView {
            VStack(spacing: 24) {
                // Challenge info section
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Challenge Info")
                    
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.custom("Avenir-Medium", size: 13))
                            .foregroundColor(.secondary)
                        
                        TextField("e.g., November Pushup Challenge", text: $viewModel.name)
                            .font(.custom("Avenir-Medium", size: 16))
                            .padding()
                            .background(Color("CardBackground"))
                            .cornerRadius(12)
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description (optional)")
                            .font(.custom("Avenir-Medium", size: 13))
                            .foregroundColor(.secondary)
                        
                        TextField("Brief description...", text: $viewModel.description, axis: .vertical)
                            .font(.custom("Avenir-Medium", size: 16))
                            .lineLimit(3...5)
                            .padding()
                            .background(Color("CardBackground"))
                            .cornerRadius(12)
                    }
                }
                
                // Dates section
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Duration")
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Start Date")
                                .font(.custom("Avenir-Medium", size: 13))
                                .foregroundColor(.secondary)
                            
                            DatePicker(
                                "",
                                selection: $viewModel.startDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("End Date")
                                .font(.custom("Avenir-Medium", size: 13))
                                .foregroundColor(.secondary)
                            
                            DatePicker(
                                "",
                                selection: $viewModel.endDate,
                                in: viewModel.startDate...,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        }
                    }
                    
                    Text("\(viewModel.durationDays) days")
                        .font(.custom("Avenir-Heavy", size: 14))
                        .foregroundColor(Color("AccentColor"))
                }
                
                // Exercises section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        sectionHeader("Exercises")
                        
                        Spacer()
                        
                        if viewModel.exercises.count < 10 {
                            Button {
                                viewModel.addExercise()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color("AccentColor"))
                            }
                        }
                    }
                    
                    ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                        exerciseRow(index: index)
                    }
                }
                
                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.custom("Avenir-Medium", size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Create button
                Button {
                    guard let userId = appViewModel.currentUser?.id else { return }
                    Task {
                        await viewModel.createChallenge(creatorUserId: userId)
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Create Challenge")
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .font(.custom("Avenir-Heavy", size: 18))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        viewModel.isValid
                            ? Color("AccentColor")
                            : Color.gray
                    )
                    .cornerRadius(14)
                }
                .disabled(!viewModel.isValid || viewModel.isLoading)
            }
            .padding()
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Challenge Created!")
                .font(.custom("Avenir-Heavy", size: 28))
                .foregroundColor(.primary)
            
            // Join code
            VStack(spacing: 12) {
                Text("Share this code with friends:")
                    .font(.custom("Avenir-Medium", size: 16))
                    .foregroundColor(.secondary)
                
                if let code = viewModel.joinCode {
                    Text(code)
                        .font(.custom("Avenir-Heavy", size: 36))
                        .foregroundColor(Color("AccentColor"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color("AccentColor").opacity(0.1))
                        .cornerRadius(12)
                    
                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Code")
                        }
                        .font(.custom("Avenir-Heavy", size: 14))
                        .foregroundColor(Color("AccentColor"))
                    }
                }
            }
            .padding()
            .background(Color("CardBackground"))
            .cornerRadius(16)
            
            Spacer()
            
            // Done button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.custom("Avenir-Heavy", size: 18))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("AccentColor"))
                    .cornerRadius(14)
            }
        }
        .padding()
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("Avenir-Heavy", size: 18))
            .foregroundColor(.primary)
    }
    
    private func exerciseRow(index: Int) -> some View {
        HStack(spacing: 12) {
            // Exercise name
            TextField("Exercise name", text: $viewModel.exercises[index].name)
                .font(.custom("Avenir-Medium", size: 16))
                .padding()
                .background(Color("CardBackground"))
                .cornerRadius(12)
            
            // Reps
            VStack(spacing: 2) {
                Text("Reps")
                    .font(.custom("Avenir-Medium", size: 10))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Button {
                        if viewModel.exercises[index].reps > 1 {
                            viewModel.exercises[index].reps -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(viewModel.exercises[index].reps)")
                        .font(.custom("Avenir-Heavy", size: 16))
                        .frame(width: 30)
                    
                    Button {
                        viewModel.exercises[index].reps += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color("AccentColor"))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color("CardBackground"))
            .cornerRadius(12)
            
            // Delete button
            if viewModel.exercises.count > 1 {
                Button {
                    viewModel.removeExercise(at: index)
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CreateChallengeView()
        .environmentObject(AppViewModel())
}

