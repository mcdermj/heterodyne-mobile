//
//  NNHFrequencyPopupViewController.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/27/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XTUIKeypadView;

@interface NNHFrequencyPopupViewController : UIViewController

@property (nonatomic) UIPopoverController *popover;
@property (nonatomic) UIViewController *masterViewController;
@property (nonatomic) IBOutlet UIPickerView *picker;
@property (nonatomic) IBOutlet UISwitch *preampSwitch;
@property (nonatomic) IBOutlet XTUIKeypadView *keypad;
@property (nonatomic) IBOutlet UISlider *filterWidth;
@property (nonatomic) IBOutlet UILabel *filterLabel;

-(IBAction)frequencyEntered:(id)sender;
-(IBAction)preampChanged:(id)sender;
-(IBAction)filterWidthChanged:(id)sender;

@end
