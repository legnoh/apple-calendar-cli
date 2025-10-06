#!/bin/bash

# Terminal.appで新しいタブを開いてmcjsを起動する

cd "$(dirname "$0")"

echo "🚀 Starting mcjs in new Terminal tab..."

osascript -e "tell application \"Terminal\" to do script \"cd '$PWD' && HOST=127.0.0.1 PORT=8620 ./.build/debug/mcjs\""

echo "✅ Terminal tab opened. Server should be starting..."