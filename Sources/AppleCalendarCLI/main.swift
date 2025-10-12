import Foundation
import EventKit

// MARK: - Main Flow

enum Command {
    case listEvents(ListEventsOptions)
    case listCalendars(ListCalendarsOptions)
    case version
    case help
}

enum OutputFormat: String {
    case text, json
}

enum BuildInfo {
    static let version = "dev"
}

func printMainUsageAndExit(exitCode: Int32 = 0) -> Never {
    print(
        """
        apple-calendar-cli - macOS Calendar JSON extractor

        Usage: apple-calendar <command> [options]

        Commands:
          list-events              List calendar events
          list-calendars           List available calendars

        Global Options:
          -V, --version            Show version and exit
          -h, --help               Show this help

        Run 'apple-calendar-cli <command> --help' for command-specific options.
        """)
    exit(exitCode)
}

func main() async {
    let command = parseCommand()
    
    switch command {
        case .version:
            print("apple-calendar-cli version \(BuildInfo.version)")
            exit(0)
        case .help:
            printMainUsageAndExit()
        case .listEvents(let options):
            await runListEvents(options: options)
        case .listCalendars(let options):
            await runListCalendars(options: options)
        }
}

// Start the program
await main()
