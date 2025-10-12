import Foundation
import EventKit

// MARK: - Models
struct EventDTO: Codable {
    let id: String
    let calendar: String
    let title: String
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let start: Int64   // epoch ms
    let end: Int64     // epoch ms
    let startFormatted: String
    let endFormatted: String
    let url: String?
    let attendees: [String]?
}

// MARK: - Helpers
func toMs(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }

func formatDate(_ date: Date, tz: TimeZone, locale: Locale) -> String {
    let f = DateFormatter()
    f.dateFormat = "MM/dd(E) HH:mm"
    f.timeZone = tz
    f.locale = locale
    return f.string(from: date)
}

enum OutputFormat: String { case text, json }

struct CLIOptions {
    var from: Date
    var to: Date
    var limit: Int = 5
    // Filters (default: include all events)
    var excludeAllDay = false            // if true, remove all-day events
    var excludeLongEvent = false         // if true, hide long (>=24h) events after 3h
    var pretty = false                   // only meaningful for json
    var calendars: [String] = [] // case-insensitive match
    var format: OutputFormat = .text
    var locale: Locale = .autoupdatingCurrent
}

// 相対時間指定をパース: 例 +3600, -1800, +1h30m, -2d, +3h10m5s, +1d2h, など。
// 返り値: 絶対秒 (since 1970) を TimeInterval で返す。失敗時は nil。
// 仕様: 先頭が + または - の場合は現在時刻を基準とした相対。数値部分 + 単位 (s,m,h,d) の繰り返しを許可。
//       単位省略時は秒扱い。例 +300 = +300s。
//       先頭が数字 (または - なし数字) の場合は従来通り絶対 epoch 秒として解釈。
func parseTimeSpec(_ raw: String, now: TimeInterval = Date().timeIntervalSince1970) -> TimeInterval? {
    if raw.isEmpty { return nil }
    let first = raw.first!
    if first == "+" || first == "-" {
        let sign: Double = first == "+" ? 1 : -1
        let body = String(raw.dropFirst())
        if body.isEmpty { return nil }
        // トークン化: 数値+任意単位 の連続。正規表現: (\d+)([smhd]?)
        let pattern = "^(?:\\d+[smhd]?)+$"
        if body.range(of: pattern, options: [.regularExpression]) == nil { return nil }
        var total: Double = 0
        var numberBuffer = ""
        for ch in body { // 1 2 h 3 0 m ...
            if ch.isNumber { numberBuffer.append(ch); continue }
            // 単位
            guard !numberBuffer.isEmpty else { return nil }
            let val = Double(numberBuffer) ?? 0
            let mult: Double
            switch ch {
            case "s": mult = 1
            case "m": mult = 60
            case "h": mult = 3600
            case "d": mult = 86400
            default: return nil
            }
            total += val * mult
            numberBuffer.removeAll(keepingCapacity: true)
        }
        if !numberBuffer.isEmpty { // 単位省略 → 秒
            total += Double(numberBuffer) ?? 0
        }
        return now + sign * total
    } else {
        // 絶対秒
        if let absVal = TimeInterval(raw) { return absVal }
        return nil
    }
}

func parseArgs() -> CLIOptions {
    var opts = CLIOptions(
        from: Date(),
        to: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    )

    // 引数を一旦配列に展開し、--flag=value 形式を --flag value に正規化
    var normalized: [String] = []
    for raw in CommandLine.arguments.dropFirst() { // drop executable name
        if raw.hasPrefix("--"), let eq = raw.firstIndex(of: "=") {
            let flag = String(raw[..<eq])
            let value = String(raw[raw.index(after: eq)...])
            if !value.isEmpty {
                normalized.append(flag)
                normalized.append(value)
            } else {
                normalized.append(flag) // 空値は後段で通常の次引数不足として扱う
            }
        } else {
            normalized.append(raw)
        }
    }

    let nowSec = Date().timeIntervalSince1970
    var it = normalized.makeIterator()
    while let arg = it.next() {
        switch arg {
        case "--from":
            if let v = it.next(), let sec = parseTimeSpec(v, now: nowSec) {
                opts.from = Date(timeIntervalSince1970: sec)
            }
        case "--to":
            if let v = it.next(), let sec = parseTimeSpec(v, now: nowSec) {
                opts.to = Date(timeIntervalSince1970: sec)
            }
        case "--limit": if let v = it.next(), let l = Int(v) { opts.limit = l }
        case "--exclude-all-day": opts.excludeAllDay = true
        case "--exclude-long-event": opts.excludeLongEvent = true
        case "--pretty": opts.pretty = true
        case "--format":
            if let v = it.next(), let f = OutputFormat(rawValue: v.lowercased()) {
                opts.format = f
            } else {
                FileHandle.standardError.write(Data("--format requires one of: text,json\n".utf8))
                printUsageAndExit(exitCode: 1)
            }
        case "--calendars":
            if let v = it.next() {
                opts.calendars = v.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            } else {
                FileHandle.standardError.write(Data("--calendars requires a comma separated value list\n".utf8))
                printUsageAndExit(exitCode: 1)
            }
        case "--locale":
            if let v = it.next() {
                // 入力例: en_US, ja_JP, fr_FR, de, zh-Hans
                let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    FileHandle.standardError.write(Data("--locale requires a non-empty identifier\n".utf8))
                    printUsageAndExit(exitCode: 1)
                }
                opts.locale = Locale(identifier: trimmed)
            } else {
                FileHandle.standardError.write(Data("--locale requires a value (e.g. ja_JP)\n".utf8))
                printUsageAndExit(exitCode: 1)
            }
        case "--help", "-h":
            printUsageAndExit()
        default:
            FileHandle.standardError.write(Data("Unknown option: \(arg)\n".utf8))
            printUsageAndExit(exitCode: 1)
        }
    }
    return opts
}

