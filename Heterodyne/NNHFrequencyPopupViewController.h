//
//  NNHFrequencyPopupViewController.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/27/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NNHFrequencyPopupViewController : UIViewController

@property (nonatomic) UIPopoverController *popover;
@property (nonatomic) UIViewController *masterViewController;

-(IBAction)frequencyEntered:(id)sender;

@end
