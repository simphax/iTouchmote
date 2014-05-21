//
//  SHXViewController.h
//  iTouchmote
//
//  Created by Simon on 2014-05-06.
//  Copyright (c) 2014 Simon Nilsson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
//#import <CoreLocation/CoreLocation.h>

@interface SHXViewController : UIViewController <NSNetServiceBrowserDelegate,NSNetServiceDelegate,UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *bonjourTable;

@property (weak, nonatomic) IBOutlet UILabel *pitchLabel;
@property (weak, nonatomic) IBOutlet UILabel *rollLabel;
@property (weak, nonatomic) IBOutlet UILabel *yawLabel;

@end
