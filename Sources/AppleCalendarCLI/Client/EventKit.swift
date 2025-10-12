import Foundation
import EventKit

// MARK: - EventKit Client

struct CalendarDTO: Codable {
    let title: String
    let colorHex: String
    let source: String
    let sourceType: String
}

struct EventDTO: Codable {
    let id: String
    let calendar: String
    let title: String
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let start: Int64  // epoch seconds
    let end: Int64  // epoch seconds
    let startFormatted: String
    let endFormatted: String
    let url: String?
    let attendees: [String]?
}

/// Client that abstracts EventKit operations
class EventKitClient {
    private let store: EKEventStore
    
    init() {
        self.store = EKEventStore()
    }
    
    /// Request calendar access permission
    func requestAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Fetch calendar list
    func fetchCalendars() -> [CalendarDTO] {
        let calendars = store.calendars(for: .event)
        return calendars.sorted { $0.title < $1.title }.map { calendar in
            let colorHex = String(
                format: "%02X%02X%02X",
                Int((calendar.cgColor.components?[0] ?? 0.0) * 255),
                Int((calendar.cgColor.components?[1] ?? 0.0) * 255),
                Int((calendar.cgColor.components?[2] ?? 0.0) * 255)
            )

            let sourceType: String
            switch calendar.source.sourceType {
            case .local:
                sourceType = "Local"
            case .exchange:
                sourceType = "Exchange"
            case .calDAV:
                sourceType = "CalDAV"
            case .mobileMe:
                sourceType = "MobileMe"
            case .subscribed:
                sourceType = "Subscribed"
            case .birthdays:
                sourceType = "Birthdays"
            @unknown default:
                sourceType = "Unknown"
            }

            return CalendarDTO(
                title: calendar.title,
                colorHex: "#\(colorHex)",
                source: calendar.source.title,
                sourceType: sourceType
            )
        }
    }
    
    /// Fetch events from specified time range
    func fetchEvents(from: Date, to: Date, calendars filter: [String]) -> [EventDTO] {
        let lower = Set(filter.map { $0.lowercased() })
        let cals: [EKCalendar]?
        if lower.isEmpty {
            cals = nil // all
        } else {
            cals = store.calendars(for: .event).filter { lower.contains($0.title.lowercased()) }
        }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: cals)
        return store.events(matching: predicate).map { event in
            EventDTO(
                id: event.calendarItemIdentifier,
                calendar: event.calendar.title,
                title: event.title ?? "",
                location: event.location,
                notes: event.notes,
                isAllDay: event.isAllDay,
                start: toSec(event.startDate),
                end: toSec(event.endDate),
                startFormatted: formatDate(event.startDate, tz: TimeZone.current, locale: Locale.current),
                endFormatted: formatDate(event.endDate, tz: TimeZone.current, locale: Locale.current),
                url: event.url?.absoluteString,
                attendees: event.attendees?.compactMap { $0.name }
            )
        }.sorted { $0.start < $1.start }
    }
    
    /// Fetch events from specified time range (with timezone and locale specification)
    func fetchEvents(from: Date, to: Date, tz: TimeZone, calendars filter: [String], locale: Locale) -> [EventDTO] {
        let lower = Set(filter.map { $0.lowercased() })
        let cals: [EKCalendar]?
        if lower.isEmpty {
            cals = nil // all
        } else {
            cals = store.calendars(for: .event).filter { lower.contains($0.title.lowercased()) }
        }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: cals)
        return store.events(matching: predicate).map { event in
            EventDTO(
                id: event.calendarItemIdentifier,
                calendar: event.calendar.title,
                title: event.title ?? "",
                location: event.location,
                notes: event.notes,
                isAllDay: event.isAllDay,
                start: toSec(event.startDate),
                end: toSec(event.endDate),
                startFormatted: formatDate(event.startDate, tz: tz, locale: locale),
                endFormatted: formatDate(event.endDate, tz: tz, locale: locale),
                url: event.url?.absoluteString,
                attendees: event.attendees?.compactMap { $0.name }
            )
        }.sorted { $0.start < $1.start }
    }
}
