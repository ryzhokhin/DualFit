//
//  CalendarView.swift
//  DualFit
//
//  Calendar view showing completion history.
//

import SwiftUI

/// Calendar view for viewing completion history
struct CalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Month navigation
                monthNavigation
                
                // Stats summary
                statsSummary
                
                // Calendar grid
                calendarGrid
                
                // Legend
                legendView
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showDayDetail) {
            if let day = viewModel.selectedDay {
                DayDetailSheet(day: day, viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Month Navigation
    
    private var monthNavigation: some View {
        HStack {
            Button {
                Task {
                    await viewModel.previousMonth()
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color("AccentColor"))
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(viewModel.monthYearString)
                    .font(.custom("Avenir-Heavy", size: 20))
                    .foregroundColor(.primary)
                
                Button {
                    Task {
                        await viewModel.goToCurrentMonth()
                    }
                } label: {
                    Text("Today")
                        .font(.custom("Avenir-Medium", size: 13))
                        .foregroundColor(Color("AccentColor"))
                }
            }
            
            Spacer()
            
            Button {
                Task {
                    await viewModel.nextMonth()
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
    
    // MARK: - Stats Summary
    
    private var statsSummary: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(viewModel.completeDays)")
                    .font(.custom("Avenir-Heavy", size: 28))
                    .foregroundColor(.green)
                
                Text("Complete Days")
                    .font(.custom("Avenir-Medium", size: 12))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            VStack(spacing: 4) {
                Text("\(viewModel.totalDaysInChallenge)")
                    .font(.custom("Avenir-Heavy", size: 28))
                    .foregroundColor(.primary)
                
                Text("Total Days")
                    .font(.custom("Avenir-Medium", size: 12))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            VStack(spacing: 4) {
                Text(String(format: "%.0f%%", viewModel.completionPercentage))
                    .font(.custom("Avenir-Heavy", size: 28))
                    .foregroundColor(Color("AccentColor"))
                
                Text("Completion")
                    .font(.custom("Avenir-Medium", size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.custom("Avenir-Heavy", size: 12))
                        .foregroundColor(.secondary)
                        .frame(height: 30)
                }
            }
            
            // Days
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.calendarDays) { day in
                    CalendarDayCell(day: day) {
                        viewModel.selectDay(day)
                    }
                }
            }
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(16)
    }
    
    // MARK: - Legend
    
    private var legendView: some View {
        HStack(spacing: 20) {
            legendItem(color: .green, label: "Complete")
            legendItem(color: .yellow, label: "Partial")
            legendItem(color: .red.opacity(0.3), label: "None")
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(12)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(label)
                .font(.custom("Avenir-Medium", size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let day: CalendarDay
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(day.isInMonth ? day.color.opacity(0.4) : Color.clear)
                
                // Today indicator
                if day.isToday && day.isInMonth {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("AccentColor"), lineWidth: 2)
                }
                
                // Day number
                Text("\(day.dayNumber)")
                    .font(.custom("Avenir-Heavy", size: 14))
                    .foregroundColor(
                        day.isInMonth
                            ? (day.isToday ? Color("AccentColor") : .primary)
                            : .secondary.opacity(0.3)
                    )
            }
            .frame(height: 40)
        }
        .buttonStyle(.plain)
        .disabled(!day.isInMonth)
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheet: View {
    let day: CalendarDay
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Date header
                VStack(spacing: 8) {
                    Text(day.date.fullDateString)
                        .font(.custom("Avenir-Heavy", size: 22))
                        .foregroundColor(.primary)
                    
                    if let status = day.status {
                        statusBadge(for: status.status)
                    }
                }
                .padding()
                
                // Status breakdown
                if let status = day.status {
                    VStack(spacing: 16) {
                        statusRow(
                            icon: "checkmark.circle.fill",
                            label: "Approved",
                            count: status.approvedCount,
                            total: status.totalExercises,
                            color: .green
                        )
                        
                        statusRow(
                            icon: "clock.fill",
                            label: "Pending",
                            count: status.pendingCount,
                            total: status.totalExercises,
                            color: .orange
                        )
                        
                        statusRow(
                            icon: "xmark.circle.fill",
                            label: "Rejected",
                            count: status.rejectedCount,
                            total: status.totalExercises,
                            color: .red
                        )
                        
                        let notSubmitted = status.totalExercises - status.approvedCount - status.pendingCount - status.rejectedCount
                        if notSubmitted > 0 {
                            statusRow(
                                icon: "circle",
                                label: "Not Submitted",
                                count: notSubmitted,
                                total: status.totalExercises,
                                color: .secondary
                            )
                        }
                    }
                    .padding()
                    .background(Color("CardBackground"))
                    .cornerRadius(16)
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No data for this day")
                            .font(.custom("Avenir-Medium", size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color("CardBackground"))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .background(Color("Background"))
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.closeDayDetail()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func statusBadge(for status: DayCompletionStatus.CompletionLevel) -> some View {
        Group {
            switch status {
            case .complete:
                Text("Complete ✅")
                    .font(.custom("Avenir-Heavy", size: 14))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
            case .partial:
                Text("Partially Complete")
                    .font(.custom("Avenir-Heavy", size: 14))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(8)
            case .none:
                Text("Not Started")
                    .font(.custom("Avenir-Heavy", size: 14))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(8)
            }
        }
    }
    
    private func statusRow(icon: String, label: String, count: Int, total: Int, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(label)
                .font(.custom("Avenir-Medium", size: 16))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(count)/\(total)")
                .font(.custom("Avenir-Heavy", size: 16))
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarView(viewModel: CalendarViewModel(challengeId: "test", currentUserId: "user"))
}

