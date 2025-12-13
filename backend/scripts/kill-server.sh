#!/bin/bash
# Kill any running Node.js backend server instances

echo "Checking for running Node.js processes on port 3000..."

# Find process on port 3000
PORT_PID=$(lsof -ti:3000 2>/dev/null)

if [ -z "$PORT_PID" ]; then
    echo "✅ No process running on port 3000"
else
    echo "Found process $PORT_PID on port 3000"
    kill -9 $PORT_PID
    echo "✅ Killed process $PORT_PID"
fi

# Find any node processes running index.js
NODE_PIDS=$(ps aux | grep "node.*index.js" | grep -v grep | awk '{print $2}')

if [ -z "$NODE_PIDS" ]; then
    echo "✅ No Node.js backend processes found"
else
    echo "Found Node.js processes: $NODE_PIDS"
    for pid in $NODE_PIDS; do
        kill -9 $pid
        echo "✅ Killed process $pid"
    done
fi

echo ""
echo "All clear! You can now start the server with: npm start"

