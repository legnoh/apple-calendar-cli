import Vapor
@preconcurrency import EventKit
import Yams
import Foundation

struct EventDTO: Content {
    let id: String
    let calendar: String
    let title: String
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let start: Int64   // epoch ms
    let end: Int64     // epoch ms
    let startFormatted: String // MM/DD HH:mm format
    let endFormatted: String   // MM/DD HH:mm format
    let url: String?
    let attendees: [String]?
}

struct CalendarDTO: Content {
    let id: String
    let title: String
}

struct Config: Codable {
    let calendars: [String]
    let timezone: String?
    
    var timeZone: TimeZone {
        if let tz = timezone, let timeZone = TimeZone(identifier: tz) {
            return timeZone
        }
        return TimeZone.current
    }
    
    static func load() -> Config? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configPath = homeDir.appendingPathComponent(".mcjs/config.yaml")
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            print("⚠️  Config file not found at: \(configPath.path)")
            print("   Create ~/.mcjs/config.yaml with:")
            print("   calendars:")
            print("     - \"Calendar Name 1\"")
            print("     - \"Calendar Name 2\"")
            return nil
        }
        
        do {
            let configData = try Data(contentsOf: configPath)
            let configString = String(data: configData, encoding: .utf8) ?? ""
            let config = try YAMLDecoder().decode(Config.self, from: configString)
            print("✅ Loaded config from: \(configPath.path)")
            print("🗓️ Target calendars: \(config.calendars)")
            return config
        } catch {
            print("❌ Failed to load config: \(error)")
            return nil
        }
    }
}

func toMs(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }

func formatDate(_ date: Date, timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM/dd(E) HH:mm"
    formatter.timeZone = timeZone
    formatter.locale = Locale(identifier: "ja_JP")
    return formatter.string(from: date)
}

final class EventStoreService: LifecycleHandler, @unchecked Sendable {
    private let store = EKEventStore()
    private(set) var granted = false
    private let targetCalendars: [String]?
    private let timeZone: TimeZone

    init(targetCalendars: [String]?, timeZone: TimeZone) {
        self.targetCalendars = targetCalendars
        self.timeZone = timeZone
    }

    func willBoot(_ app: Application) throws {
        // アクセス権限はmain()で既に確認済み
        granted = true
    }

    func calendars() -> [CalendarDTO] {
        store.calendars(for: .event).map { CalendarDTO(id: $0.calendarIdentifier, title: $0.title) }
    }

    func fetch(from: Date, to: Date, calendarNames: [String]? = nil) -> [EventDTO] {
        let calendars: [EKCalendar]?
        
        // 優先順位: 1. 引数で指定されたカレンダー, 2. 設定ファイルのカレンダー, 3. 全てのカレンダー
        let targetNames: [String]?
        if let names = calendarNames, !names.isEmpty {
            targetNames = names
        } else if let configNames = targetCalendars, !configNames.isEmpty {
            targetNames = configNames
        } else {
            targetNames = nil
        }
        
        if let names = targetNames {
            let set = Set(names.map { $0.lowercased() })
            calendars = store.calendars(for: .event).filter { set.contains($0.title.lowercased()) }
        } else {
            calendars = nil // all
        }

        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: calendars)
        let events = store.events(matching: predicate)

        return events.map { ev in
            EventDTO(
                id: ev.eventIdentifier,
                calendar: ev.calendar.title,
                title: ev.title ?? "(no title)",
                location: ev.location,
                notes: ev.notes,
                isAllDay: ev.isAllDay,
                start: toMs(ev.startDate),
                end: toMs(ev.endDate),
                startFormatted: formatDate(ev.startDate, timeZone: timeZone),
                endFormatted: formatDate(ev.endDate, timeZone: timeZone),
                url: ev.url?.absoluteString,
                attendees: ev.attendees?.compactMap { $0.name }
            )
        }.sorted { $0.start < $1.start }
    }
}

