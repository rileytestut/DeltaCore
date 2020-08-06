//
//  DeltaCore.h
//  DeltaCore
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for DeltaCore.
FOUNDATION_EXPORT double DeltaCoreVersionNumber;

//! Project version string for DeltaCore.
FOUNDATION_EXPORT const unsigned char DeltaCoreVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <DeltaCore/PublicHeader.h>
#import <DeltaCore/DeltaTypes.h>

// HACK: Needed because the generated DeltaCore-Swift header file uses @import syntax, which isn't supported in Objective-C++ code.
//#import <GLKit/GLKit.h>
#import <MetalKit/MetalKit.h>
#import <AVFoundation/AVFoundation.h>

@interface NSXPCConnection ()

// Initialize an NSXPCConnection that will connect to the specified service name. Note: Receiving a non-nil result from this init method does not mean the service name is valid or the service has been launched. The init method simply constructs the local object.
- (instancetype)initWithServiceName:(NSString *)serviceName NS_AVAILABLE_IOS(11_0);

- (instancetype)initWithYourMom:(BOOL)mom;

@end;

NS_ASSUME_NONNULL_BEGIN

@interface NSExtension : NSObject

+ (instancetype)extensionWithIdentifier:(NSString *)identifier error:(NSError *_Nullable *)error;
+ (void)extensionWithURL:(NSURL *)url completion:(void (^)(NSExtension *_Nullable extension, NSError *_Nullable error))completionBlock;

- (void)beginExtensionRequestWithInputItems:(NSArray *)inputItems completion:(void (^)(NSUUID *requestIdentifier))completion;

- (int)pidForRequestIdentifier:(NSUUID *)requestIdentifier;
- (void)cancelExtensionRequestWithIdentifier:(NSUUID *)requestIdentifier;

- (void)setRequestCancellationBlock:(void (^)(NSUUID *uuid, NSError *error))cancellationBlock;
- (void)setRequestCompletionBlock:(void (^)(NSUUID *uuid, NSArray *extensionItems))completionBlock;
- (void)setRequestInterruptionBlock:(void (^)(NSUUID *uuid))interruptionBlock;

@property (nonatomic,retain) NSMutableDictionary<NSUUID *, NSXPCConnection *> * _extensionServiceConnections;
@property (nonatomic,copy) NSSet * _allowedErrorClasses;
@property (nonatomic,retain) NSMutableDictionary * _extensionContexts;

@end

NS_ASSUME_NONNULL_END

NS_ASSUME_NONNULL_BEGIN

//@interface NSPortMessage : NSObject
//
//- (instancetype)initWithSendPort:(nullable NSPort *)sendPort receivePort:(nullable NSPort *)replyPort components:(nullable NSArray *)components NS_DESIGNATED_INITIALIZER;
//
//@property (nullable, readonly, copy) NSArray *components;
//@property (nullable, readonly, retain) NSPort *receivePort;
//@property (nullable, readonly, retain) NSPort *sendPort;
//- (BOOL)sendBeforeDate:(NSDate *)date;
//
//@property uint32_t msgid;
//
//@end

NS_ASSUME_NONNULL_END

void *RSTGetPort(CFMessagePortRef port);



#include <mach/message.h>
#import <Foundation/Foundation.h>

#include <mach/std_types.h>
#include <mach/message.h>
#include <sys/types.h>
#include <stdbool.h>

#include <mach/mach_types.h>

#if TARGET_OS_MACCATALYST
#include <xpc/xpc.h>
#else
typedef id xpc_object_t;
typedef void *xpc_type_t;
#endif

#define    BOOTSTRAP_MAX_NAME_LEN 128
#define    BOOTSTRAP_MAX_CMD_LEN 512

typedef char name_t[BOOTSTRAP_MAX_NAME_LEN];

kern_return_t
bootstrap_register(mach_port_t bp, name_t service_name, mach_port_t sp);

//kern_return_t
//task_get_bootstrap_port (task_t task, mach_port_t *bootstrap_port);


kern_return_t
bootstrap_look_up(mach_port_t bp, const name_t service_name, mach_port_t *sp);

typedef struct _xpc_pipe_s* xpc_pipe_t;

void xpc_dictionary_set_int64(xpc_object_t xdict,
                              const char* key,
                              int64_t value);
//void xpc_release(xpc_object_t object);

bool xpc_dictionary_get_bool(xpc_object_t xdict, const char* key);
int64_t xpc_dictionary_get_int64(xpc_object_t xdict, const char* key);
const char* xpc_dictionary_get_string(xpc_object_t xdict, const char* key);
uint64_t xpc_dictionary_get_uint64(xpc_object_t xdict, const char* key);
void xpc_dictionary_set_uint64(xpc_object_t xdict,
                               const char* key,
                               uint64_t value);
void xpc_dictionary_set_string(xpc_object_t xdict, const char* key,
                               const char* string);
xpc_object_t xpc_dictionary_create(const char* const* keys,
                                   const xpc_object_t* values,
                                   size_t count);
xpc_object_t xpc_dictionary_create_reply(xpc_object_t original);
xpc_object_t xpc_dictionary_get_value(xpc_object_t xdict, const char* key);
char* xpc_copy_description(xpc_object_t object);

// Dictionary manipulation.
void xpc_dictionary_set_mach_send(xpc_object_t dictionary,
                                  const char* name,
                                  mach_port_t port);
void xpc_dictionary_get_audit_token(xpc_object_t dictionary,
                                    audit_token_t* token);
// Raw object getters.
mach_port_t xpc_mach_send_get_right(xpc_object_t value);
// Pipe methods.
xpc_pipe_t xpc_pipe_create_from_port(mach_port_t port, int flags);
int xpc_pipe_receive(mach_port_t port, xpc_object_t* message);
int xpc_pipe_routine(xpc_pipe_t pipe,
                     xpc_object_t request,
                     xpc_object_t* reply);
int xpc_pipe_routine_reply(xpc_object_t reply);
int xpc_pipe_simpleroutine(xpc_pipe_t pipe, xpc_object_t message);
int xpc_pipe_routine_forward(xpc_pipe_t forward_to, xpc_object_t request);

xpc_type_t RSTXPCDictionaryType();
