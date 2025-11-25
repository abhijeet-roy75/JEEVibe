#!/bin/bash
# Start backend server in interactive mode (foreground)
cd "$(dirname "$0")"

# Kill any existing server on port 3000
lsof -ti:3000 | xargs kill -9 2>/dev/null || true

echo "🚀 Starting JEEVibe backend server..."
echo "📝 Server will run in foreground - logs will appear here"
echo "🛑 Press Ctrl+C to stop the server"
echo ""

# Start the server in foreground (interactive mode)
node src/index.js

