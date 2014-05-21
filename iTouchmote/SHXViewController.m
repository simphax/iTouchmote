//
//  SHXViewController.m
//  iTouchmote
//
//  Created by Simon on 2014-05-06.
//  Copyright (c) 2014 Simon Nilsson. All rights reserved.
//

#import "SHXViewController.h"
#import "F53OSC.h"

@interface SHXViewController ()
{
    NSMutableArray *services;
    
    int connectedService;
    bool touchDown;
}

@property (strong, nonatomic) NSNetServiceBrowser *bonjourBrowser;
@property (strong, nonatomic) NSOperationQueue *motionQueue;

@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) CMAttitude *refAttitude;
@property (strong, nonatomic) CMAttitude *currentAttitude;

@end

@implementation SHXViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSLog(@"Lets go!");
    connectedService = -1;
    touchDown = false;
    services = [[NSMutableArray alloc] init];
    

    _bonjourBrowser = [[NSNetServiceBrowser alloc] init];
    _bonjourBrowser.delegate = self;
    [_bonjourBrowser searchForServicesOfType:@"_touchmote._udp."
                                    inDomain:@"local."];
    _motionManager = [[CMMotionManager alloc] init];
    [_motionManager setDeviceMotionUpdateInterval:0.01];
    
    _motionQueue = [[NSOperationQueue alloc] init];
    _motionQueue.name = @"Motion Queue";
    _motionQueue.maxConcurrentOperationCount = 1;
    
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
        
        
        
        if(connectedService != -1)
        {
            NSNetService *theService = [services objectAtIndex:connectedService];
            
            //NSLog(@"Sending message to %@",[theService hostName]);
            F53OSCClient *oscClient = [[F53OSCClient alloc] init];
            F53OSCMessage *message =
            [F53OSCMessage messageWithAddressPattern:@"/cursor/motionData"
                                           arguments:@[@(_currentAttitude.pitch),@(_currentAttitude.roll),@(_currentAttitude.yaw),@(touchDown)]];
            [oscClient sendPacket:message toHost:[theService hostName] onPort:[theService port]];
        }
        
    }];
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing
{
    NSLog(@"Found service %@",netService);
    
    
    [netService setDelegate:self];
    [netService resolveWithTimeout:1];
    [services addObject:netService];
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing
{
    NSLog(@"Lost service %@",netService);
    
    if(connectedService == [services indexOfObject:netService])
    {
        connectedService = -1;
    }
    [services removeObject:netService];
    [self.bonjourTable reloadData];
}

-(void)netServiceDidResolveAddress:(NSNetService *)sender
{
	NSLog(@"Service resolved. Host name: %@ Port number: %@",
					[sender hostName], [NSNumber numberWithInt:[sender port]]);
    
    [self.bonjourTable reloadData];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([services count] > indexPath.row)
    {
        UITableViewCell *cell = [[UITableViewCell alloc] init];
        
        [cell.textLabel setText:[NSString stringWithFormat:@"%@",[[services objectAtIndex:indexPath.row] hostName]]];
        
        return cell;
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(section == 0)
    {
        return [services count];
    }
    return 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([services count] > indexPath.row)
    {
        [self connectToService:indexPath.row];
    }
}

- (void) connectToService: (int) serviceIndex
{
    NSLog(@"Sending data to %i",serviceIndex);
    
    connectedService = serviceIndex;
    
}
- (IBAction)touchButtonDown:(id)sender {
    touchDown = true;
}

- (IBAction)touchButtonUp:(id)sender {
    touchDown = false;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)recalibrateMotion {
    self.refAttitude = self.motionManager.deviceMotion.attitude;
}

@end
