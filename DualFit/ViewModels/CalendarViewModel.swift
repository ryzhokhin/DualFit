//
//  CalendarViewModel.swift
//  DualFit
//
//  View model for the calendar view showing completion history.
//

import Foundation
import SwiftUI

/// Represents a day in the calendar with its completion status
struct CalendarDay: Identifiable, Equatable {
    let id: String
    let date: Date
    var status: DayCompletionStatus?
    
    var dayNumber: Int {
        date.dayOfMonth
    }
    
    var isToday: Bool {
        date.isToday
    }
    
    var color: Color {
        guard let status = status else { return .clear }
        
        switch status.status {
        case .complete:
            return .green
        case .partial:
            return .yellow
        case .none:
            return .red.opacity(0.3)
        }
    }
    
    var isInMonth: Bool = true
}

/// View model for the calendar tab
@MainActor
class CalendarViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentMonth: Date = Date()
    @Published var calendarDays: [CalendarDay] = []
    @Published var completionStatuses: [DayCompletionStatus] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedDay: CalendarDay?
    @Published var showDayDetail: Bool = false
    
    // MARK: - Properties
    
    private let challengeID: String
    private let currentUserID: String
    private var exercises: [ChallengeExercise] = []
    private var challenge: Challenge?
    
    private let submissionService = SubmissionService.shared
    
    // MARK: - Computed Properties
    
    var monthYearString: String {
        currentMonth.monthYearString
    }
    
    var weekdayHeaders: [String] {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }
    
    var completeDays: Int {
        completionStatuses.filter { $0.status == .complete }.count
    }
    
    var totalDaysInChallenge: Int {
        challenge?.daysElapsed ?? 0
    }
    
    var completionPercentage: Double {
        guard totalDaysInChallenge > 0 else { return 0 }
        return Double(completeDays) / Double(totalDaysInChallenge) * 100
    }
    
    // MARK: - Initialization
    
    init(challengeID: String, currentUserID: String) {
        self.challengeID = challengeID
        self.currentUserID = currentUserID
    }
    
    // MARK: - Public Methods
    
    /// Set exercises (called from parent view model)
    func setExercises(_ exercises: [ChallengeExercise]) {
        self.exercises = exercises
    }
    
    /// Set challenge (called from parent view model)
    func setChallenge(_ challenge: Challenge) {
        self.challenge = challenge
    }
    
    /// Load completion status for the current month
    func loadCompletionStatus() async {
        guard let challenge = challenge else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Calculate date range for the challenge
            let startDate = challenge.startDate
            let endDate = min(challenge.endDate, Date())
            
            completionStatuses = try await submissionService.getCompletionStatus(
                challengeID: challengeID,
                userID: currentUserID,
                exerciseCount: exercises.count,
                startDate: startDate,
                endDate: endDate
            )
            
            buildCalendarDays()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Build the calendar days grid for the current month
    private func buildCalendarDays() {
        let calendar = Calendar.current
        let startOfMonth = currentMonth.startOfMonth
        let endOfMonth = currentMonth.endOfMonth
        
        // Get all days in the month
        let daysInMonth = Date.datesInMonth(for: currentMonth)
        
        // Calculate padding for first day of month
        let firstWeekday = startOfMonth.dayOfWeek
        let leadingPadding = firstWeekday - 1
        
        var days: [CalendarDay] = []
        
        // Add leading padding days (from previous month)
        for i in stride(from: leadingPadding, through: 1, by: -1) {
            if let paddingDate = calendar.date(byAdding: .day, value: -i, to: startOfMonth) {
                var day = CalendarDay(
                    id: "padding-\(paddingDate.timeIntervalSince1970)",
                    date: paddingDate
                )
                day.isInMonth = false
                days.append(day)
            }
        }
        
        // Add days in month
        for date in daysInMonth {
            let normalizedDate = date.startOfDay
            let status = completionStatuses.first {
                calendar.isDate($0.date, inSameDayAs: normalizedDate)
            }
            
            let day = CalendarDay(
                id: ISO8601DateFormatter().string(from: normalizedDate),
                date: normalizedDate,
                status: status
            )
            days.append(day)
        }
        
        // Add trailing padding to complete the grid (total should be multiple of 7)
        let totalDays = days.count
        let remainingDays = (7 - (totalDays % 7)) % 7
        
        for i in 1...max(remainingDays, 0) {
            if let paddingDate = calendar.date(byAdding: .day, value: i, to: endOfMonth) {
                var day = CalendarDay(
                    id: "padding-\(paddingDate.timeIntervalSince1970)",
                    date: paddingDate
                )
                day.isInMonth = false
                days.append(day)
            }
        }
        
        calendarDays = days
    }
    
    /// Go to previous month
    func previousMonth() async {
        if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
            buildCalendarDays()
        }
    }
    
    /// Go to next month
    func nextMonth() async {
        if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
            buildCalendarDays()
        }
    }
    
    /// Go to current month
    func goToCurrentMonth() async {
        currentMonth = Date()
        buildCalendarDays()
    }
    
    /// Select a day to view details
    func selectDay(_ day: CalendarDay) {
        guard day.isInMonth else { return }
        selectedDay = day
        showDayDetail = true
    }
    
    /// Close day detail
    func closeDayDetail() {
        showDayDetail = false
        selectedDay = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

