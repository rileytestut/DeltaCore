//
//  DeltaTypes.m
//  DeltaCore
//
//  Created by Riley Testut on 6/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

@import Foundation;

#import "DeltaTypes.h"
#import <DeltaCore/DeltaCore.h>

#import <mach/mach.h>

#if TARGET_OS_MACCATALYST
#import <xpc/xpc.h>
#endif

NSNotificationName const DeltaRegistrationRequestNotification = @"DeltaRegistrationRequestNotification";

//@implementation RSTMessagePort
//
//@end

@interface RSTMachPort : NSPort {
    @public
    __weak id _delegate;
    NSUInteger _flags;
    uint32_t _machPort;
    NSUInteger _reserved;
}

@end

@implementation RSTMachPort
@end

void *RSTGetPort(CFMessagePortRef port)
{
//    NSLog(@"Port: %@", port);
//
//    NSMessagePort *messagePort = (__bridge NSMessagePort *)port;
//    NSLog(@"Port2: %@", port);
//
//    RSTMessagePort *rstPort = (RSTMessagePort *)messagePort;
//    NSLog(@"Port3: %@", rstPort);
//
//    NSMachPort *underlyingPort = (__bridge NSMachPort *)(rstPort->_port);
//    NSLog(@"Underlying Port: %@", underlyingPort);
    
    return NULL;
}

@implementation NSPort (Delegate)

- (void)setMyDelegate:(id)delegate
{
    NSLog(@"Existing delegate: %@", self);
    [self setDelegate:delegate];
    NSLog(@"New delegate: %@", self);
}

@end

//OS_xpc_object object;
//xpc_type_t type;


@implementation MachMessageDelegate

- (void)assignToMachPort:(NSMachPort *)machPort
{
    ((RSTMachPort *)machPort)->_delegate = self;
    NSLog(@"New delegate!");
}

- (void)handlePortMessage:(NSPortMessage *)message
{
    NSLog(@"Handle port message: %@", message);
}

@end

int RSTSendPort(mach_port_t destination_port, mach_port_t value)
{
    kern_return_t       err;
    
    struct {
        mach_msg_header_t          header;
        mach_msg_body_t            body;
        mach_msg_port_descriptor_t task_port;
    } msg;
    
    msg.header.msgh_remote_port = destination_port;
    msg.header.msgh_local_port = MACH_PORT_NULL;
    msg.header.msgh_bits = MACH_MSGH_BITS (MACH_MSG_TYPE_COPY_SEND, 0) |
    MACH_MSGH_BITS_COMPLEX;
    msg.header.msgh_size = sizeof msg;
    
    msg.body.msgh_descriptor_count = 1;
    msg.task_port.name = value;
    msg.task_port.disposition = MACH_MSG_TYPE_COPY_SEND;
    msg.task_port.type = MACH_MSG_PORT_DESCRIPTOR;
    
    err = mach_msg_send (&msg.header);
    if (err != KERN_SUCCESS)
    {
        NSLog(@"mach_msg_send failed: %@", @(err));
    }
    
    return 0;
}

typedef struct {
    mach_msg_header_t          header;
    mach_msg_body_t            body;
    mach_msg_port_descriptor_t task_port;
    mach_msg_trailer_t         trailer;
} RSTMessage;

int RSTReceivePort(void *source_data, mach_port_t *value)
{
    kern_return_t       err;
    
    RSTMessage message = *((RSTMessage *)source_data);
    *value = message.task_port.name;
    
    return 0;
}

xpc_type_t RSTXPCDictionaryType()
{
    xpc_object_t dictionary = xpc_dictionary_create(NULL, NULL, 0);
    xpc_type_t type = xpc_get_type(dictionary);
    return type;
}
