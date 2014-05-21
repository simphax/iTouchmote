//
//  SHXTouchViewController.m
//  iTouchmote
//
//  Created by Simon on 2014-05-06.
//  Copyright (c) 2014 Simon Nilsson. All rights reserved.
//

#import "SHXTouchViewController.h"
#import "F53OSC.h"

@interface SHXTouchViewController ()
{
    bool touchDown;
    CGPoint firstTouchPosition;
    CGPoint touchDragRelativePosition;
}

@property (strong, nonatomic) NSOperationQueue *motionQueue;

@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) CMAttitude *refAttitude;
@property (strong, nonatomic) CMAttitude *currentAttitude;

@end

@implementation SHXTouchViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSLog(@"Lets go!");
    touchDown = false;
    
    _motionManager = [[CMMotionManager alloc] init];
    [_motionManager setDeviceMotionUpdateInterval:0.01];
    
    _motionQueue = [[NSOperationQueue alloc] init];
    _motionQueue.name = @"Motion Queue";
    _motionQueue.maxConcurrentOperationCount = 1;
    
    [self startMotionUpdates];
    
}

-(void) startMotionUpdates
{
    if(![_motionManager isDeviceMotionActive])
    {
        [_motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical toQueue:_motionQueue withHandler:^void(CMDeviceMotion *motionData, NSError *error) {
            if (self.refAttitude == nil)
                [self recalibrateMotion];
            
            _currentAttitude = motionData.attitude;
            
            [_currentAttitude multiplyByInverseOfAttitude:self.refAttitude];
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self.pitchLabel setText:[NSString stringWithFormat:@"%.2f",(180/M_PI)*_currentAttitude.pitch]];
                [self.rollLabel setText:[NSString stringWithFormat:@"%.2f",(180/M_PI)*_currentAttitude.roll]];
                [self.yawLabel setText:[NSString stringWithFormat:@"%.2f",(180/M_PI)*_currentAttitude.yaw]];
            }];
            
            
            
            if(_hostService != nil)
            {
                //NSLog(@"Sending message to %@",[theService hostName]);
                F53OSCClient *oscClient = [[F53OSCClient alloc] init];
                F53OSCMessage *message =
                [F53OSCMessage messageWithAddressPattern:@"/cursor/motionData"
                                               arguments:@[@(_currentAttitude.pitch),@(_currentAttitude.roll),@(_currentAttitude.yaw),@(touchDown),@(touchDragRelativePosition.x),@(touchDragRelativePosition.y)]];
                [oscClient sendPacket:message toHost:[_hostService hostName] onPort:[_hostService port]];
            }
            
        }];
    }
}

-(void) stopMotionUpdates
{
    [_motionManager stopDeviceMotionUpdates];
    self.refAttitude = nil;
}

- (IBAction)toggleActive:(id)sender
{
    if([sender isOn])
    {
        NSLog(@"Activating motion updates");
        [self startMotionUpdates];
    }
    else
    {
        NSLog(@"Deactivating motion updates");
        [self stopMotionUpdates];
    }
}

- (IBAction)changeHost:(id)sender
{
    [_motionManager stopDeviceMotionUpdates];
    self.hostService = nil;
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)touchDragInside:(id)sender forEvent:(UIEvent *)event {
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:touch.window];
    
    location.x = location.x - firstTouchPosition.x;
    location.y = location.y - firstTouchPosition.y;
    
    touchDragRelativePosition.x = location.x/touch.window.bounds.size.width;
    touchDragRelativePosition.y = location.y/touch.window.bounds.size.height;
}

- (IBAction)touchButtonDown:(id)sender forEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:touch.window];
    
    firstTouchPosition = location;
    touchDragRelativePosition.x = 0;
    touchDragRelativePosition.y = 0;
    
    touchDown = true;
}

- (IBAction)touchButtonUp:(id)sender
{
    touchDragRelativePosition.x = 0;
    touchDragRelativePosition.y = 0;
    touchDown = false;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)recalibrateMotion
{
    self.refAttitude = self.motionManager.deviceMotion.attitude;
}

@end
