//
//  SHXTouchViewController.m
//  iTouchmote
//
//  Created by Simon on 2014-05-06.
//  Copyright (c) 2014 Simon Nilsson. All rights reserved.
//

#import "SHXTouchViewController.h"
#import "F53OSC.h"

#define MAX_TOUCHES 11

@interface SHXTouchViewController ()
{
    bool touchDown;
    CGPoint firstTouchPosition;
    NSMutableDictionary *offsetTouches;
    
    NSMutableArray *allTouches;
    
    int messageId;
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
    
    offsetTouches = [NSMutableDictionary dictionary];
    allTouches = [[NSMutableArray alloc] initWithCapacity:MAX_TOUCHES];
    
    _motionManager = [[CMMotionManager alloc] init];
    [_motionManager setDeviceMotionUpdateInterval:0.01];
    
    _motionQueue = [[NSOperationQueue alloc] init];
    _motionQueue.name = @"Motion Queue";
    _motionQueue.maxConcurrentOperationCount = 1;
    
    [self startMotionUpdates];
    
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
            /*
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self.pitchLabel setText:[NSString stringWithFormat:@"%.2f",(180/M_PI)*_currentAttitude.pitch]];
                [self.rollLabel setText:[NSString stringWithFormat:@"%.2f",(180/M_PI)*_currentAttitude.roll]];
                [self.yawLabel setText:[NSString stringWithFormat:@"%.2f",(180/M_PI)*_currentAttitude.yaw]];
            }];
            */
            @synchronized([NSNumber numberWithUnsignedInteger:1337])
            {
                if(_hostService != nil)
                {
                    //NSLog(@"Sending message to %@",[theService hostName]);
                    F53OSCClient *oscClient = [[F53OSCClient alloc] init];
                    
                    NSMutableArray *allMessages = [[NSMutableArray alloc] init];
                    
                    [allMessages addObject:[[F53OSCMessage messageWithAddressPattern:@"/tmote/begin"
                                                                          arguments:@[@(messageId)]] packetData]
                    ];
                    
                    
                    [allMessages addObject:[[F53OSCMessage messageWithAddressPattern:@"/tmote/motion"
                                                                          arguments:@[@(messageId),@(_currentAttitude.pitch),@(_currentAttitude.roll),@(_currentAttitude.yaw)]] packetData]
                    ];
                    
                    @synchronized(offsetTouches)
                    {
                            [offsetTouches enumerateKeysAndObjectsUsingBlock:^void(id key, id value, BOOL *stop)
                             {
                                 int touchId = [key integerValue];
                                 CGPoint point = [value CGPointValue];
                                 [allMessages addObject:[[F53OSCMessage messageWithAddressPattern:@"/tmote/relCur"
                                                                                        arguments:@[@(messageId),@(touchId),@(point.x),@(point.y)]] packetData]
                                  ];
                             }];
                    }
                    
                    [allMessages addObject:[[F53OSCMessage messageWithAddressPattern:@"/tmote/buttons"
                                                                          arguments:@[@(messageId),@(touchDown)]] packetData]
                    ];

                    
                    [allMessages addObject:[[F53OSCMessage messageWithAddressPattern:@"/tmote/end"
                                                                          arguments:@[@(messageId)]] packetData]
                    ];
                    
                    F53OSCBundle *bundle = [[F53OSCBundle alloc] init];
                    bundle.elements = allMessages;
                    
                    [oscClient sendPacket:bundle toHost:[self.hostService hostName] onPort:[self.hostService port]];
                    
                    messageId++;
                }
            }
        }];
    }
}

-(void) stopMotionUpdates
{
    [_motionManager stopDeviceMotionUpdates];
    self.refAttitude = nil;
}

-(int) getTouchId:(UITouch *) touch
{
    int i = [allTouches indexOfObject:touch];
    
    if(i == NSNotFound)
    {
        [allTouches addObject:touch];
        i = [allTouches indexOfObject:touch];
    }
    
    return i;
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
    for(UITouch *touch in [event allTouches])
    {
        int touchId = [self getTouchId:touch];
        CGPoint location = [touch locationInView:touch.window];
        
        location.x = location.x - firstTouchPosition.x;
        location.y = location.y - firstTouchPosition.y;
        
        CGPoint point;
        point.x = location.x/touch.window.bounds.size.width;
        point.y = location.y/touch.window.bounds.size.height;
        
        @synchronized(offsetTouches)
        {
            offsetTouches[[NSNumber numberWithInt:touchId]] = [NSValue valueWithCGPoint:point];
        }
    }
}

- (IBAction)touchButtonDown:(id)sender forEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    [allTouches addObject:touch];
    CGPoint location = [touch locationInView:touch.window];
    
    firstTouchPosition = location;
    @synchronized(offsetTouches)
    {
        [offsetTouches removeAllObjects];
    }
    
    touchDown = true;
}

- (IBAction)touchButtonUp:(id)sender forEvent:(UIEvent *)event
{
    [allTouches removeAllObjects];
    @synchronized(offsetTouches)
    {
        [offsetTouches removeAllObjects];
    }
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
