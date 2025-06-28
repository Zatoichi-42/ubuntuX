#!/bin/bash

# UbuntuX Repository Refresh Script
# This script updates the local repository from GitHub

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a git repository
if [[ ! -d .git ]]; then
    print_error "Not in a git repository. Please run this script from the ubuntuX directory."
    exit 1
fi

# Check if git is available
if ! command -v git &> /dev/null; then
    print_error "Git is not installed. Installing git..."
    sudo apt update
    sudo apt install -y git
fi

# Check if dos2unix is available
if ! command -v dos2unix &> /dev/null; then
    print_warning "dos2unix not found. Installing..."
    sudo apt update
    sudo apt install -y dos2unix
fi

print_status "Fetching latest changes from GitHub..."
git fetch origin

print_status "Pulling latest changes..."
git pull origin main

print_status "Setting executable permissions..."
chmod +x init.sh

print_status "Converting line endings..."
dos2unix init.sh 2>/dev/null || true

print_status "Repository updated successfully!"
print_status "Run: ./init.sh to start the setup script"

# Show current status
echo ""
print_status "Current repository status:"
git status --short