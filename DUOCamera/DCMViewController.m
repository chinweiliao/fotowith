//
//  DCMViewController.m
//  DUOCamera
//
//  Created by Dominik Krejcik on 24/10/2013.
//  Copyright (c) 2013 Dominik Krejcik. All rights reserved.
//

#import "DCMViewController.h"

#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <AVFoundation/AVFoundation.h>

#import "DCMQueue.h"

static NSString * appServiceType = @"duocam";
static NSString * shutterSignal = @"TAKE_PICTURE";
static NSString * flashSignal = @"FLASH";
static NSString * shouldTorch = @"SHOULD_TORCH";
static NSString * shouldFlash = @"SHOULD_FLASH";
static NSString * shouldNotFlash = @"SHOULD_NOT_FLASH";
static NSString * unfreezeSignal = @"UNFREEZE";
static NSString * cameraSignal   = @"CAMERA";
static NSString * screenSignal   = @"SCREEN";
enum FlashType {
    OFF, FLASH, ON
};

@interface DCMViewController () <MCBrowserViewControllerDelegate, MCSessionDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, UIAlertViewDelegate>

// Session stuff
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCAdvertiserAssistant *advertiser;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, assign) BOOL isCancel;

- (void)showPeerBrowserController;
- (void)hidePeerBrowserController;

// Image capturing
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) dispatch_queue_t framesProcessingQueue;

- (AVCaptureConnection *)getCaptureConnection;

// Remote image displaying
@property (nonatomic, strong) DCMQueue *queue;
@property (nonatomic, strong) dispatch_queue_t imageBufferProcessingQueue;
@property (atomic, assign) BOOL keepProcessingQueue;

- (void)startProcessingQueue;
- (void)stopProcessingQueue;
- (void)setRemoteImage:(UIImage *)image;
- (void)sendImage:(UIImage *)image;

- (void)showRemoteCameraView;
- (void)hideRemoteCameraView;

- (void)drawTakePicButton;
- (void)showTakePicButton;
- (void)hideTakePicButton;

// Taking image
@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, strong) UIImage *ownCapturedImage;
@property (nonatomic, strong) UIImage *remoteCapturedImage;
@property (nonatomic, assign) BOOL initiatedCapture;
@property (nonatomic, assign) BOOL showingStillImage;

- (void)captureImage;
- (void)sendCaptureSignal;
- (void)takeAndSendPicture;
- (void)processCaptureSignal;
- (void)processCapturedImage:(UIImage *)image;

- (void)flash;
- (void)sendUnfreezeSignal;

// Saving image
- (UIImage *)makeImageFromOwnScreen;

- (void)reset;

// Menu stuff
@property (nonatomic, strong) UIPanGestureRecognizer *panRecognizer;
@property (nonatomic, assign) CGFloat initialDragStart;
@property (nonatomic, assign) BOOL dragginLeft;
@property (nonatomic, assign) BOOL draggingRight;

- (void)pan:(UIPanGestureRecognizer *)recognizer;
- (void)closeMenu:(CGFloat)velocity;
- (void)openMenu:(CGFloat)velocity;

@property (nonatomic, strong) UIAlertView *choosingAlertView;
@property (nonatomic, assign) BOOL isCamera;
@property (nonatomic, assign) enum FlashType shouldFlashLight;
- (void)connectToCamera;
- (void)setFlash: (AVCaptureDevice *)device;
- (BOOL)toggleFlashLight;
- (void)turnOnTorch;
- (void)turnOffTorch;
- (void)setUpCamera;
- (void)setUpScreen;

@end

