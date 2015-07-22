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

- (instancetype)init
{
    // Designated Initializer
    return [self initWithDynamicIdentifier:@"" initSelector:@selector(init) initParameters:@[]];
}

- (instancetype)initWithDynamicIdentifier:(NSString * __nonnull)identifier initSelector:(SEL __nonnull)initSelector initParameters:(NSArray * __nonnull)initParameters
{
    if (![self.class isDynamicSubclass])
    {
        Class dynamicSubclass = [self.class subclassForDynamicIdentifier:identifier];
        
        if (dynamicSubclass)
        {
            object_setClass(self, dynamicSubclass);
            
            self = [dynamicSubclass alloc];
            
            NSMethodSignature *methodSignature = [dynamicSubclass instanceMethodSignatureForSelector:initSelector];
            
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
            [invocation setTarget:self];
            [invocation setSelector:initSelector];
            
            [initParameters enumerateObjectsUsingBlock:^(id argument, NSUInteger index, BOOL *stop) {
                
                NSInteger argumentIndex = 2 + index;
                
                if (strcmp([methodSignature getArgumentTypeAtIndex:argumentIndex], @encode(id)) == 0)
                {
                    // Object
                    
                    [invocation setArgument:&argument atIndex:argumentIndex];
                }
                else
                {
                    // Primitive Value
                    
                    NSUInteger bufferSize = 0;
                    NSGetSizeAndAlignment([argument objCType], &bufferSize, NULL);
                    
                    void *buffer = malloc(bufferSize);
                    [argument getValue:buffer];
                    
                    [invocation setArgument:buffer atIndex:argumentIndex];
                    
                    free(buffer);
                }
            }];
            
            [invocation invoke];
            [invocation getReturnValue:&self];
        }
        else
        {
            self = [super init];
        }
    }
    else
    {
        self = [super init];
    }    
    
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

+ (Class)subclassForDynamicIdentifier:(nonnull NSString *)identifier
{
    NSDictionary *dynamicSubclasses = objc_getAssociatedObject(self.class, DeltaDynamicSubclassesKey);
    Class subclass = dynamicSubclasses[identifier];
    
    return subclass;
}

@end
