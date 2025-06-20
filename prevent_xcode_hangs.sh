#!/bin/bash

echo "🔧 Preventing Xcode Build Hangs Script"
echo "======================================"

# Step 1: Clean all build artifacts
echo "1. Cleaning build artifacts..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode*
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*/Symbols/System/Library/Caches

# Step 2: Disable problematic Xcode features
echo "2. Disabling problematic Xcode features..."
defaults write com.apple.dt.Xcode IDEIndexDisable -bool true
defaults write com.apple.dt.Xcode DVTTextShowCompletionsOnDemand -bool true
defaults write com.apple.dt.Xcode DVTTextShowFoldingRibbon -bool true

# Step 3: Set build optimizations
echo "3. Setting build optimizations..."
# These will be manual steps in Xcode Build Settings

# Step 4: Kill any stuck processes
echo "4. Cleaning up stuck processes..."
pkill -f "swift-frontend" 2>/dev/null || true
pkill -f "sourcekit" 2>/dev/null || true
pkill -f "xcodebuild" 2>/dev/null || true

echo "✅ Prevention steps complete!"
echo ""
echo "📋 MANUAL STEPS NEEDED IN XCODE:"
echo "1. Go to Build Settings → Swift Compiler - Code Generation"
echo "2. Set 'Optimization Level' to 'No Optimization [-Onone]' for DEBUG"
echo "3. Set 'Compilation Mode' to 'Incremental'"
echo "4. Disable 'Whole Module Optimization'"
echo ""
echo "🔄 RESTART YOUR MAC NOW to clear kernel-level issues"
