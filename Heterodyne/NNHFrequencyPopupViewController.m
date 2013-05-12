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
#import "XTUILightedButtonArray.h"
#import "ACVRangeSelector.h"
#import "SWRevealViewController.h"
#import "NNHViewController.h"
#import "XTUIPanadapterView.h"

@interface NNHFrequencyPopupViewController () {
    NNHMetisDriver *driver;
    XTDSPReceiver *mainReceiver;
    XTDSPTransmitter *transmitter;
}

@end

@implementation NNHFrequencyPopupViewController

@synthesize popover = _popover;
@synthesize masterViewController = _masterViewController;
@synthesize picker;
@synthesize keypad;
@synthesize filterWidth;
@synthesize filterLabel;
@synthesize preampButton;
@synthesize modeSelector;
@synthesize volumeSlider;
@synthesize micGainSlider;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void)awakeFromNib {
    NNHAppDelegate *delegate = (NNHAppDelegate *) [[UIApplication sharedApplication] delegate];
    driver = [delegate  driver];
    mainReceiver = [[[delegate sdr] receivers] objectAtIndex:0];
    transmitter = [[delegate sdr] transmitter];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    //  Set initial values of UI
    modeSelector.selected = [mainReceiver mode];
    preampButton.selected = driver.preamp;
    
    if(driver.preamp == YES)
        [self.preampButton setBackgroundColor:[UIColor redColor]];
    else
        [self.preampButton setBackgroundColor:[UIColor blackColor]];
    
    keypad.frequency = [driver getFrequency:0];
    volumeSlider.value = mainReceiver.gain;
    micGainSlider.value = transmitter.gain;
    
    [self updateFilter];
    
    
}

-(void)updateFilter {
    if([mainReceiver.mode isEqualToString:@"USB"]) {
        filterWidth.maximumValue = 5000.0f;
        filterWidth.minimumValue = -500.0f;
        mainReceiver.highCut = 2500.0f;
        mainReceiver.lowCut = -300.0f;
    } else if([mainReceiver.mode isEqualToString:@"LSB"]) {
        filterWidth.maximumValue = 500.0f;
        filterWidth.minimumValue = -5000.0f;
        mainReceiver.highCut = 300.0f;
        mainReceiver.lowCut = -2500.0f;
     } else if([mainReceiver.mode isEqualToString:@"AM"] || [mainReceiver.mode isEqualToString:@"SAM"]) {
        filterWidth.maximumValue = 20000.0f;
        filterWidth.minimumValue = -20000.0f;
         mainReceiver.highCut = 5000.0f;
         mainReceiver.lowCut = -5000.0f;
    } else {
        filterWidth.maximumValue = 1000.0f;
        filterWidth.minimumValue = 10.0f;
    }
        
    filterWidth.leftValue = mainReceiver.lowCut;
    filterWidth.rightValue = mainReceiver.highCut;
    
    filterLabel.text = [NSString stringWithFormat:@"%d Hz", (int) (filterWidth.rightValue - filterWidth.leftValue)];
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
    [driver setFrequency:(int)keypad.frequency forReceiver:0];
}

-(IBAction)filterWidthChanged:(id)sender {
    ACVRangeSelector *slider = (ACVRangeSelector *) sender;
    mainReceiver.highCut = slider.rightValue;
    mainReceiver.lowCut = slider.leftValue;
    
    filterLabel.text = [NSString stringWithFormat:@"%d Hz", (int) (filterWidth.rightValue - filterWidth.leftValue)];
}

-(IBAction)preampButtonPushed:(id)sender {
    driver.preamp = !driver.preamp;
    if(driver.preamp == YES) 
        [self.preampButton setBackgroundColor:[UIColor redColor]];
    else
        [self.preampButton setBackgroundColor:[UIColor blackColor]];
}

-(IBAction)micGainSliderChanged:(id)sender {
    UISlider *slider = (UISlider *) sender;
    
    transmitter.gain = slider.value;
}

-(IBAction)volumeSliderChanged:(id)sender {
    UISlider *slider = (UISlider *) sender;
    
    mainReceiver.gain = slider.value;
}

#pragma mark - Mode handling

-(NSArray *)contentForButtonArray:(XTUILightedButtonArray *)buttonArray {
    return [mainReceiver modes];
}

-(void)buttonPressed:(NSString *)button forArray:(XTUILightedButtonArray *)array {
    mainReceiver.mode = button;
    NNHAppDelegate *delegate = ((NNHAppDelegate *)[[UIApplication sharedApplication] delegate]);
    SWRevealViewController *rvc = (SWRevealViewController *) delegate.window.rootViewController;
    NNHViewController *mvc = (NNHViewController *) rvc.frontViewController;
    
    delegate.sdr.transmitter.mode = button;
    [self updateFilter];
}

@end
