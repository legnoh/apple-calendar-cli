import Foundation

// MARK: - Time Parsing Utilities

func toSec(_ date: Date) -> Int64 { 
    Int64(date.timeIntervalSince1970) 
}

func formatDate(_ date: Date, tz: TimeZone, locale: Locale) -> String {
    let f = DateFormatter()
    f.dateFormat = "MM/dd(E) HH:mm"
    f.timeZone = tz
    f.locale = locale
    return f.string(from: date)
}

// Parse relative time specifications: e.g., +3600, -1800, +1h30m, -2d, +3h10m5s, +1d2h, etc.
// Returns: Absolute seconds (since 1970) as TimeInterval. nil on failure.
// Specification: If starts with + or -, it's relative to current time. Allows repetition of number + unit (s,m,h,d).
//               If unit is omitted, treat as seconds. e.g., +300 = +300s.
//               If starts with a digit (or digit without -), interpret as absolute epoch seconds as before.
func parseTimeSpec(_ raw: String) -> TimeInterval? {
    if raw.isEmpty { return nil }

    // Check if it's a relative time spec (starts with + or -)
    if raw.hasPrefix("+") || raw.hasPrefix("-") {
        let isPositive = raw.hasPrefix("+")
        let body = String(raw.dropFirst())
        if body.isEmpty { return nil }
   
        // Check if it contains time units (letters)
        let pattern = #"[a-zA-Z]"#
        if body.range(of: pattern, options: [.regularExpression]) == nil { return nil }

        var totalSeconds: TimeInterval = 0
        var numberBuffer = ""

        for ch in body {
            if ch.isNumber { numberBuffer.append(ch); continue }
            
            guard !numberBuffer.isEmpty else { return nil }
            guard let num = Double(numberBuffer) else { return nil }
            
            switch ch.lowercased() {
            case "s":
                totalSeconds += num
            case "m":
                totalSeconds += num * 60
            case "h":
                totalSeconds += num * 3600
            case "d":
                totalSeconds += num * 86400
            default:
                return nil
            }
            numberBuffer = ""
        }
        
        // If there's leftover number without unit, treat as seconds
        if !numberBuffer.isEmpty {
            guard let num = Double(numberBuffer) else { return nil }
            totalSeconds += num
        }
        
        let offset = isPositive ? totalSeconds : -totalSeconds
        return Date().timeIntervalSince1970 + offset
    } else {
        // Absolute time (epoch seconds)
        if let absVal = TimeInterval(raw) { return absVal }
        return nil
    }
}
