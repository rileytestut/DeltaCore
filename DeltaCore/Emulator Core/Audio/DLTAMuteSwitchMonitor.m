//
//  DLTAMuteSwitchMonitor.m
//  DeltaCore
//
//  Created by Riley Testut on 11/19/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

#import "DLTAMuteSwitchMonitor.h"

#import <notify.h>

@import AudioToolbox;

@interface DLTAMuteSwitchMonitor ()

@property (nonatomic, readwrite) BOOL isMonitoring;
@property (nonatomic, readwrite) BOOL isMuted;

@property (nonatomic) int notifyToken;

@end

@implementation DLTAMuteSwitchMonitor

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _isMuted = YES;
    }
    
    return self;
}

- (void)startMonitoring:(void (^)(BOOL isMuted))muteHandler
{
    if ([self isMonitoring])
    {
        return;
    }
    
    self.isMonitoring = YES;
    
    __weak __typeof(self) weakSelf = self;
    void (^updateMutedState)(void) = ^{
        if (weakSelf == nil)
        {
            return;
        }
        
        uint64_t state;
        uint32_t result = notify_get_state(weakSelf.notifyToken, &state);
        if (result == NOTIFY_STATUS_OK)
        {
            weakSelf.isMuted = (state == 0);
            muteHandler(weakSelf.isMuted);
        }
        else
        {
            NSLog(@"Failed to get mute state. Error: %@", @(result));
        }
    };
    
    NSString *privateAPIName = [[@[@"com", @"apple", @"springboard", @"ring3rstat3"] componentsJoinedByString:@"."] stringByReplacingOccurrencesOfString:@"3" withString:@"e"];
    notify_register_dispatch(privateAPIName.UTF8String, &_notifyToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(int token) {
        updateMutedState();
    });
    
    updateMutedState();
}

- (void)stopMonitoring
{
    if (![self isMonitoring])
    {
        return;
    }
    
    self.isMonitoring = NO;
    
    notify_cancel(self.notifyToken);
}

@end
