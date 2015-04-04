//
//  AnimationDirector.h
//  DUOCamera
//
//  Created by Daz on 4/3/15.
//  Copyright (c) 2015 Dominik Krejcik. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AnimationDirector: NSObject

+(void) showFlash:(UIView*) targetUIView completion: (void (^)(void))callback;
+(void) showRightToLeftTransition:(UIView*) targetUIView;
+(void) showLeftToRightTransition:(UIView*) targetUIView completion: (void (^)(void))callback;
+(void) fadeAway:(UIView*) targetUIView;

@end