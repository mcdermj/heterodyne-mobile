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
#import "XTSoftwareDefinedRadio.h"
#import "XTReceiver.h"

@interface NNHFrequencyPopupViewController () {
    NNHMetisDriver *driver;
    XTReceiver *mainReceiver;
}

@end

@implementation NNHFrequencyPopupViewController

@synthesize popover = _popover;
@synthesize masterViewController = _masterViewController;
@synthesize picker;
@synthesize preampSwitch;
@synthesize keypad;
@synthesize filterWidth;
@synthesize filterLabel;

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
    driver = [delegate  driver];
    mainReceiver = [[[delegate sdr] receivers] objectAtIndex:0];

    //  Set initial values of UI
    [picker selectRow:[[mainReceiver modes] indexOfObject:[mainReceiver mode]] inComponent:0 animated:NO];
    preampSwitch.on = driver.preamp;
    
    keypad.frequency = [driver getFrequency:0];
    
    [self updateFilter];
}

-(void)updateFilter {
    if([mainReceiver.mode isEqualToString:@"USB"] || [mainReceiver.mode isEqualToString:@"LSB"]) {
        filterWidth.maximumValue = 3000.0f;
        filterWidth.minimumValue = 100.0f;
    } else if([mainReceiver.mode isEqualToString:@"AM"] || [mainReceiver.mode isEqualToString:@"SAM"]) {
        filterWidth.maximumValue = 20000.0f;
        filterWidth.minimumValue = 1000.0f;
    } else {
        filterWidth.maximumValue = 1000.0f;
        filterWidth.minimumValue = 10.0f;
    }
    
    [filterWidth setValue:mainReceiver.filterWidth animated:YES];
    
    filterLabel.text = [NSString stringWithFormat:@"%d Hz", (int) filterWidth.value];
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
    NSLog(@"Frequency entered: %f\n", keypad.frequency);
    NSLog(@"My master view controller is %@", [self.presentedViewController class]);
    [driver setFrequency:(int)keypad.frequency forReceiver:0];
}

-(IBAction)preampChanged:(id)sender {    
    [driver setPreamp:preampSwitch.on];
}

-(IBAction)filterWidthChanged:(id)sender {
    mainReceiver.filterWidth = filterWidth.value;

    [self updateFilter];
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
        
    [self updateFilter];
}

@end
