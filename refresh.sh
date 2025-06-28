#!/bin/bash

# Ubuntu Server Refresh Script
# This script refreshes the system and pulls the latest changes from GitHub

set -x

echo "=== Ubuntu Server Refresh Script ==="
echo "Refreshing system and pulling latest changes..."

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    git remote add origin https://github.com/Zatoichi-42/ubuntuX.git
fi

# Fetch the latest changes
echo "Fetching latest changes from GitHub..."
git fetch origin

# Reset to match the remote repository
echo "Resetting to match remote repository..."
git reset --hard origin/main

# Pull latest changes
echo "Pulling latest changes..."
git pull origin main

# Make scripts executable
echo "Making scripts executable..."
chmod +x refresh.sh
chmod +x init.sh

echo "=== Refresh Complete ==="
echo "Latest changes pulled from GitHub."
echo "Run './init.sh' to execute the setup script."