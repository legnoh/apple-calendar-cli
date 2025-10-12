# apple-calendar-cli

Calendar CLI for macOS

## ✨ Features

- 🗓️ **Calendar filtering** (`--calendars Work,Private`)
- ⏰ **Readable time strings** (`startFormatted` / `endFormatted` in system timezone)
- 🚫 **Filters (opt-in exclusions)**: All-day events & long events (>=24h) are included by default; exclude via flags
- 🎯 **Result limiting**: Default window is now → +30 days, returning up to 5 events (`--limit`)
- 🧪 **Pure CLI**: No server. Human-readable text by default, JSON via `--format json` (logs/errors to stderr)
- 🛠️ **Flexible options**: Range, limit, pretty-print, calendar selection, selective exclusions

---

## 🛠️ Setup

### 1. Requirements

- macOS 13.0+
- Xcode Command Line Tools (Swift 5.9 or later)
- Calendar (EventKit) permission granted

### 2. Install

#### (A) Homebrew (recommended)
Tap + install:
```bash
brew tap legnoh/etc
brew install apple-calendar-cli
```
Upgrade later:
```bash
brew update
brew upgrade apple-calendar-cli
```
Verify version:
```bash
apple-calendar --help
```

#### (B) Download release archive
1. Get `apple-calendar-cli-<version>-universal.tar.gz` from GitHub Releases
2. Edit `$PATH` or Execute directly:
  ```bash
  tar -xzf apple-calendar-cli-vX.Y.Z-universal.tar.gz
  ./apple-calendar --help
  ```

#### (C) Build from source
```bash
git clone https://github.com/legnoh/apple-calendar-cli.git
cd apple-calendar-cli
swift build -c release
./.build/release/apple-calendar --help
```

### 3. Configuration
No external config files. All calendars are queried in the system timezone.

### 4. Examples
```bash
# Default (now → +30d, limit 5, human-readable text)
apple-calendar

# JSON output (same data as text mode)
apple-calendar --format json | jq

# Custom range (absolute epoch seconds)
NOW_S=$(date +%s)
NEXT_DAY_S=$((NOW_S + 24*3600))
apple-calendar --from $NOW_S --to $NEXT_DAY_S --limit 20 --pretty

# Relative range examples
apple-calendar --from +0 --to +1d --limit 20
apple-calendar --from -1h --to +2h --format json
apple-calendar --from +0 --to +90m --exclude-all-day
apple-calendar --from +0 --to +1d2h30m --pretty
apple-calendar --to +365d --limit 0  # 1 year ahead, no limit

# Exclude all-day events
apple-calendar --exclude-all-day

# Hide long (>=24h) events after 3h
apple-calendar --exclude-long-event

# Filter calendars (comma separated, case-insensitive)
apple-calendar --calendars "Work,Private"
 
# Override locale (default: system locale)
apple-calendar --locale en_US --to +7d --limit 0
```

### 5. Help
```bash
apple-calendar --help
```

---

## 🔄 Processing Flow
1. Query EventKit for range (`--from/--to`; defaults: now → now+30d)
2. If `--calendars` provided, filter to those calendar titles (case-insensitive)
3. Apply exclusions: `--exclude-all-day`, `--exclude-long-event`
4. Apply limit (`--limit`, 0 = unlimited)
5. Encode as JSON (if `--format json`) or render text lines → stdout
   - Text format pattern: `MM/dd(E) HH:mm - HH:mm | Title (Calendar)[AllDay]`
     - Same-day events: end side date omitted (time only)
     - Cross-day events: both ends show full `MM/dd(E) HH:mm`
     - Calendar name follows title in parentheses
     - `[AllDay]` suffix for all-day events

## 📊 Output JSON (EventDTO)
```json
{
  "id": "event-id",
  "calendar": "Work",
  "title": "Team Meeting",
  "location": "Room A",
  "notes": "Prepare agenda",
  "isAllDay": false,
  "start": 1633507200,
  "end": 1633510800,
  "startFormatted": "10/06(Wed) 14:00",
  "endFormatted": "10/06(Wed) 15:00",
  "url": "https://example.com/meeting",
  "attendees": ["Taro Tanaka", "Hanako Sato"]
}
```

---

## ⚙️ Configuration
Nothing to configure. All calendars, system timezone.

## 🧪 Filtering Summary
| Aspect | Default | Option |
|--------|---------|--------|
| All-day events | Included | `--exclude-all-day` |
| Long events (>=24h) after 3h | Shown | `--exclude-long-event` |
| Calendars | All | `--calendars <a,b,...>` |
| Limit | 5 | `--limit <n>` (0=unlimited) |
| Output format | text | `--format json` or `--format text` |
| Range | now → +30d | `--from / --to` (epoch seconds or relative: +1h30m, -2d, +365d) |
| Locale | System | `--locale <id>` (e.g. ja_JP, en_US) |

---

## 🔧 Development
```bash
swift build
swift run apple-calendar --format json --pretty
```

### Manual build / run
```bash
# Debug build
swift build

# Release build
swift build -c release

# Run
swift run apple-calendar

# (Grant calendar permission when prompted on first run)
```

---

## 🚀 GitHub Releases & Distribution

Official artifacts:
- Universal binary (arm64 + x86_64) – codesigned & notarized
- Homebrew formula: `brew tap legnoh/etc && brew install apple-calendar-cli`

To cut a release (maintainers):
```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```
Workflow auto-generates release notes & updates the Homebrew tap.

---

## ❓ Troubleshooting
### Calendar permission
```bash
tccutil reset Calendar
# System Settings > Privacy & Security > Calendar → allow apple-calendar
```

### Quick check
```bash
swift run apple-calendar --limit 3 --pretty
```

### Missing far-future events (e.g., next April)
1. Increase range: `--to +365d` (or larger)
2. Remove limit: `--limit 0`
3. Watch stderr: if you see `[info] truncated ...` raise or disable limit
4. Remove filters: avoid `--calendars`, `--exclude-all-day`, `--exclude-long-event`
5. Confirm event exists & is synced in the macOS Calendar app

### Truncation notice
When events exceed `--limit`, stderr shows for example:
```
[info] truncated 12 events (showing first 5); use --limit 0 to show all within range
```

---

## 📄 License
MIT License - see [LICENSE](LICENSE)
