# mcjs
macOS Calendar JSON API Server

macOSのカレンダー.app (EventKit) から予定を取得し、JSON APIとして配信するサーバーです。  
GrafanaのJSON APIデータソースとの連携や、カレンダーデータの可視化に最適です。

## ✨ 特徴

- 🗓️ **設定ベースのカレンダーフィルタリング** - YAMLファイルで対象カレンダーを指定
- ⏰ **タイムゾーン対応** - 設定可能なタイムゾーンでの時刻表示
- 🚫 **スマートフィルタリング** - 全日イベント除外、長期イベントの3時間表示制限
- 📊 **Grafana連携** - JSON APIプラグインに最適化されたエンドポイント
- 🔧 **VS Code統合** - 完全なデバッグ・タスク設定同梱

---

## 🛠️ セットアップ

### 1. 要件
- macOS 13.0以降
- Xcode Command Line Tools (Swift 5.9)
- カレンダーへのアクセス権限

### 2. インストール
```bash
git clone https://github.com/legnoh/mcj.git
cd mcj
swift build
```

### 3. 設定ファイル作成
```bash
mkdir -p ~/.mcjs
cat > ~/.mcjs/config.yaml << 'EOF'
calendars:
  - "カレンダー"
  - "仕事"
  - "プライベート"
timezone: "Asia/Tokyo"
EOF
```

### 4. サーバー起動
```bash
# Terminal.appで起動（推奨 - カレンダーアクセス権限のため）
./launch_terminal.sh

# または直接起動
swift run mcjs
```

---

## 📡 API エンドポイント

### `/upcoming`
直近5件のイベント（全日イベント除外、長期イベント3時間制限適用）
```bash
curl http://localhost:8620/upcoming | jq
```

### `/events`
期間とカレンダーを指定してイベント取得
```bash
# 直近1週間のイベント
FROM=$(($(date +%s) * 1000))
TO=$((($(date +%s) + 7*24*3600) * 1000))
curl "http://localhost:8620/events?from=$FROM&to=$TO" | jq

# 特定カレンダーのみ
curl "http://localhost:8620/events?from=$FROM&to=$TO&calendars=仕事,プライベート" | jq
```

### `/calendars`
利用可能なカレンダー一覧
```bash
curl http://localhost:8620/calendars | jq
```

### `/healthz`
ヘルスチェック
```bash
curl http://localhost:8620/healthz | jq
```

## 📊 レスポンス形式

### EventDTO
```json
{
  "id": "event-id",
  "calendar": "カレンダー",
  "title": "会議",
  "location": "会議室A",
  "notes": "議事録を準備",
  "isAllDay": false,
  "start": 1633507200000,
  "end": 1633510800000,
  "startFormatted": "10/06(水) 14:00",
  "endFormatted": "10/06(水) 15:00",
  "url": "https://example.com/meeting",
  "attendees": ["田中太郎", "佐藤花子"]
}
```

---

## 🎯 Grafana連携

### データソース設定
- **Type**: JSON API
- **URL**: `http://localhost:8620`

### パネル設定例

#### 1. 今後の予定表示
- **Query**: `/upcoming`
- **Visualization**: Table
- **Columns**: `title`, `calendar`, `startFormatted`, `endFormatted`, `location`

#### 2. 期間指定イベント表示
- **Query**: `/events?from=$__from&to=$__to`
- **Time Range**: Grafana時間範囲使用
- **Visualization**: Table / Timeline

---

## ⚙️ 設定

### 環境変数
```bash
HOST=127.0.0.1    # バインドアドレス（デフォルト: 127.0.0.1）
PORT=8620         # ポート番号（デフォルト: 8620）
CORS_ORIGIN=*     # CORS設定（デフォルト: 全てのオリジンを許可）
```

### 設定ファイル（~/.mcjs/config.yaml）
```yaml
calendars:          # 対象カレンダー名のリスト
  - "カレンダー"     # 設定したカレンダーのみが対象となる
  - "仕事"          # 設定がない場合は全カレンダーが対象
  - "プライベート"
timezone: "Asia/Tokyo"  # タイムゾーン（デフォルト: システムのタイムゾーン）
```

### フィルタリング機能

#### 全日イベント除外（/upcomingのみ）
全日イベントは`/upcoming`エンドポイントから除外されます。

#### 長期イベント制限
1日以上続くイベントは、開始から3時間経過後に表示されなくなります。
- 例：3日間の会議 → 開始から3時間後に非表示
- 例：30分の打ち合わせ → 常に表示（1日未満のため）

---

## 🔧 開発環境

### VS Code統合
```bash
# タスク実行
Cmd+Shift+P → "Tasks: Run Task"
- Build
- Run
- Build Release

# デバッグ実行
F5 または "Run and Debug" → "🚀 Launch in Terminal"
```

### 手動ビルド・実行
```bash
# デバッグビルド
swift build

# リリースビルド
swift build -c release

# 直接実行
swift run mcjs

# Terminal.app起動（推奨）
./launch_terminal.sh
```

---

## 🚀 GitHub Releases

### 自動リリース
```bash
# タグ作成でリリース
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actionsが自動でUniversal Binary（Intel + Apple Silicon）をビルド・リリースします。

### 手動リリース
GitHubの「Actions」タブから「Release」ワークフローを手動実行可能です。

---

## ❓ トラブルシューティング

### カレンダーアクセス権限
```bash
# 権限リセット
tccutil reset Calendar

# システム設定で手動許可
# System Settings > Privacy & Security > Calendar
```

### コード署名（必要に応じて）
```bash
codesign -s - --force .build/debug/mcjs
```

### ネットワーク接続確認
```bash
# サーバー起動確認
curl http://localhost:8620/healthz

# ポート使用状況
lsof -i :8620
```

---

## 📄 ライセンス
MIT License - [LICENSE](LICENSE) ファイルを参照
