//
//  AnimationDirector.m
//  DUOCamera
//
//  Created by Daz on 4/3/15.
//  Copyright (c) 2015 Dominik Krejcik. All rights reserved.
//

#import "AnimationDirector.h"

@interface AnimationDirector()


@end

@implementation AnimationDirector

+(void) showFlash:(UIView *)targetUIView completion: (void (^)(void))callback {
    UIView* mask = [[UIView alloc] initWithFrame:targetUIView.frame];
    mask.backgroundColor = [UIColor whiteColor];
    mask.alpha = 1;
    
    [targetUIView addSubview:mask];
    [UIView animateWithDuration:0.1 animations:^{
        mask.alpha = 0.0;
    } completion:^(BOOL finished){
        targetUIView.alpha = 1.0;
        [mask removeFromSuperview];
        if (callback != nil){
            callback();
        }
    }];

}

+(void) showRightToLeftTransition:(UIView *)targetUIView {
    CGRect screeenRect = [[UIScreen mainScreen] bounds];
    CGFloat originX = targetUIView.frame.origin.x;
    targetUIView.frame = CGRectMake(screeenRect.size.width, 0, targetUIView.frame.size.width, targetUIView.frame.size.height);
    
    [UIView animateWithDuration:0.5 animations:^{
        targetUIView.frame = CGRectMake(originX, 0, targetUIView.frame.size.width, targetUIView.frame.size.height);
    } completion:^(BOOL finished){
    }];
}

//+(void) showLeftToRightTransition:(UIView *)targetUIView, (^completion)(void) {
+(void) showLeftToRightTransition:(UIView *)targetUIView completion:(void (^)(void))callback {
    CGRect screeenRect = [[UIScreen mainScreen] bounds];
    CGFloat originX = targetUIView.frame.origin.x;
    [UIView animateWithDuration:0.5 animations:^{
        targetUIView.frame = CGRectMake(screeenRect.size.width, 0, targetUIView.frame.size.width, targetUIView.frame.size.height);
    } completion:^(BOOL finished){
        targetUIView.frame = CGRectMake(originX, 0, targetUIView.frame.size.width, targetUIView.frame.size.height);
        callback();
    }];
}

+(void) fadeAway: (UIView*) targetUIView {
    targetUIView.alpha = 1.0;
    [UIView animateWithDuration:0.5 animations:^{
        targetUIView.alpha = 0.0;
    } completion:^(BOOL finished){

    }];
    
    
}

@end