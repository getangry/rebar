#!/bin/sh
set -e

# Check if package.json has changed since last install
if [ ! -f "/app/node_modules/.package-lock.json" ] || \
   [ "/app/package.json" -nt "/app/node_modules/.package-lock.json" ] || \
   [ "/app/package-lock.json" -nt "/app/node_modules/.package-lock.json" ]; then
  echo "📦 Installing npm dependencies..."
  npm install --legacy-peer-deps
else
  echo "✅ Dependencies up to date"
fi

# Execute the main command
exec "$@"
