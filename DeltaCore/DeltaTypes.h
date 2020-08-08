//
//  DeltaTypes.h
//  DeltaCore
//
//  Created by Riley Testut on 1/30/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#if !TARGET_OS_MACCATALYST
#import <IOSurface/IOSurfaceRef.h>
#endif

#import <Metal/Metal.h>

// Extensible Enums
typedef NSString *GameType NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *CheatType NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *GameControllerInputType NS_TYPED_EXTENSIBLE_ENUM;

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const DeltaRegistrationRequestNotification;

#if !TARGET_OS_MACCATALYST
id IOSurfaceCreateXPCObject(IOSurfaceRef aSurface);
IOSurfaceRef IOSurfaceLookupFromXPCObject(id xobj) CF_RETURNS_RETAINED;

@interface NSXPCCoder ()

- (void)encodeXPCObject:(id)xpcObject forKey:(NSString *)key;
//
//// This validates the type of the decoded object matches the type passed in. If they do not match, an exception is thrown (just like the rest of Secure Coding behaves). Note: This can return NULL, but calling an xpc function with NULL will crash. So make sure to do the right thing if you get back a NULL result.
- (nullable id)decodeXPCObjectOfType:(void *)type forKey:(NSString *)key API_AVAILABLE(macos(10.9), ios(7.0), watchos(2.0), tvos(9.0));

@end

void *xpc_get_type(id object);

@interface NSPort (Delegate)

- (void)setMyDelegate:(id)delegate;

@end

mach_port_t
mach_task_self();

#endif

@interface MachMessageDelegate : NSObject <NSMachPortDelegate>

- (void)assignToMachPort:(NSMachPort *)machPort;

@end

int RSTSendPort(mach_port_t destination_port, mach_port_t value);
int RSTReceivePort(void *source_data, mach_port_t *value);


@interface MTLSharedTextureHandle (PrivateAPIs)

- (instancetype)initWithIOSurface:(IOSurfaceRef)arg1 label:(NSString *)label;
- (IOSurfaceRef)ioSurface;


@end

NS_ASSUME_NONNULL_END
