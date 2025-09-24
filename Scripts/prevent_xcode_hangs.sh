#!/bin/bash
set -euo pipefail

log_step() {
    echo "$1"
}

log_step "🔧 Preventing Xcode Build Hangs Script"
log_step "======================================"

# Step 1: Clean all build artifacts
log_step "1. Cleaning build artifacts..."
paths=(
    "$HOME/Library/Developer/Xcode/DerivedData/*"
    "$HOME/Library/Caches/com.apple.dt.Xcode*"
    "$HOME/Library/Developer/Xcode/iOS DeviceSupport/*/Symbols/System/Library/Caches"
)
for path in "${paths[@]}"; do
    expanded_path=$(eval echo "$path")
    [ -d "$expanded_path" ] && rm -rf "$expanded_path"
done

# Step 2: Disable problematic Xcode features
log_step "2. Disabling problematic Xcode features..."
defaults write com.apple.dt.Xcode IDEIndexDisable -bool true
defaults write com.apple.dt.Xcode DVTTextShowCompletionsOnDemand -bool true
defaults write com.apple.dt.Xcode DVTTextShowFoldingRibbon -bool true

# Step 3: Set build optimizations
log_step "3. Setting build optimizations..."
# These will be manual steps in Xcode Build Settings

# Step 4: Kill any stuck processes
log_step "4. Cleaning up stuck processes..."
for proc in swift-frontend sourcekit xcodebuild; do
    pkill -f "$proc" 2>/dev/null || true
done

log_step "✅ Prevention steps complete!"
echo ""
log_step "📋 MANUAL STEPS NEEDED IN XCODE:"
log_step "1. Go to Build Settings → Swift Compiler - Code Generation"
log_step "2. Set 'Optimization Level' to 'No Optimization [-Onone]' for DEBUG"
log_step "3. Set 'Compilation Mode' to 'Incremental'"
log_step "4. Disable 'Whole Module Optimization'"
echo ""
log_step "🔄 RESTART YOUR MAC NOW to clear kernel-level issues"
