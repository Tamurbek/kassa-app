#!/bin/bash
echo "🔄 Starting Git sync..."

# Add all changes
git add .

# Commit changes
git commit -m "fix: resolve Windows SQLite FFI boolean compatibility issue for remote sync and bump version to 1.23.51"

# Delete locally if it exists and recreate
git tag -d v1.23.51 2>/dev/null
git tag v1.23.51

# Push to repository
echo "🚀 Pushing changes to remote..."
git push origin kassa-app-version
git push origin v1.23.51 -f

echo "✅ Git sync completed successfully!"
