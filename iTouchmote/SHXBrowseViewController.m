//
//  SHXBrowseViewController.m
//  iTouchmote
//
//  Created by Simon on 2014-05-21.
//  Copyright (c) 2014 Simon Nilsson. All rights reserved.
//

#import "SHXBrowseViewController.h"

@interface SHXBrowseViewController ()
{
    NSMutableArray *services;
    
    int connectedService;
    
    SHXTouchViewController *touchViewController;
}

@property (strong, nonatomic) NSNetServiceBrowser *bonjourBrowser;

@end

@implementation SHXBrowseViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    services = [[NSMutableArray alloc] init];
    
    _bonjourBrowser = [[NSNetServiceBrowser alloc] init];
    _bonjourBrowser.delegate = self;
    [_bonjourBrowser searchForServicesOfType:@"_touchmote._udp."
                                    inDomain:@"local."];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) connectToService: (int) serviceIndex
{
    NSLog(@"Sending data to %i",serviceIndex);
    
    connectedService = serviceIndex;
    
}

#pragma mark NSNetServiceBrowseDelegate
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
    if(touchViewController != nil && touchViewController.hostService == netService)
    {
        touchViewController.hostService = nil;
    }
    [services removeObject:netService];
    [self.bonjourTable reloadData];
}

#pragma mark NSNetServiceDelegate
-(void)netServiceDidResolveAddress:(NSNetService *)sender
{
	NSLog(@"Service resolved. Host name: %@ Port number: %@",
          [sender hostName], [NSNumber numberWithInt:[sender port]]);
    
    [self.bonjourTable reloadData];
}

#pragma mark UITableViewDataSource
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([services count] > indexPath.row)
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"hostName"];//[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"hostName"];
        
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

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([services count] > indexPath.row)
    {
        [self connectToService:indexPath.row];
        
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        if(touchViewController == nil)
        {
            touchViewController = (SHXTouchViewController*)[sb instantiateViewControllerWithIdentifier:@"touchViewController"];
        }
        
        [touchViewController setHostService:[services objectAtIndex:connectedService]];
        touchViewController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
        [self presentViewController:touchViewController animated:YES completion:nil];
         
    }
}


#pragma mark - Navigation
/*
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    SHXTouchViewController *dest = (SHXTouchViewController*)[segue destinationViewController];
    [dest setHostService:[services objectAtIndex:connectedService]];
}
*/

@end