func printUsageAndExit(exitCode: Int32 = 0) -> Never {
    print("""
apple-calendar-cli - macOS Calendar JSON extractor (one-shot)

Usage: apple-calendar-cli [options]

Options:
  --from <spec>            Start time. Epoch seconds or relative (+1h30m, -2d, +3600). Default: now
  --to <spec>              End time. Epoch seconds or relative. Default: now + 30d
  --limit <n>              Limit number of events (default 5, 0 = no limit) (also --limit=10)
  --exclude-all-day        Exclude all-day events (default: include)
  --exclude-long-event     Hide long (>=24h) events after 3h from start (default: keep)
  --calendars list         Comma separated calendar names to include (case-insensitive) (also --calendars=A,B)
  --format <text|json>     Output format (default: text) (also --format=json)
  --pretty                 Pretty-print JSON (only if --format json)
  --locale <id>            Locale identifier (default: system). Example: ja_JP, en_US, fr_FR
  -h, --help               Show this help
""")
    exit(exitCode)
}

// MARK: - Calendar Fetch
func fetchEvents(store: EKEventStore, from: Date, to: Date, tz: TimeZone, calendars filter: [String], locale: Locale) -> [EventDTO] {
    let lower = Set(filter.map { $0.lowercased() })
    let cals: [EKCalendar]?
    if lower.isEmpty {
        cals = nil // all
    } else {
        cals = store.calendars(for: .event).filter { lower.contains($0.title.lowercased()) }
    }
    let predicate = store.predicateForEvents(withStart: from, end: to, calendars: cals)
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
            startFormatted: formatDate(ev.startDate, tz: tz, locale: locale),
            endFormatted: formatDate(ev.endDate, tz: tz, locale: locale),
            url: ev.url?.absoluteString,
            attendees: ev.attendees?.compactMap { $0.name }
        )
    }.sorted { $0.start < $1.start }
}

// MARK: - Main Flow
@main
enum Run {
    static func main() async {
    let options = parseArgs()
        let tz = TimeZone.current

        let store = EKEventStore()
        let granted = await withCheckedContinuation { cont in
            store.requestAccess(to: .event) { ok, _ in cont.resume(returning: ok) }
        }
        guard granted else {
            FileHandle.standardError.write(Data("Calendar access not granted.\n".utf8))
            exit(1)
        }

    var events = fetchEvents(store: store,
                 from: options.from,
                 to: options.to,
                 tz: tz,
                 calendars: options.calendars,
                 locale: options.locale)

        // Filters
        if options.excludeAllDay { events.removeAll { $0.isAllDay } }
        if options.excludeLongEvent {
            let now = Date()
            events.removeAll { e in
                let duration = TimeInterval(e.end - e.start) / 1000
                if duration >= 86400 { // long event
                    let start = Date(timeIntervalSince1970: TimeInterval(e.start)/1000)
                    return now >= start.addingTimeInterval(10800) // hide after 3h
                }
                return false
            }
        }
        if options.limit > 0 {
            let originalCount = events.count
            if originalCount > options.limit {
                events = Array(events.prefix(options.limit))
                let truncated = originalCount - events.count
                FileHandle.standardError.write(Data("[info] truncated \(truncated) events (showing first \(events.count)); use --limit 0 to show all within range\n".utf8))
            }
        }

        switch options.format {
        case .json:
            let encoder = JSONEncoder()
            if options.pretty { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
            do {
                let data = try encoder.encode(events)
                FileHandle.standardOutput.write(data)
                if options.pretty { FileHandle.standardOutput.write(Data("\n".utf8)) }
            } catch {
                FileHandle.standardError.write(Data("Failed to encode JSON: \(error)\n".utf8))
                exit(1)
            }
        case .text:
            // Simple human-readable table-ish output
            // IDは省略し開始時刻昇順。最大幅制御はシンプルに。
            let df = DateFormatter()
            df.dateFormat = "MM/dd(E) HH:mm"
            df.timeZone = tz
            df.locale = options.locale
            // 同日イベント終了時刻の日付省略用フォーマッタ (時刻のみ)
            let tf = DateFormatter()
            tf.dateFormat = "HH:mm"
            tf.timeZone = tz
            tf.locale = options.locale
            let cal = Calendar.current
            for e in events {
                let start = Date(timeIntervalSince1970: TimeInterval(e.start)/1000)
                let end = Date(timeIntervalSince1970: TimeInterval(e.end)/1000)
                let endStr: String
                if cal.isDate(start, inSameDayAs: end) { // 同日内完結
                    // 開始と終了が同日なら終了側は時刻のみ
                    endStr = tf.string(from: end)
                } else {
                    endStr = df.string(from: end)
                }
                // 出力形式:  MM/dd(E) HH:mm - HH:mm | Title (Calendar)[AllDay]
                let calSuffix = " (\(e.calendar))"
                let line = "\(df.string(from: start))-\(endStr) | \(e.title)\(calSuffix)\(e.isAllDay ? " [AllDay]" : "")"
                FileHandle.standardOutput.write(Data(line.utf8))
                FileHandle.standardOutput.write(Data("\n".utf8))
            }
        }
    }
}
