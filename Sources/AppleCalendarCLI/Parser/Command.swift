import Foundation

// MARK: - Command Parser

func parseCommand() -> Command {
    let args = Array(CommandLine.arguments.dropFirst())  // drop executable name

    // Check for global options first
    if args.isEmpty {
        return .help
    }

    let firstArg = args[0]
    switch firstArg {
    case "--version", "-V":
        return .version
    case "--help", "-h":
        return .help
    case "list-events":
        return .listEvents(parseListEventsArgs(args: Array(args.dropFirst())))
    case "list-calendars":
        return .listCalendars(parseListCalendarsArgs(args: Array(args.dropFirst())))
    default:
        // Unknown command - show help
        FileHandle.standardError.write(Data("Unknown command: \(firstArg)\n".utf8))
        return .help
    }
}

/// Argument normalization utility
func normalizeArguments(_ args: [String]) -> [String] {
    var normalized: [String] = []
    for raw in args {
        if raw.hasPrefix("--"), let eq = raw.firstIndex(of: "=") {
            let flag = String(raw[..<eq])
            let value = String(raw[raw.index(after: eq)...])
            if !value.isEmpty {
                normalized.append(flag)
                normalized.append(value)
            } else {
                normalized.append(flag) // Empty value will be handled as missing argument error later
            }
        } else {
            normalized.append(raw)
        }
    }
    return normalized
}

// MARK: - Common Option Parsing

/// Common options that appear in multiple commands
struct CommonOptions {
    var format: OutputFormat = .text
    var pretty: Bool = false
}

/// Parse common options that appear across multiple commands
/// Returns (remainingArgs, commonOptions, shouldShowHelp)
func parseCommonOptions(
    _ args: [String],
    helpHandler: () -> Never
) -> (remainingArgs: [String], commonOptions: CommonOptions, shouldShowHelp: Bool) {
    
    var remainingArgs: [String] = []
    var commonOpts = CommonOptions()
    
    let normalized = normalizeArguments(args)
    var it = normalized.makeIterator()
    
    while let arg = it.next() {
        switch arg {
        case "--help", "-h":
            helpHandler()
        case "--format":
            if let v = it.next(), let f = OutputFormat(rawValue: v.lowercased()) {
                commonOpts.format = f
            } else {
                FileHandle.standardError.write(Data("--format requires one of: text,json\n".utf8))
                helpHandler()
            }
        case "--pretty":
            commonOpts.pretty = true
        default:
            // This option should be handled by command-specific parser
            remainingArgs.append(arg)
        }
    }
    
    return (remainingArgs, commonOpts, false)
}
