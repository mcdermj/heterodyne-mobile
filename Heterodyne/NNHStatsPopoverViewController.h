//
//  NNHStatsPopoverViewController.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 7/11/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NNHStatsPopoverViewController : UIViewController

@property UIPopoverController *popover;
@property UIViewController *masterViewController;
@property IBOutlet UILabel *packetsIn;
@property IBOutlet UILabel *droppedPacketsIn;
@property IBOutlet UILabel *outOfOrderPacketsIn;
@property IBOutlet UILabel *packetsOut;
@property IBOutlet UILabel *bandwidthIn;
@property IBOutlet UILabel *bandwidthOut;
@property IBOutlet UILabel *metisVersion;
@property IBOutlet UILabel *penelopeVersion;
@property IBOutlet UILabel *mercuryVersion;

@end
