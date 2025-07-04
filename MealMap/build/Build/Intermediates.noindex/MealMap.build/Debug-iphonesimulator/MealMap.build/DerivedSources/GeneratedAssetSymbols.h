#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "meal_map_icon_1x" asset catalog image resource.
static NSString * const ACImageNameMealMapIcon1X AC_SWIFT_PRIVATE = @"meal_map_icon_1x";

/// The "meal_map_icon_2x" asset catalog image resource.
static NSString * const ACImageNameMealMapIcon2X AC_SWIFT_PRIVATE = @"meal_map_icon_2x";

/// The "meal_map_icon_3x" asset catalog image resource.
static NSString * const ACImageNameMealMapIcon3X AC_SWIFT_PRIVATE = @"meal_map_icon_3x";

#undef AC_SWIFT_PRIVATE
