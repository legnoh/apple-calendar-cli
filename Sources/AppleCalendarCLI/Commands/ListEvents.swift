import Foundation

// MARK: - List Events Command

struct ListEventsOptions {
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

func printListEventsUsageAndExit(exitCode: Int32 = 0) -> Never {
  print(
    """
    apple-calendar list-events - List calendar events

    Usage: apple-calendar list-events [options]

    Options:
      --from <spec>            Start time. Epoch seconds or relative (+1h30m, -2d, +3600). Default: now
      --to <spec>              End time. Epoch seconds or relative. Default: now + 30d
      --limit <n>              Limit number of events (default 5, 0 = no limit)
      --exclude-all-day        Exclude all-day events (default: include)
      --exclude-long-event     Hide long (>=24h) events after 3h from start (default: keep)
      --calendars <list>       Comma separated calendar names to include (case-insensitive)
      --format <text|json>     Output format (default: text)
      --pretty                 Pretty-print JSON (only if --format json)
      --locale <id>            Locale identifier (default: system). Example: ja_JP, en_US, fr_FR
      -h, --help               Show this help

    Examples:
      apple-calendar list-events --to +7d --limit 0
      apple-calendar list-events --format json --pretty
      apple-calendar list-events --calendars "Work,Personal" --exclude-all-day
    """)
  exit(exitCode)
}

func parseListEventsArgs(args: [String]) -> ListEventsOptions {
    var opts = ListEventsOptions(
        from: Date(),
        to: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    )

    // Parse common options first
    let (remainingArgs, commonOpts, _) = parseCommonOptions(args) {
        printListEventsUsageAndExit()
    }
    
    // Apply common options
    opts.format = commonOpts.format
    opts.pretty = commonOpts.pretty

    // Parse command-specific options
    let normalized = normalizeArguments(remainingArgs)
    var it = normalized.makeIterator()
    
    while let arg = it.next() {
        switch arg {
        case "--from":
            if let v = it.next(), let sec = parseTimeSpec(v) {
                opts.from = Date(timeIntervalSince1970: sec)
            }
        case "--to":
            if let v = it.next(), let sec = parseTimeSpec(v) {
                opts.to = Date(timeIntervalSince1970: sec)
            }
        case "--limit": if let v = it.next(), let l = Int(v) { opts.limit = l }
        case "--exclude-all-day": opts.excludeAllDay = true
        case "--exclude-long-event": opts.excludeLongEvent = true
        case "--calendars":
            if let v = it.next() {
                opts.calendars = v.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            } else {
                FileHandle.standardError.write(Data("--calendars requires a comma separated value list\n".utf8))
                printListEventsUsageAndExit(exitCode: 1)
            }
        case "--locale":
            if let v = it.next() {
                // Input examples: en_US, ja_JP, fr_FR, de, zh-Hans
                let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    FileHandle.standardError.write(Data("--locale requires a non-empty identifier\n".utf8))
                    printListEventsUsageAndExit(exitCode: 1)
                }
                opts.locale = Locale(identifier: trimmed)
            } else {
                FileHandle.standardError.write(Data("--locale requires a value (e.g. ja_JP)\n".utf8))
                printListEventsUsageAndExit(exitCode: 1)
            }
        default:
            FileHandle.standardError.write(Data("Unknown option: \(arg)\n".utf8))
            printListEventsUsageAndExit(exitCode: 1)
        }
    }
    return opts
}

func runListEvents(options: ListEventsOptions) async {
    let tz = TimeZone.current
    let client = EventKitClient()

    let granted = await client.requestAccess()
    guard granted else {
        FileHandle.standardError.write(Data("Calendar access not granted.\n".utf8))
        exit(1)
    }

    var events = client.fetchEvents(from: options.from,
                                   to: options.to,
                                   tz: tz,
                                   calendars: options.calendars,
                                   locale: options.locale)

    // Filters
    if options.excludeAllDay { events.removeAll { $0.isAllDay } }
    if options.excludeLongEvent {
        let now = Date()
        events.removeAll { e in
            let duration = TimeInterval(e.end - e.start)
            if duration >= 86400 { // long event
                let start = Date(timeIntervalSince1970: TimeInterval(e.start))
                return now >= start.addingTimeInterval(10800) // hide after 3h
            }
            return false
        }
    }
    if options.limit > 0 {
        let originalCount = events.count
        if originalCount > options.limit {
            events = Array(events.prefix(options.limit))
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
        // Omit ID and sort by start time ascending. Keep width control simple.
        let df = DateFormatter()
        df.dateFormat = "MM/dd(E) HH:mm"
        df.timeZone = tz
        df.locale = options.locale
        // Formatter for same-day event end times (time only)
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        tf.timeZone = tz
        tf.locale = options.locale
        let cal = Calendar.current
        for e in events {
            let start = Date(timeIntervalSince1970: TimeInterval(e.start))
            let end = Date(timeIntervalSince1970: TimeInterval(e.end))
            let endStr: String
            if cal.isDate(start, inSameDayAs: end) { // Same day completion
                // If start and end are on same day, show time only for end
                endStr = tf.string(from: end)
            } else {
                endStr = df.string(from: end)
            }
            // Output format: MM/dd(E) HH:mm - HH:mm | Title (Calendar)[AllDay]
            let calSuffix = " (\(e.calendar))"
            let line = "\(df.string(from: start))-\(endStr) | \(e.title)\(calSuffix)\(e.isAllDay ? " [AllDay]" : "")"
            FileHandle.standardOutput.write(Data(line.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }
}
