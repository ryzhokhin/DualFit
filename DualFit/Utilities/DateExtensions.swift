//
//  DateExtensions.swift
//  DualFit
//
//  Date utility extensions.
//

import Foundation

extension Date {
    /// Start of day for this date
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// End of day for this date
    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
    }
    
    /// Check if this date is the same day as another date
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
    
    /// Check if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Format as a short date string (e.g., "Nov 30")
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
    
    /// Format as a full date string (e.g., "November 30, 2025")
    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: self)
    }
    
    /// Format as relative string (e.g., "Today", "Yesterday", or date)
    var relativeDateString: String {
        if isToday {
            return "Today"
        }
        
        if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        }
        
        return shortDateString
    }
    
    /// Get all dates in a month
    static func datesInMonth(for date: Date) -> [Date] {
        let calendar = Calendar.current
        
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    /// Get the first day of the month
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    /// Get the last day of the month
    var endOfMonth: Date {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return self
        }
        return calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? self
    }
    
    /// Month and year string (e.g., "November 2025")
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }
    
    /// Day of week (1 = Sunday, 7 = Saturday)
    var dayOfWeek: Int {
        Calendar.current.component(.weekday, from: self)
    }
    
    /// Day number in month (1-31)
    var dayOfMonth: Int {
        Calendar.current.component(.day, from: self)
    }
}

