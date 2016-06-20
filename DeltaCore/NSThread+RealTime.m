//
//  NSThread+RealTime.m
//  DeltaCore
//
//  Created by Riley Testut on 6/9/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//
//  Based on OpenEmu's OETimingUtils https://github.com/OpenEmu/OpenEmu-SDK/blob/master/OpenEmuBase/OETimingUtils.m
// 

#import "NSThread+RealTime.h"

#import <mach/mach_init.h>
#import <mach/mach_time.h>
#import <mach/thread_policy.h>
#import <mach/thread_act.h>
#import <pthread.h>

@implementation NSThread (RealTime)

static double mach_to_sec = 0;

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct mach_timebase_info base;
        mach_timebase_info(&base);
        mach_to_sec = 1e-9 * (base.numer / (double)base.denom);
    });
}

+ (BOOL)setRealTimePriorityWithPeriod:(NSTimeInterval)period
{
    thread_port_t threadport = pthread_mach_thread_np(pthread_self());
    
    struct thread_time_constraint_policy ttcpolicy;
    ttcpolicy.period      = period / mach_to_sec;
    ttcpolicy.computation = 0.007 / mach_to_sec;
    ttcpolicy.constraint  = 0.03 / mach_to_sec;
    ttcpolicy.preemptible = 1;
    
    if (thread_policy_set(threadport,
                          THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&ttcpolicy,
                          THREAD_TIME_CONSTRAINT_POLICY_COUNT) != KERN_SUCCESS)
    {
        NSLog(@"+[NSThread setRealTimePriorityWithPeriod:] failed.");
        return NO;
    }
    
    return YES;
}

+ (void)realTimeWaitUntil:(NSTimeInterval)delay
{
    mach_wait_until(delay / mach_to_sec);
}

#pragma mark - Getters/Setters -

+ (NSTimeInterval)absoluteTime
{
    return mach_absolute_time() * mach_to_sec;
}

@end
