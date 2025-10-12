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
```bash
git clone https://github.com/legnoh/apple-calendar-cli.git
cd apple-calendar-cli  # (repository rename pending if desired)
swift build
```

### 3. Configuration
No external config files. All calendars are queried in the system timezone.

### 4. Examples
```bash
# Default (now → +30d, limit 5, human-readable text)
swift run apple-calendar

# JSON output (same data as text mode)
swift run apple-calendar --format json | jq

# Custom range (absolute epoch seconds)
NOW_S=$(date +%s)
NEXT_DAY_S=$((NOW_S + 24*3600))
swift run apple-calendar --from $NOW_S --to $NEXT_DAY_S --limit 20 --pretty

# Relative range examples
swift run apple-calendar --from +0 --to +1d --limit 20
swift run apple-calendar --from -1h --to +2h --format json
swift run apple-calendar --from +0 --to +90m --exclude-all-day
swift run apple-calendar --from +0 --to +1d2h30m --pretty

# Exclude all-day events
swift run apple-calendar --exclude-all-day

# Hide long (>=24h) events after 3h
swift run apple-calendar --exclude-long-event

# Filter calendars (comma separated, case-insensitive)
swift run apple-calendar --calendars "Work,Private"
```

### 5. Help
```bash
swift run apple-calendar --help
```

---

## 🔄 Processing Flow
1. Query EventKit for range (`--from/--to`; defaults: now → now+30d)
2. If `--calendars` provided, filter to those calendar titles (case-insensitive)
3. Apply exclusions: `--exclude-all-day`, `--exclude-long-event`
4. Apply limit (`--limit`, 0 = unlimited)
5. Encode as JSON (if `--format json`) or render text lines → stdout

## 📊 Output JSON (EventDTO)
```json
{
  "id": "event-id",
  "calendar": "Work",
  "title": "Team Meeting",
  "location": "Room A",
  "notes": "Prepare agenda",
  "isAllDay": false,
  "start": 1633507200000,
  "end": 1633510800000,
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
| Range | now → +30d | `--from / --to` (epoch seconds or relative spec e.g. +1h30m, -2d) |

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

## 🚀 GitHub Releases

### Automatic release
```bash
# Tag & push to release
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions builds and publishes a Universal Binary (Intel + Apple Silicon).

### Manual release
Trigger the Release workflow from the Actions tab if needed.

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

---

## 📄 License
MIT License - see [LICENSE](LICENSE)
