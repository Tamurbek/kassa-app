#!/bin/bash
echo "🔄 Starting Git sync..."

# Add all changes
git add .

# Commit changes
git commit -m "fix: redesign receipt layout to use 5mm margins and solid black text, prevent cutoff, bump version to 1.23.56"

# Delete locally if it exists and recreate
git tag -d v1.23.56 2>/dev/null
git tag v1.23.56

# Push to repository
echo "🚀 Pushing changes to remote..."
git push origin kassa-app-version
git push origin v1.23.56 -f

echo "✅ Git sync completed successfully!"