@main
enum AppMain {
    static func main() async throws {
        // 設定ファイルを読み込み
        let config = Config.load()
        
        // まず、カレンダーアクセス権限を確認
        let store = EKEventStore()
        
        let hasAccess = await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        
        guard hasAccess else {
            print("❌ Calendar access not granted")
            print("")
            print("To grant calendar access:")
            print("1. Open System Settings > Privacy & Security > Calendar")
            print("2. Find 'mcjs' or 'swift' and enable it")
            print("3. If not listed, try running: tccutil reset Calendar")
            print("4. Then run this application again")
            print("")
            print("Alternative: Run from Xcode or as a signed application bundle")
            return
        }
        
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = try await Application.make(env)
        // Use async shutdown in Swift 6

        // CORS (Grafana JSON API Pluginからのアクセスを許可)
        let corsConfig: CORSMiddleware.Configuration
        if let origin = Environment.get("CORS_ORIGIN"), origin != "*" {
            corsConfig = CORSMiddleware.Configuration(
                allowedOrigin: .custom(origin),
                allowedMethods: [.GET, .OPTIONS],
                allowedHeaders: [.accept, .contentType, .origin, .xRequestedWith, .userAgent]
            )
            app.logger.notice("CORS custom origin (set CORS_ORIGIN=\(origin))")
        } else {
            corsConfig = CORSMiddleware.Configuration(
                allowedOrigin: .all,
                allowedMethods: [.GET, .OPTIONS],
                allowedHeaders: [.accept, .contentType, .origin, .xRequestedWith, .userAgent]
            )
        }
        app.middleware.use(CORSMiddleware(configuration: corsConfig))
        app.middleware.use(ErrorMiddleware.default(environment: env))

        // Bind先
        app.http.server.configuration.hostname = Environment.get("HOST") ?? "127.0.0.1"
        app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8620

        let service = EventStoreService(targetCalendars: config?.calendars, timeZone: config?.timeZone ?? .current)
        app.lifecycle.use(service)

        struct Query: Decodable {
            // Grafanaの $__from / $__to （ms）をそのまま受け取る
            let from: Int64
            let to: Int64
            // "Work,Personal" のようにカンマ区切り
            let calendars: String?
        }

        // List calendars
        app.get("calendars") { _ -> [CalendarDTO] in
            return service.calendars()
        }

        // Events (with query parameters)
        app.get("events") { req -> [EventDTO] in
            let q = try req.query.decode(Query.self)
            guard q.from < q.to else { throw Abort(.badRequest, reason: "'from' must be less than 'to'") }
            let from = Date(timeIntervalSince1970: TimeInterval(q.from) / 1000)
            let to   = Date(timeIntervalSince1970: TimeInterval(q.to) / 1000)
            let names = q.calendars?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return service.fetch(from: from, to: to, calendarNames: names)
        }

        // Fixed URL for Grafana - upcoming 5 events (excluding all-day events)
        app.get("upcoming") { _ -> [EventDTO] in
            let now = Date()
            // 直近5個のイベントを確実に取得するため、より長い期間で検索
            let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? Date()
            let events = service.fetch(from: now, to: futureDate)
            
            let filteredEvents = events.filter { event in
                // 全日イベントを除外
                guard !event.isAllDay else { return false }
                
                // イベントの期間を計算（ミリ秒 -> 秒）
                let startDate = Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
                let endDate = Date(timeIntervalSince1970: TimeInterval(event.end) / 1000)
                let duration = endDate.timeIntervalSince(startDate)
                
                // 1日以上のイベントかチェック（86400秒 = 24時間）
                if duration >= 86400 {
                    // 開始から3時間経過したかチェック（10800秒 = 3時間）
                    let threeHoursAfterStart = startDate.addingTimeInterval(10800)
                    return now < threeHoursAfterStart
                }
                
                // 1日未満のイベントはそのまま表示
                return true
            }
            
            // 直近5個までのイベントを返す
            return Array(filteredEvents.prefix(5))
        }

        app.get("healthz") { _ in ["ok": true] }
        try await app.execute()
    }
}
