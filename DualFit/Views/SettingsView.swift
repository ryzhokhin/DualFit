//
//  SettingsView.swift
//  DualFit
//
//  View for challenge settings (only visible to creator).
//

import SwiftUI

/// View for challenge settings
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Join Code Section
                joinCodeSection
                
                // Challenge Name (read-only)
//                challengeNameSection
                
                // Editable Dates Section
                datesSection
                
                // Editable Exercises Section
                exercisesSection
                
                // Save Button
                if viewModel.hasChanges {
                    saveButton
                }
                
                // Success/Error messages
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.custom("Avenir-Medium", size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                if viewModel.saveSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Changes saved successfully!")
                            .font(.custom("Avenir-Medium", size: 14))
                            .foregroundColor(.green)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
    }
    
    // MARK: - Join Code Section
    
    private var joinCodeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invitation Code")
                .font(.custom("Avenir-Heavy", size: 18))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                Text("Share this code with friends to invite them to join:")
                    .font(.custom("Avenir-Medium", size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Join code display
                Text(viewModel.joinCode)
                    .font(.custom("Avenir-Heavy", size: 42))
                    .foregroundColor(Color("AccentColor"))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color("AccentColor").opacity(0.1))
                    .cornerRadius(16)
                
                // Copy button
                Button {
                    viewModel.copyJoinCode()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(viewModel.copiedToClipboard ? "Copied!" : "Copy Code")
                    }
                    .font(.custom("Avenir-Heavy", size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("AccentColor"))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    // MARK: - Challenge Name Section
//    
//    private var challengeNameSection: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Challenge Name")
//                .font(.custom("Avenir-Heavy", size: 18))
//                .foregroundColor(.primary)
//            
//            Text(viewModel.challenge.name)
//                .font(.custom("Avenir-Heavy", size: 16))
//                .foregroundColor(.primary)
//                .padding()
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .background(Color("CardBackground"))
//                .cornerRadius(12)
//        }
//        .padding()
//        .background(Color("CardBackground"))
//        .cornerRadius(16)
//    }
//    
    // MARK: - Dates Section
    
    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Duration")
                .font(.custom("Avenir-Heavy", size: 18))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
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
                
                VStack(alignment: .leading, spacing: 8) {
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
            
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: viewModel.startDate, to: viewModel.endDate).day ?? 0
            Text("\(days + 1) days")
                .font(.custom("Avenir-Heavy", size: 14))
                .foregroundColor(Color("AccentColor"))
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    // MARK: - Exercises Section
    
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Exercises")
                    .font(.custom("Avenir-Heavy", size: 18))
                    .foregroundColor(.primary)
                
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
            
            if viewModel.exercises.isEmpty {
                Text("No exercises yet. Add one to get started.")
                    .font(.custom("Avenir-Medium", size: 14))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                    exerciseRow(at: index)
                }
            }
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    private func exerciseRow(at index: Int) -> some View {
        HStack(spacing: 12) {
            // Exercise name
            TextField("Exercise name", text: Binding(
                get: { viewModel.exercises[index].name },
                set: { viewModel.exercises[index].name = $0 }
            ))
            .font(.custom("Avenir-Medium", size: 16))
            .padding()
            .background(Color("Background"))
            .cornerRadius(12)
            
            // Reps
            VStack(spacing: 2) {
                Text("Reps")
                    .font(.custom("Avenir-Medium", size: 10))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Button {
                        if viewModel.exercises[index].dailyRequiredReps > 1 {
                            viewModel.exercises[index].dailyRequiredReps -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(viewModel.exercises[index].dailyRequiredReps)")
                        .font(.custom("Avenir-Heavy", size: 16))
                        .frame(width: 30)
                    
                    Button {
                        viewModel.exercises[index].dailyRequiredReps += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color("AccentColor"))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color("Background"))
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
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button {
            Task {
                await viewModel.saveChanges()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Changes")
                }
            }
            .font(.custom("Avenir-Heavy", size: 18))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color("AccentColor"))
            .cornerRadius(14)
        }
        .disabled(viewModel.isLoading)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(viewModel: SettingsViewModel(challenge: Challenge.sample))
}