@implementation DCMViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.remoteImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.ownImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.remoteImageView.clipsToBounds = YES;
    self.ownImageView.clipsToBounds = YES;
    self.remoteWaitingView.hidden = YES;
    self.ownImageView.hidden = YES;
    
    self.queue = [[DCMQueue alloc] init];
    self.keepProcessingQueue = YES;
    
    self.framesProcessingQueue = dispatch_queue_create("duocam.framesQueue", NULL);
    self.imageBufferProcessingQueue = dispatch_queue_create("duocam.imageBufferQueue", NULL);
    
    // for capturing peer's screen view to self's screen view
    self.captureSession = [[AVCaptureSession alloc] init];
    
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoOutput.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA) };
    self.videoOutput.alwaysDiscardsLateVideoFrames = YES;
    
    // setting capture output for captureSession (where the image should be shown
    [self.captureSession addOutput:self.videoOutput];
    [self.videoOutput setSampleBufferDelegate:self queue:self.framesProcessingQueue];
    
    // still image after taking the picture (I guess..
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    [self.captureSession addOutput:self.stillImageOutput];
    
    // setting captureSession input, for streaming images to peer
    /*if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        NSArray *possibleDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        AVCaptureDevice *device = [possibleDevices objectAtIndex:0];
        NSError *error = nil;
        AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
        [self.captureSession addInput:input];
    }*/
    
    // initialize peer id, session and its advertiser
    self.peerID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
    self.session = [[MCSession alloc] initWithPeer:self.peerID];
    self.session.delegate = self;
    self.advertiser = [[MCAdvertiserAssistant alloc] initWithServiceType:appServiceType discoveryInfo:nil session:self.session];
    /*
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.ownCameraView
                                                          attribute:NSLayoutAttributeWidth
                                                          relatedBy:0
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeWidth
                                                         multiplier:0.5
                                                           constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.remoteCameraView
                                                          attribute:NSLayoutAttributeWidth
                                                          relatedBy:0
                                                             toItem:self.view
                                                          attribute:NSLayoutAttributeWidth
                                                         multiplier:0.5
                                                           constant:0]];*/
    self.ownCameraView.clipsToBounds = NO;
    self.remoteCameraView.clipsToBounds = NO;
    
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMakeRotation(-M_PI/2));
    self.previewLayer.frame = self.ownCameraView.bounds; // the remote camera view will be presented here

    // add remove camera streaming view
    [self.ownCameraView.layer addSublayer:self.previewLayer];
    [self.captureSession startRunning];
    
    [self hideRemoteCameraView];
    [self drawTakePicButton];
    [self hideTakePicButton];
    
    self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self.view addGestureRecognizer:self.panRecognizer];
    
    //self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(captureImage:)];
    //[self.ownCameraView addGestureRecognizer:self.tapRecognizer];
    
    //UITapGestureRecognizer *tapGr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(captureImage:)];
    //self.remoteImageView.userInteractionEnabled = YES;
    //[self.remoteImageView addGestureRecognizer:tapGr];
    
    
    // initiailizing the alert view
    self.choosingAlertView = [[UIAlertView alloc] initWithTitle:@"Choose!" message:@"Which one is the front camera?" delegate:self cancelButtonTitle:@"This one" otherButtonTitles:nil, nil];
    
    self.isCamera = NO;
    self.shouldFlashLight = OFF;
    self.isCancel = NO;

}

- (void)viewDidAppear:(BOOL)animated {
    if (!self.connected) {
        [self hideRemoteCameraView];
        
        if (!self.isCancel) {
            [self showPeerBrowserController];
        }
    }
}

- (void)dealloc {
    [self.advertiser stop];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        self.previewLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMakeRotation(-M_PI/2));
    } else {
        self.previewLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransformMakeRotation(M_PI/2));
    }
}

#pragma mark - UI Actions

- (void)showPeerBrowserController {
    if (self.session.connectedPeers.count == 0) {
        [self.advertiser start];
        
        MCBrowserViewController *browserController = [[MCBrowserViewController alloc] initWithServiceType:appServiceType session:self.session];
        browserController.delegate = self;
        
        // should extend this to check peers as many as possible?
        browserController.minimumNumberOfPeers = 1;
        browserController.maximumNumberOfPeers = 1;
        [browserController.navigationController.navigationItem setTitle:@"Pair up!"];
        [self presentViewController:browserController animated:YES completion:NULL];
    }
}

- (void)hidePeerBrowserController {
    [self.advertiser stop];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self dismissViewControllerAnimated:YES completion:NULL];
    });
}

- (void)showRemoteCameraView {
    self.remoteImageView.hidden = NO;
    self.connectButton.hidden = YES;
}

