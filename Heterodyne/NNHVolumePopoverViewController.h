//
//  NNHVolumePopoverViewController.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 5/11/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NNHVolumePopoverViewController : UIViewController

@property (nonatomic) UIPopoverController *popover;
@property (nonatomic) UIViewController *masterViewController;

-(IBAction)sliderValueChanged:(id)sender;

@end
