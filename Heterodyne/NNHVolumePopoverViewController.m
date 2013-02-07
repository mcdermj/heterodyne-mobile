//
//  NNHVolumePopoverViewController.m
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
