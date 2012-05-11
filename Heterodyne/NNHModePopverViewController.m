//
//  NNHModePopverViewController.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 5/11/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NNHModePopverViewController.h"
#import "NNHAppDelegate.h"
#import "XTReceiver.h"
#import "XTSoftwareDefinedRadio.h"

@interface NNHModePopverViewController () {
    XTReceiver *mainReceiver;
}

@end

@implementation NNHModePopverViewController

@synthesize masterViewController;
@synthesize popover;
@synthesize picker;

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
    NNHAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    mainReceiver = [[[delegate sdr] receivers] objectAtIndex:0];
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

#pragma mark - Picker handling
-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [[mainReceiver modes] count];
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [[mainReceiver modes] objectAtIndex:row];
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    [mainReceiver setMode:[[mainReceiver modes] objectAtIndex:row]];
}

@end
