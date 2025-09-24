# MealMap Scripts

This directory contains utility scripts for the MealMap project.

## Available Scripts

### `prevent_xcode_hangs.sh`
**Purpose:** Prevents Xcode build hangs and improves build performance.

**What it does:**
- Cleans Xcode build artifacts and caches
- Disables problematic Xcode features
- Kills stuck Swift compiler processes
- Provides manual optimization steps for Xcode settings

**Usage:**
```bash
cd Scripts
chmod +x prevent_xcode_hangs.sh
./prevent_xcode_hangs.sh
```

**When to use:**
- Before starting development sessions
- When experiencing slow builds or hangs
- After major Xcode updates
- When switching between branches with significant changes

**Note:** Follow the manual steps printed by the script to complete the optimization.

## Adding New Scripts

When adding new scripts to this directory:
1. Make them executable: `chmod +x script_name.sh`
2. Add proper error handling with `set -euo pipefail`
3. Include usage documentation in this README
4. Use descriptive logging with the `log_step()` function pattern
