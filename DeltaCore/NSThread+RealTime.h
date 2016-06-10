//
//  NSThread+RealTime.h
//  DeltaCore
//
//  Created by Riley Testut on 6/9/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSThread (RealTime)

+ (BOOL)setRealTimePriorityWithPeriod:(NSTimeInterval)period;

+ (NSTimeInterval)absoluteTime;
+ (void)realTimeWaitUntil:(NSTimeInterval)delay;

@end
