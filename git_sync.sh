#!/bin/bash
echo "🔄 Starting Git sync..."

# Add all changes
git add .

# Commit changes
git commit -m "fix: make update download resilient to connection timeouts and add browser fallback and bump version to 1.23.52"

# Delete locally if it exists and recreate
git tag -d v1.23.52 2>/dev/null
git tag v1.23.52

# Push to repository
echo "🚀 Pushing changes to remote..."
git push origin kassa-app-version
git push origin v1.23.52 -f

echo "✅ Git sync completed successfully!"
