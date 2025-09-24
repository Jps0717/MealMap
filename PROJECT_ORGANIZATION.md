# MealMap Project Organization

This document outlines the structure and organization of the MealMap iOS project.

## Directory Structure

```
MealMap/
├── Scripts/                    # Build and utility scripts
│   ├── prevent_xcode_hangs.sh # Xcode optimization script
│   └── README.md              # Script documentation
├── MealMap/                   # Main application directory
│   └── MealMap/               # Source code
│       ├── Models/            # Data models
│       ├── Views/             # SwiftUI views
│       │   ├── Components/    # Reusable UI components
│       │   ├── Categories/    # Category-related views
│       │   ├── Chat/          # Chat interface
│       │   ├── Map/           # Map-related views
│       │   ├── Menu/          # Menu scanning and analysis
│       │   ├── Nutrition/     # Nutrition tracking views
│       │   ├── Onboarding/    # User onboarding
│       │   ├── Profile/       # User profile management
│       │   ├── Search/        # Restaurant search
│       │   └── Windows/       # Window-level views
│       ├── ViewModels/        # MVVM view models
│       ├── Managers/          # Business logic managers
│       └── Services/          # External service integrations
└── README.md                  # Project documentation
```

## Component Organization

### Models (`Models/`)
- **Core Data Models**: `NutritionData.swift`, `User.swift`, `ConsumedItem.swift`
- **Business Models**: `RestaurantData.swift`, `RestaurantFilter.swift`
- **Analysis Models**: `MenuAnalysis.swift`, `SavedMenuAnalysis.swift`

### Views (`Views/`)
Organized by feature area:
- **Components**: Reusable UI components like `LoadingView.swift`, `QuickActionButton.swift`
- **Categories**: Restaurant category browsing
- **Map**: Map interface and location-based features  
- **Menu**: Menu scanning, OCR, and nutrition analysis
- **Nutrition**: Nutrition tracking and daily summaries
- **Profile**: User management and dietary preferences

### Managers (`Managers/`)
Business logic coordinators:
- **AuthenticationManager**: User authentication
- **ConsumptionManager**: Nutrition consumption tracking
- **LocationManager**: GPS and location services
- **NutritionDataManager**: Nutrition data coordination

### Services (`Services/`)
External integrations:
- **FirebaseFirestoreService**: Cloud data persistence
- **NutritionixAPIService**: Nutrition data API
- **OverpassAPIService**: Restaurant location data
- **MenuOCRService**: Menu text extraction

## Recent Cleanup Actions

### Files Removed
- ✅ Duplicate `MealMapApp.swift` (kept the enhanced version)
- ✅ `MapLoadingView.swift` (redundant with `LoadingView.swift`)
- ✅ All `.DS_Store` files

### Files Consolidated
- ✅ Created unified `CategoryRestaurantRow.swift` component
- ✅ Moved scripts to dedicated `Scripts/` directory

### Files Organized
- ✅ Enhanced `.gitignore` with comprehensive rules
- ✅ Created script documentation in `Scripts/README.md`

## Maintenance Guidelines

### Adding New Features
1. Choose appropriate directory based on feature area
2. Follow existing naming conventions
3. Create reusable components in `Views/Components/`
4. Add business logic to appropriate managers
5. Update this documentation

### Code Organization
- **Single Responsibility**: Each file should have one clear purpose
- **Dependency Injection**: Use managers and services as dependencies
- **Reusability**: Extract common UI patterns to components
- **Documentation**: Update README files when adding major features

### Build Optimization
- Use `Scripts/prevent_xcode_hangs.sh` before development sessions
- Keep DerivedData clean between major changes
- Monitor build times and investigate slow compiles

## Architecture Notes

This project follows MVVM architecture with:
- **Models**: Pure data structures
- **Views**: SwiftUI views with minimal logic
- **ViewModels**: Business logic and state management
- **Managers**: Cross-cutting concerns and coordination
- **Services**: External API integration

The modular organization allows for easy testing, maintenance, and feature additions.
