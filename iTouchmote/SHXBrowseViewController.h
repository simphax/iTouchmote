//
//  SHXBrowseViewController.h
//  iTouchmote
//
//  Created by Simon on 2014-05-21.
//  Copyright (c) 2014 Simon Nilsson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SHXTouchViewController.h"

@interface SHXBrowseViewController : UIViewController <NSNetServiceBrowserDelegate, NSNetServiceDelegate, UITableViewDataSource, UITableViewDelegate>


@property (weak, nonatomic) IBOutlet UITableView *bonjourTable;

@end
