//
//  DynamicObject.m
//  DeltaCore
//
//  Created by Riley Testut on 4/19/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

#import "DynamicObject.h"

@import ObjectiveC.runtime;

const void *DeltaDynamicSubclassesKey = &DeltaDynamicSubclassesKey;

@implementation DynamicObject

#pragma mark - Init -

- (instancetype)initWithDynamicIdentifier:(NSString * __nonnull)identifier
{
    if (![self.class isDynamicSubclass])
    {
        NSDictionary *dynamicSubclasses = objc_getAssociatedObject(self.class, DeltaDynamicSubclassesKey);
        Class dynamicSubclass = dynamicSubclasses[identifier];
        
        if (dynamicSubclass)
        {
            object_setClass(self, dynamicSubclass);
        }
    }
    
    self = [super init];
    
    if (self)
    {
        
    }
    
    return self;
}

+ (void)initialize
{
    if (self == [DynamicObject class])
    {
        return;
    }
    
    if (![self isDynamicSubclass])
    {
        [self registerDynamicSubclasses];
    }
}

#pragma mark - Dynamic Subclasses -

+ (void)registerDynamicSubclasses
{    
    NSMutableDictionary *dynamicSubclasses = [NSMutableDictionary dictionary];
    
    int totalClasses = objc_getClassList(NULL, 0);
    Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * totalClasses);
    totalClasses = objc_getClassList(classes, totalClasses);
    
    for (int i = 0; i < totalClasses; i++)
    {
        Class subclass = classes[i];
        
        if (class_getSuperclass(subclass) != self)
        {
            continue;
        }
        
        if (![subclass isDynamicSubclass])
        {
            continue;
        }
        
        dynamicSubclasses[[subclass dynamicIdentifier]] = subclass;
    }

    free(classes);
        
    objc_setAssociatedObject(self, DeltaDynamicSubclassesKey, dynamicSubclasses, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

+ (BOOL)isDynamicSubclass
{
    return NO;
}

+ (nullable NSString *)dynamicIdentifier
{
    return nil;
}

@end