- (void)hideRemoteCameraView {
    self.remoteImageView.hidden = YES;
    self.connectButton.hidden = NO;
}

- (void)drawTakePicButton {
    self.takePicButtonOutlet.layer.cornerRadius = 30;
    self.takePicButtonOutlet.layer.borderWidth = 1;
    self.takePicButtonOutlet.layer.borderColor = [[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:0.8] CGColor];
    self.takePicButtonOutlet.layer.backgroundColor = [[UIColor whiteColor] CGColor];
}

- (void)showTakePicButton {
    self.takePicButtonOutlet.hidden = NO;
}

- (void)hideTakePicButton {
    self.takePicButtonOutlet.hidden = YES;
}

- (IBAction)takePicButton:(UIButton *)sender {
    [self captureImage];
}

- (void)connectButtonTapped:(id)sender {
    [self showPeerBrowserController];
}

- (void)disconnectButtonTapped:(id)sender {
    [self.session disconnect];
    self.connected = NO;
    [self stopProcessingQueue];
    [self hideRemoteCameraView];
    [self hideTakePicButton];
}

- (IBAction)flashButtonTapped:(UIButton *)sender {
    if (self.isCamera) {
        if (self.shouldFlashLight == OFF) {
            self.shouldFlashLight = FLASH;
            [self.session sendData:[shouldFlash dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
            [sender setTitle:@"Flash" forState:UIControlStateNormal];
        } else if (self.shouldFlashLight == FLASH) {
            self.shouldFlashLight = ON;
            [self.session sendData:[shouldTorch dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
            [sender setTitle:@"On" forState:UIControlStateNormal];
            [self turnOnTorch];
        } else {
            self.shouldFlashLight = OFF;
            [self.session sendData:[shouldNotFlash dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
            [sender setTitle:@"Off" forState:UIControlStateNormal];
            
            [self turnOffTorch];
        }
    } else {
        [self.session sendData:[flashSignal dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataUnreliable error:nil];
        
        if (self.shouldFlashLight == OFF) {
            [sender setTitle:@"Flash" forState:UIControlStateNormal];
        } else if (self.shouldFlashLight == FLASH) {
            [sender setTitle:@"On" forState:UIControlStateNormal];
        } else {
            [sender setTitle:@"Off" forState:UIControlStateNormal];
        }
    }
}

- (BOOL)toggleFlashLight {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    if (device.torchMode == AVCaptureTorchModeOff) {
        // Start session configuration
        [self.captureSession beginConfiguration];
        [device lockForConfiguration:nil];
        
        // Set torch to on
        [device setTorchMode:AVCaptureTorchModeOn];
        
        [device unlockForConfiguration];
        [self.captureSession commitConfiguration];
        
        return YES;
    } else if (device.torchMode == AVCaptureTorchModeOn) {
        [self.captureSession beginConfiguration];
        [device lockForConfiguration:nil];
        
        // Set torch to on
        [device setTorchMode:AVCaptureTorchModeOff];
        
        [device unlockForConfiguration];
        [self.captureSession commitConfiguration];
    }
    return NO;
}

- (void)turnOnTorch {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    [self.captureSession beginConfiguration];
    [device lockForConfiguration:nil];
    
    // Set torch to on
    [device setTorchMode:AVCaptureTorchModeOn];
    
    [device unlockForConfiguration];
    [self.captureSession commitConfiguration];
}

- (void)turnOffTorch {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    [self.captureSession beginConfiguration];
    [device lockForConfiguration:nil];
    
    // Set torch to on
    [device setTorchMode:AVCaptureTorchModeOff];
    
    [device unlockForConfiguration];
    [self.captureSession commitConfiguration];
}

- (void)pan:(UIPanGestureRecognizer *)recognizer {
    UIView* view = self.view;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint location = [recognizer locationInView:view];
        if (location.x <  CGRectGetMidX(view.bounds)) {
            self.dragginLeft = YES;
            self.draggingRight = NO;
        } else {
            self.draggingRight = YES;
            self.dragginLeft = NO;
        }
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [recognizer translationInView:view];
        if (self.dragginLeft) {
            self.ownCameraView.transform = CGAffineTransformMakeTranslation(translation.x-self.initialDragStart, 0);
            self.ownImageView.transform = CGAffineTransformMakeTranslation(translation.x-self.initialDragStart, 0);
            self.remoteCameraView.transform = CGAffineTransformMakeTranslation(-translation.x+self.initialDragStart, 0);
        } else {
            self.ownCameraView.transform = CGAffineTransformMakeTranslation(-translation.x-self.initialDragStart, 0);
            self.ownImageView.transform = CGAffineTransformMakeTranslation(-translation.x-self.initialDragStart, 0);
            self.remoteCameraView.transform = CGAffineTransformMakeTranslation(translation.x+self.initialDragStart, 0);
        }
        if (self.remoteCameraView.transform.tx < 0) {
            self.ownCameraView.transform = CGAffineTransformIdentity;
            self.ownImageView.transform = CGAffineTransformIdentity;
            self.remoteCameraView.transform = CGAffineTransformIdentity;
        }
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        if (self.remoteCameraView.transform.tx > 100) {
            [self openMenu:[recognizer velocityInView:view].x];
        } else {
            [self closeMenu:[recognizer velocityInView:view].x];
        }
        self.dragginLeft = NO;
        self.draggingRight = NO;
    }
}

- (void)closeMenu:(CGFloat)velocity {
    [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.6 initialSpringVelocity:1 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.ownCameraView.transform = CGAffineTransformIdentity;
        self.remoteCameraView.transform = CGAffineTransformIdentity;
        self.ownImageView.transform = CGAffineTransformIdentity;
        self.initialDragStart = 0;
    } completion:^(BOOL finished) {
    }];
}

- (void)openMenu:(CGFloat)velocity {
    [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.6 initialSpringVelocity:1 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.ownCameraView.transform = CGAffineTransformMakeTranslation(-250, 0);
        self.ownImageView.transform = CGAffineTransformMakeTranslation(-250, 0);
        self.remoteCameraView.transform = CGAffineTransformMakeTranslation(250, 0);
        self.initialDragStart = 250;
    } completion:^(BOOL finished) {
        
    }];
}

#pragma mark - Queue Processing

- (void)startProcessingQueue {
    self.keepProcessingQueue = YES;
    
    dispatch_async(self.imageBufferProcessingQueue, ^(void) {
        useconds_t sleepTime = 40000;
        while (self.keepProcessingQueue) {
            //NSLog(@"%ld", (long)self.queue.count);
            if (self.queue.count > 20) {
                sleepTime = 20000;
            } else if (self.queue.count > 10) {
                sleepTime = 30000;
            }
            if (!self.queue.isEmpty) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    UIImage *image = [self.queue dequeue];
                    self.remoteImageView.image = image;
                });
            }
            usleep(sleepTime); // Sleep for ~1/24s
        }
    });
}

- (void)stopProcessingQueue {
    self.keepProcessingQueue = NO;
    [self.queue removeAllObjects];
}

- (void)setRemoteImage:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.remoteImageView.image = image;
    });
}

