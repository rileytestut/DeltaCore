//
//  DLTAAudioRendering.h
//  DeltaCore
//
//  Created by Riley Testut on 3/16/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DLTARingBuffer.h"

@protocol DLTAAudioRendering <NSObject>

@property (nonatomic, readonly) DLTARingBuffer *ringBuffer;

@end
