import Foundation

extension Date {
    /// The start of the calendar day (00:00:00) in the user's local
    /// timezone. Used for daily budget rollover per `A4`.
    public func startOfDay(in calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    /// Whether two dates fall on the same calendar day in the user's
    /// local timezone.
    public func isSameDay(as other: Date, in calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }
}
