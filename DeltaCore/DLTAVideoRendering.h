//
//  DLTAVideoRendering.h
//  DeltaCore
//
//  Created by Riley Testut on 3/16/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DLTAVideoRendering <NSObject>

@property (nonatomic, readonly) unsigned char *videoBuffer;

@end
