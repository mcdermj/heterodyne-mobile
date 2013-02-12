//
//  NNHMicGainPopoverViewController.m
//
// Copyright (c) 2010-2013 - Jeremy C. McDermond (NH6Z)

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

#import "NNHMicGainPopoverViewController.h"
#import "NNHAppDelegate.h"
#import "XTDSPTransmitter.h"
#import "XTSoftwareDefinedRadio.h"

@implementation NNHMicGainPopoverViewController

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
    XTDSPTransmitter *transmitter = ((NNHAppDelegate *)[UIApplication sharedApplication].delegate).sdr.transmitter;
    
    volumeSlider.value = transmitter.gain;
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
    XTDSPTransmitter *transmitter = ((NNHAppDelegate *)[UIApplication sharedApplication].delegate).sdr.transmitter;

    transmitter.gain = slider.value;
}

@end