#pragma mark - Image Sending

- (void)sendImage:(UIImage *)image {
    if (self.connected && image) {
        NSData *imageData = UIImageJPEGRepresentation(image, 0.2);
        [self.session sendData:imageData toPeers:self.session.connectedPeers withMode:MCSessionSendDataUnreliable error:nil];
    }
}

#pragma mark - MCBrowserControllerDelegate

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    [self hidePeerBrowserController];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
    self.isCancel = YES;
    [self hidePeerBrowserController];
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if (state == MCSessionStateConnected && [session.connectedPeers.firstObject isEqual:peerID]) {
        self.connected = YES;
        [self hidePeerBrowserController];
        [self.choosingAlertView performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
        //[self showRemoteCameraView];
        //[self startProcessingQueue];
    } else if (state == MCSessionStateNotConnected) {
        self.connected = NO;
        [self stopProcessingQueue];
        [self hideRemoteCameraView];
        [self hideTakePicButton];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    // respond this to become the camera
    if (buttonIndex == 0) {
        // I am camera
        
        [self setUpCamera];
        [self.session sendData:[screenSignal dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
    } else if (buttonIndex == 1) {
        // I am not
        
        [self setUpScreen];
        [self.session sendData:[cameraSignal dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
    }
}

- (void)setUpCamera {
    self.isCamera = true;
    [self connectToCamera];
    [self showTakePicButton];
    [self startProcessingQueue];
}

- (void)setUpScreen {
    [self showRemoteCameraView];
    [self showTakePicButton];
    [self startProcessingQueue];
}

- (void)connectToCamera {
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        NSArray *possibleDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        AVCaptureDevice *device = [possibleDevices objectAtIndex:0];
        NSError *error = nil;
        AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
        [self.captureSession addInput:input];

        self.ownCameraView.hidden = NO;
        self.remoteCameraView.hidden = YES;
    }
}

- (void)setFlash:(AVCaptureDevice *)device {
    if ([device hasTorch] == YES) {
        self.flashButtonOutlet.hidden = NO;
    } else {
        self.flashButtonOutlet.hidden = YES;
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    UIImage *image = [UIImage imageWithData:data];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (image) {
        if (self.keepProcessingQueue) {
            [self.queue enqueue:image];
        } else if (!self.remoteCapturedImage) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self processCapturedImage:image];
            });
        }
    } else if (string) {
        if ([string isEqualToString:shutterSignal]) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self processCaptureSignal];
            });
        } else if ([string isEqualToString:unfreezeSignal]) {
            [self reset];
        } else if ([string isEqualToString:flashSignal]) {
            
            if (self.shouldFlashLight == OFF) {
                self.shouldFlashLight = FLASH;
                [self.session sendData:[shouldFlash dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
                [self.flashButtonOutlet setTitle:@"Flash" forState:UIControlStateNormal];
            } else if (self.shouldFlashLight == FLASH) {
                self.shouldFlashLight = ON;
                [self.session sendData:[shouldTorch dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
                [self.flashButtonOutlet setTitle:@"On" forState:UIControlStateNormal];
                
                [self turnOnTorch];
            } else {
                self.shouldFlashLight = OFF;
                [self.session sendData:[shouldNotFlash dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
                [self.flashButtonOutlet setTitle:@"Off" forState:UIControlStateNormal];
                
                [self turnOffTorch];
            }
        } else if ([string isEqualToString:shouldFlash]) {
            self.shouldFlashLight = FLASH;
            [self.flashButtonOutlet setTitle:@"Flash" forState:UIControlStateNormal];
        } else if ([string isEqualToString:shouldTorch]) {
            self.shouldFlashLight = ON;
            [self.flashButtonOutlet setTitle:@"On" forState:UIControlStateNormal];
        } else if ([string isEqualToString:shouldNotFlash]) {
            self.shouldFlashLight = OFF;
            [self.flashButtonOutlet setTitle:@"Off" forState:UIControlStateNormal] ;
        } else if ([string isEqualToString:cameraSignal]) {
            [self setUpCamera];
            [self.choosingAlertView dismissWithClickedButtonIndex:-1 animated:true];
        } else if ([string isEqualToString:screenSignal]) {
            [self setUpScreen];
            [self.choosingAlertView dismissWithClickedButtonIndex:-1 animated:true];
        }
    }
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"frame captured %ld", (long)self.queue.count);
    if (self.keepProcessingQueue) {
        CGImageRef imgRef = [self imageRefFromSampleBuffer:sampleBuffer];
        UIImageOrientation orientation = self.interfaceOrientation == UIInterfaceOrientationLandscapeRight ? UIImageOrientationUp | UIImageOrientationUpMirrored : UIImageOrientationDown | UIImageOrientationDownMirrored;
//        orientation |= UIImageOrientationDownMirrored;


        [self sendImage:[UIImage imageWithCGImage:imgRef scale:1.0 orientation:orientation]];
        CGImageRelease(imgRef);
    }
}

#pragma mark - Capturing Image

- (AVCaptureConnection *)getCaptureConnection {
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.stillImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
            }
        }
    }

    return videoConnection;
}

