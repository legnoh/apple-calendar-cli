import Foundation

// MARK: - List Calendars Command

struct ListCalendarsOptions {
    var format: OutputFormat = .text
    var pretty = false
}

func printListCalendarsUsageAndExit(exitCode: Int32 = 0) -> Never {
    print(
        """
        apple-calendar list-calendars - List available calendars

        Usage: apple-calendar list-calendars [options]

        Description:
          Lists all available calendars with their color, source, and account type.

        Options:
          --format <text|json>     Output format (default: text)
          --pretty                 Pretty-print JSON (only if --format json)
          -h, --help               Show this help

        Examples:
          apple-calendar list-calendars
          apple-calendar list-calendars --format json
          apple-calendar list-calendars --format json --pretty
        """)
    exit(exitCode)
}

func parseListCalendarsArgs(args: [String]) -> ListCalendarsOptions {
    var opts = ListCalendarsOptions()
    
    // Parse common options first
    let (remainingArgs, commonOpts, _) = parseCommonOptions(args) {
        printListCalendarsUsageAndExit()
    }
    
    // Apply common options
    opts.format = commonOpts.format
    opts.pretty = commonOpts.pretty

    // Parse command-specific options (none for list-calendars currently)
    let normalized = normalizeArguments(remainingArgs)
    var it = normalized.makeIterator()
    
    while let arg = it.next() {
        switch arg {
        default:
            FileHandle.standardError.write(Data("Unknown option: \(arg)\n".utf8))
            printListCalendarsUsageAndExit(exitCode: 1)
        }
    }
    return opts
}

func runListCalendars(options: ListCalendarsOptions) async {
    let client = EventKitClient()
    let granted = await client.requestAccess()
    guard granted else {
        FileHandle.standardError.write(Data("Calendar access not granted.\n".utf8))
        exit(1)
    }

    let calendars = client.fetchCalendars()

    switch options.format {
    case .json:
        let encoder = JSONEncoder()
        if options.pretty { 
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys] 
        }
        do {
            let data = try encoder.encode(calendars)
            FileHandle.standardOutput.write(data)
            if options.pretty { 
                FileHandle.standardOutput.write(Data("\n".utf8)) 
            }
        } catch {
            FileHandle.standardError.write(Data("Failed to encode JSON: \(error)\n".utf8))
            exit(1)
        }
    case .text:
        for calendar in calendars {
            print("\(calendar.title) | \(calendar.colorHex) | \(calendar.source) (\(calendar.sourceType))")
        }
    }
}
