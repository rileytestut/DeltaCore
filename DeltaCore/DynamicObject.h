//
//  DynamicObject.h
//  DeltaCore
//
//  Created by Riley Testut on 4/19/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DynamicObject : NSObject

@property (class, nonatomic, readonly, getter=isDynamicSubclass) BOOL dynamicSubclass;
@property (class, nonatomic, nullable, readonly) NSString *dynamicIdentifier;

+ (Class)subclassForDynamicIdentifier:(NSString *)identifier;

- (instancetype)initWithDynamicIdentifier:(NSString *)identifier initSelector:(SEL)initSelector initParameters:(NSArray *)initParameters NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
