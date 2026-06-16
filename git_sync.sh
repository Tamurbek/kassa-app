#!/bin/bash
echo "🔄 Starting Git sync..."

# Add all changes
git add .

# Commit changes
git commit -m "fix: redesign receipt layout to use symmetric margins, prevent cutoff, bump version to 1.23.54"

# Delete locally if it exists and recreate
git tag -d v1.23.54 2>/dev/null
git tag v1.23.54

# Push to repository
echo "🚀 Pushing changes to remote..."
git push origin kassa-app-version
git push origin v1.23.54 -f

echo "✅ Git sync completed successfully!"
