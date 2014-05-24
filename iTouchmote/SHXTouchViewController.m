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
    
    int messageId;
    
    int smoothingSize;
    NSMutableArray *bufferYaw;
    NSMutableArray *bufferPitch;
    
    NSTimer *netSendTimer;
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
    messageId = 0;
    
    smoothingSize = 10;
    
    bufferYaw = [[NSMutableArray alloc] initWithCapacity:smoothingSize];
    bufferPitch = [[NSMutableArray alloc] initWithCapacity:smoothingSize];
    
    _motionManager = [[CMMotionManager alloc] init];
    [_motionManager setDeviceMotionUpdateInterval:0.01];
    
    _motionQueue = [[NSOperationQueue alloc] init];
    _motionQueue.name = @"Motion Queue";
    _motionQueue.maxConcurrentOperationCount = 1;
    
    [self startMotionUpdates];
    
    
}

-(void) sendFrame
{
    @synchronized([NSNumber numberWithUnsignedInteger:1337])
    {
        if(_hostService != nil)
        {
            double yaw=0, pitch=0;
            if([bufferYaw count]>0)
            {
                NSLog(@"Smoothing with %i values",[bufferYaw count]);
                //@synchronized([NSNumber numberWithUnsignedInteger:1336])
                //{
                    for (NSNumber *value in [bufferYaw copy]) {
                        yaw += value.doubleValue;
                    }
                    yaw /= [bufferYaw count];
                    
                    for (NSNumber *value in [bufferPitch copy]) {
                        pitch += value.doubleValue;
                    }
                    pitch /= [bufferPitch count];
                //}
            }
            else
            {
                NSLog(@"Smoothing buffer is empty");
                yaw = _currentAttitude.yaw;
                pitch = _currentAttitude.pitch;
            }
            
            //NSLog(@"Sending message to %@",[theService hostName]);
            F53OSCClient *oscClient = [[F53OSCClient alloc] init];
            F53OSCMessage *beginMessage =
            [F53OSCMessage messageWithAddressPattern:@"/tmote/begin"
                                           arguments:@[@(messageId)]];
            
            F53OSCMessage *motionMessage =
            [F53OSCMessage messageWithAddressPattern:@"/tmote/motion"
                                           arguments:@[@(messageId),@(pitch),@(_currentAttitude.roll),@(yaw)]];
            
            F53OSCMessage *cursorMessage =
            [F53OSCMessage messageWithAddressPattern:@"/tmote/relCur"
                                           arguments:@[@(messageId),@(0),@(touchDragRelativePosition.x),@(touchDragRelativePosition.y)]];
            
            F53OSCMessage *buttonsMessage =
            [F53OSCMessage messageWithAddressPattern:@"/tmote/buttons"
                                           arguments:@[@(messageId),@(touchDown)]];
            
            F53OSCMessage *endMessage =
            [F53OSCMessage messageWithAddressPattern:@"/tmote/end"
                                           arguments:@[@(messageId)]];
            
            F53OSCBundle *bundle = [[F53OSCBundle alloc] init];
            bundle.elements = [NSArray arrayWithObjects:[beginMessage packetData], [motionMessage packetData], [cursorMessage packetData], [buttonsMessage packetData], [endMessage packetData], nil];
            
            [oscClient sendPacket:bundle toHost:[self.hostService hostName] onPort:[self.hostService port]];
            
            messageId++;
        }
        
        [bufferYaw removeAllObjects];
        [bufferPitch removeAllObjects];
    }
}

-(void) viewDidAppear:(BOOL)animated
{
    [self startMotionUpdates];
}

-(void) viewDidDisappear:(BOOL)animated
{
    [self stopMotionUpdates];
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
            //@synchronized([NSNumber numberWithUnsignedInteger:1336])
            //{
                [bufferYaw addObject:[NSNumber numberWithDouble:_currentAttitude.yaw]];
                [bufferPitch addObject:[NSNumber numberWithDouble:_currentAttitude.pitch]];
            //}
            /*
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self.pitchLabel setText:[NSString stringWithFormat:@"%.2f",(180/M_PI)*_currentAttitude.pitch]];
                [self.rollLabel setText:[NSString stringWithFormat:@"%.2f",(180/M_PI)*_currentAttitude.roll]];
                [self.yawLabel setText:[NSString stringWithFormat:@"%.2f",(180/M_PI)*_currentAttitude.yaw]];
            }];
            */
            
        }];
    }
    if(netSendTimer != nil)
    {
        [netSendTimer invalidate];
    }
    netSendTimer = [NSTimer scheduledTimerWithTimeInterval:.02 target:self selector:@selector(sendFrame) userInfo:nil repeats:YES];
}

-(void) stopMotionUpdates
{
    if(netSendTimer != nil)
    {
        [netSendTimer invalidate];
    }
    [_motionManager stopDeviceMotionUpdates];
    [bufferYaw removeAllObjects];
    [bufferPitch removeAllObjects];
    self.refAttitude = nil;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake) {
        NSLog(@"shakieshakie");
        [self recalibrateMotion];
    }
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
    [self stopMotionUpdates];
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

- (IBAction)recalibrateMotion
{
    self.refAttitude = self.motionManager.deviceMotion.attitude;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
