//
//  NNHVolumePopoverViewController.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 5/11/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NNHVolumePopoverViewController.h"
#import "XTDSPReceiver.h"
#import "NNHAppDelegate.h"
#import "XTSoftwareDefinedRadio.h"

@interface NNHVolumePopoverViewController ()

@end

@implementation NNHVolumePopoverViewController

@synthesize popover;
@synthesize masterViewController;
@synthesize volumeSlider;

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
    NNHAppDelegate *delegate = (NNHAppDelegate *) [[UIApplication sharedApplication] delegate];
    XTDSPReceiver *mainReceiver = (XTDSPReceiver *) [[[delegate sdr] receivers] objectAtIndex:0];

    volumeSlider.value = mainReceiver.gain;
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

-(IBAction)sliderValueChanged:(id)sender {
    UISlider *slider = (UISlider *) sender;
    NNHAppDelegate *delegate = (NNHAppDelegate *) [[UIApplication sharedApplication] delegate];
                                                   
    XTDSPReceiver *mainReceiver = (XTDSPReceiver *) [[[delegate sdr] receivers] objectAtIndex:0];
    mainReceiver.gain = slider.value;
}

@end
