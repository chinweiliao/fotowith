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
@property (weak, nonatomic) IBOutlet UIButton *takePicButtonOutlet;
@property (weak, nonatomic) IBOutlet UIButton *flashButtonOutlet;
@property (weak, nonatomic) IBOutlet UIButton *countDownButtonOutlet;
@property (weak, nonatomic) IBOutlet UILabel *countDownLabel;
@property (weak, nonatomic) IBOutlet UIButton *shutterModeButtonOutlet;
@property (weak, nonatomic) IBOutlet UIButton *singleOrSplitModeButtonOutlet;
@property (weak, nonatomic) IBOutlet UIView *topBarOutlet;

- (IBAction)takePicButton:(UIButton *)sender;
- (IBAction)connectButtonTapped:(id)sender;
- (IBAction)disconnectButtonTapped:(id)sender;
- (IBAction)flashButtonTapped:(UIButton *)sender;
- (IBAction)countDownButtonTapped:(UIButton *)sender;
- (IBAction)shutterModeButtonTapped:(UIButton *)sender;
- (IBAction)singleOrSplitModeButtonTapped:(UIButton *)sender;

@end