- (void)captureImage {
    if (!self.showingStillImage) {
        self.showingStillImage = YES;
        if (self.isCamera) {
            self.remoteWaitingView.hidden = NO;
            self.remoteActivityView.hidden = NO;
            [self.remoteActivityView startAnimating];
            
            [self stopProcessingQueue];
            //[self sendCaptureSignal];
            [self takeAndSendPicture];
        } else {
            [self sendCaptureSignal];
        }
    } else {
        [self sendUnfreezeSignal];
        [self reset];
    }
}

- (void)sendCaptureSignal {
    self.initiatedCapture = YES;
    [self.session sendData:[shutterSignal dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
}

- (void)takeAndSendPicture {
    NSLog(@"%@", @"going to take the pic");
    if (self.shouldFlashLight == FLASH) {
        [self turnOnTorch];
    }

    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:[self getCaptureConnection] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        //UIImageOrientation orientation = self.interfaceOrientation == UIInterfaceOrientationLandscapeRight ? UIImageOrientationUp : UIImageOrientationDown;
        UIImageOrientation sendOrientation = self.interfaceOrientation == UIInterfaceOrientationLandscapeRight ? UIImageOrientationUp | UIImageOrientationUpMirrored : UIImageOrientationDown | UIImageOrientationDownMirrored;
        
        UIImage *sendImage = [UIImage imageWithCGImage:[UIImage imageWithData:imageData].CGImage scale:2.0 orientation:sendOrientation];
        [self.session sendData:UIImageJPEGRepresentation(sendImage, 1.0) toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
        
        UIImageOrientation orientation = self.interfaceOrientation == UIInterfaceOrientationLandscapeRight ? UIImageOrientationUp : UIImageOrientationDown;
        UIImage *image = [UIImage imageWithCGImage:[UIImage imageWithData:imageData].CGImage scale:2.0 orientation:orientation];
        self.ownCapturedImage = image;
        self.ownImageView.hidden = NO;
        self.ownImageView.image = self.ownCapturedImage;
        
        if (self.shouldFlashLight != ON) {
            [self turnOffTorch];
        }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        


    }];
}

- (void)processCaptureSignal {
    self.initiatedCapture = NO;
    [self stopProcessingQueue];
    [self takeAndSendPicture];
}

- (void)processCapturedImage:(UIImage *)image {
    self.remoteCapturedImage = image;
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.showingStillImage = YES;
        if (!self.initiatedCapture) {
            self.remoteImageView.image = self.ownCapturedImage;
            self.ownImageView.image = self.remoteCapturedImage;
        } else {
            self.remoteImageView.image = self.remoteCapturedImage;
            self.ownImageView.image = self.ownCapturedImage;
        }
        self.remoteWaitingView.hidden = YES;
        self.remoteActivityView.hidden = YES;
        
        [self flash];
        
        UIImageWriteToSavedPhotosAlbum([self makeImageFromOwnScreen], nil, nil, nil);
    });
}

- (void)flash {
    UIView *whiteView = [[UIView alloc] initWithFrame:self.view.bounds];
    whiteView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:whiteView];
    
    [UIView animateWithDuration:0.25 animations: ^{
        whiteView.alpha = 0.0;
    } completion: ^(BOOL finished) {
        [whiteView removeFromSuperview];
    }];
}

- (void)sendUnfreezeSignal {
    [self.session sendData:[unfreezeSignal dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
}

#pragma mark - Save image

- (void)reset {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.ownCapturedImage = nil;
        self.remoteCapturedImage = nil;
        self.initiatedCapture = NO;
        self.showingStillImage = NO;
        
        self.ownImageView.hidden = YES;
        self.remoteWaitingView.hidden = YES;
        self.ownCameraView.frame = self.ownCameraView.frame;
        
        [self startProcessingQueue];
    });
}

/* This should be only a temporary measure - really the images should be stitched together using CoreGraphics */
- (UIImage *)makeImageFromOwnScreen {
    UIGraphicsBeginImageContext(self.view.bounds.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.view.layer renderInContext:context];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Image Utils

- (CGImageRef)imageRefFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(context);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return newImage;
}

@end
