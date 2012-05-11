//
//  NNHFrequencyPopupViewController.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/27/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NNHFrequencyPopupViewController.h"

#import "XTUIKeypadView.h"
#import "NNHAppDelegate.h"
#import "NNHMetisDriver.h"

@interface NNHFrequencyPopupViewController ()

@end

@implementation NNHFrequencyPopupViewController

@synthesize popover = _popover;
@synthesize masterViewController = _masterViewController;

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
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Interface actions
-(IBAction)frequencyEntered:(id)sender {
    XTUIKeypadView *keypad = (XTUIKeypadView *) sender;
    
    NSLog(@"Frequency entered: %f\n", keypad.frequency);
    NSLog(@"My master view controller is %@", [self.presentedViewController class]);
    NNHMetisDriver *driver = [(NNHAppDelegate *) [[UIApplication sharedApplication] delegate] driver];
    [driver setFrequency:(int)keypad.frequency forReceiver:0];
    [self.popover dismissPopoverAnimated:YES];
}

@end
