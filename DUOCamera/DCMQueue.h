//
//  DCMQueue.h
//  DUOCamera
//
//  Created by Dominik Krejcik on 29/10/2013.
//  Copyright (c) 2013 Dominik Krejcik. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DCMQueue : NSObject

- (void)enqueue:(id)object;
- (id)dequeue;

- (void)removeAllObjects;

- (NSInteger)count;
- (BOOL)isEmpty;

@end
