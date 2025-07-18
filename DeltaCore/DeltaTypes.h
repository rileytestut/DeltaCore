//
//  DeltaTypes.h
//  DeltaCore
//
//  Created by Riley Testut on 1/30/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

// Extensible Enums
typedef NSString *GameType NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *CheatType NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *GameControllerInputType NS_TYPED_EXTENSIBLE_ENUM;

// Emulator Core Options
typedef NSString *EmulatorCoreOption NS_REFINED_FOR_SWIFT NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT EmulatorCoreOption const EmulatorCoreOptionOpenGLES2;
FOUNDATION_EXPORT EmulatorCoreOption const EmulatorCoreOptionMetal;

extern NSNotificationName const DeltaRegistrationRequestNotification;

// Used by GameWindow.
@interface UIWindow (Private)

@property (nullable, weak, nonatomic, setter=_setLastFirstResponder:) UIResponder *_lastFirstResponder /* API_AVAILABLE(ios(16)) */;
- (void)_restoreFirstResponder /* API_AVAILABLE(ios(16)) */;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
