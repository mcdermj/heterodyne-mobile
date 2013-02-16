//
//  NNHFrequencyPopupViewController.m
//
//  Copyright (c) 2010-2013 - Jeremy C. McDermond (NH6Z)

// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

#import "NNHFrequencyPopupViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "XTUIKeypadView.h"
#import "NNHAppDelegate.h"
#import "NNHMetisDriver.h"
#import "XTSoftwareDefinedRadio.h"
#import "XTDSPReceiver.h"
#import "XTDSPTransmitter.h"
#import "XTUIKeypadButton.h"
#import "XTUILightedToggleButton.h"

@interface NNHFrequencyPopupViewController () {
    NNHMetisDriver *driver;
    XTDSPReceiver *mainReceiver;
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
@synthesize preampButton;

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
    preampButton.selected = driver.preamp;
    if(driver.preamp == YES)
        [self.preampButton setBackgroundColor:[UIColor redColor]];
    else
        [self.preampButton setBackgroundColor:[UIColor blackColor]];
    
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
    
    if(mainReceiver.filterWidth > filterWidth.maximumValue)
        mainReceiver.filterWidth = filterWidth.maximumValue;
    
    if(mainReceiver.filterWidth < filterWidth.minimumValue)
        mainReceiver.filterWidth = filterWidth.minimumValue;
    
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

-(IBAction)preampButtonPushed:(id)sender {
    driver.preamp = !driver.preamp;
    if(driver.preamp == YES) 
        [self.preampButton setBackgroundColor:[UIColor redColor]];
    else
        [self.preampButton setBackgroundColor:[UIColor blackColor]];
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
    NSString *mode = [[mainReceiver modes] objectAtIndex:row];
    mainReceiver.mode = mode;
    ((NNHAppDelegate *)[[UIApplication sharedApplication] delegate]).sdr.transmitter.mode = mode;
        
    [self updateFilter];
}

@end
