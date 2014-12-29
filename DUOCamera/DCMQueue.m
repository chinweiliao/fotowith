//
//  DCMQueue.m
//  DUOCamera
//
//  Created by Dominik Krejcik on 29/10/2013.
//  Copyright (c) 2013 Dominik Krejcik. All rights reserved.
//

#import "DCMQueue.h"

@interface DCMQueue ()

@property (atomic, strong) NSMutableArray *array;

@end

@implementation DCMQueue

- (id)init {
    self = [super init];
    if (self) {
        _array = [NSMutableArray new];
    }
    
    return self;
}

- (void)enqueue:(id)object {
    @synchronized(self) {
        [self.array addObject:object];
    }
}

- (id)dequeue {
    @synchronized(self) {
        id retval = self.array.firstObject;
        if (retval) {
            [self.array removeObjectAtIndex:0];
        }
        return retval;
    }
}

- (void)removeAllObjects {
    @synchronized(self) {
        [self.array removeAllObjects];
    }
}

- (NSInteger)count {
    @synchronized(self) {
        return self.array.count;
    }
}

- (BOOL)isEmpty {
    return self.count == 0;
}

@end
