//
//  DCMViewController.h
//  DUOCamera
//
//  Created by Dominik Krejcik on 24/10/2013.
//  Copyright (c) 2013 Dominik Krejcik. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DCMViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIView *ownCameraView;
@property (nonatomic, strong) IBOutlet UIView *remoteCameraView;
@property (nonatomic, strong) IBOutlet UIImageView *remoteImageView;
@property (nonatomic, strong) IBOutlet UIImageView *ownImageView;
@property (nonatomic, strong) IBOutlet UIButton *connectButton;
@property (nonatomic, strong) IBOutlet UIView *remoteWaitingView;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *remoteActivityView;
@property (nonatomic, strong) IBOutlet UIButton *disconnectButton;

- (IBAction)connectButtonTapped:(id)sender;
- (IBAction)disconnectButtonTapped:(id)sender;

@end
