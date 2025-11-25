#!/bin/bash
# Start backend server in background (for production)
cd "$(dirname "$0")"

# Kill any existing server on port 3000
lsof -ti:3000 | xargs kill -9 2>/dev/null || true

# Start the server in background
node src/index.js > server.log 2>&1 &
SERVER_PID=$!

# Wait a moment to see if it starts successfully
sleep 2

# Check if process is still running
if ps -p $SERVER_PID > /dev/null; then
  echo "✅ Backend server started successfully. PID: $SERVER_PID"
  echo "📋 Logs: tail -f server.log"
  echo "🛑 Stop: kill $SERVER_PID"
else
  echo "❌ Backend server failed to start. Check server.log for errors:"
  tail -20 server.log
  exit 1
fi

