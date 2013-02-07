//
//  NNHStatsPopoverViewController.m
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

#import "NNHStatsPopoverViewController.h"

#import "NNHMetisDriver.h"
#import "NNHAppDelegate.h"

@interface NNHStatsPopoverViewController () {
    NNHMetisDriver *driver;
    NSTimer *refreshTimer;
    
    unsigned long oldPacketsIn;
    unsigned long oldDroppedPacketsIn;
    unsigned long oldOutOfOrderPacketsIn;
    unsigned long oldPacketsOut;
    unsigned long oldBytesIn;
    unsigned long oldBytesOut;
}

-(void)updateStats;

@end

@implementation NNHStatsPopoverViewController

@synthesize popover;
@synthesize masterViewController;
@synthesize packetsIn;
@synthesize droppedPacketsIn;
@synthesize outOfOrderPacketsIn;
@synthesize packetsOut;
@synthesize bandwidthIn;
@synthesize bandwidthOut;
@synthesize metisVersion;
@synthesize mercuryVersion;
@synthesize penelopeVersion;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        oldPacketsIn = 0;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    NNHAppDelegate *delegate = (NNHAppDelegate *) [[UIApplication sharedApplication] delegate];
    driver = [delegate  driver];
    
    metisVersion.text = [NSString stringWithFormat:@"%.1f", driver.ozyVersion / 10.0];
    mercuryVersion.text = [NSString stringWithFormat:@"%.1f", driver.mercuryVersion / 10.0];
    penelopeVersion.text = [NSString stringWithFormat:@"%.1f", driver.penelopeVersion / 10.0];
    
    [self updateStats];
    refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateStats) userInfo:nil repeats:YES];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

-(void)viewDidDisappear:(BOOL)animated {
    [refreshTimer invalidate];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

static const float headerScaling = 1060.0 / 1032.0;

-(void)updateStats {
    packetsIn.text = [NSString stringWithFormat:@"%lu (%lu/sec)", driver.packetsIn, driver.packetsIn - oldPacketsIn];
    oldPacketsIn = driver.packetsIn;
    
    droppedPacketsIn.text = [NSString stringWithFormat:@"%lu (%lu/sec) %.2f %%", driver.droppedPacketsIn, driver.droppedPacketsIn - oldDroppedPacketsIn, (double) driver.droppedPacketsIn / (double) driver.packetsIn];
    oldDroppedPacketsIn = driver.droppedPacketsIn;

    outOfOrderPacketsIn.text = [NSString stringWithFormat:@"%lu (%lu/sec)", driver.outOfOrderPacketsIn, driver.outOfOrderPacketsIn - oldOutOfOrderPacketsIn];
    oldOutOfOrderPacketsIn = driver.outOfOrderPacketsIn;

    packetsOut.text = [NSString stringWithFormat:@"%lu (%lu/sec)", driver.packetsOut, driver.packetsOut - oldPacketsOut];
    oldPacketsOut = driver.packetsOut;
    
    bandwidthIn.text = [NSString stringWithFormat:@"%.2f Mbps", (float) ((driver.bytesIn - oldBytesIn) * 8) / 1000000.0f * headerScaling];
    oldBytesIn = driver.bytesIn;
    
    bandwidthOut.text = [NSString stringWithFormat:@"%.2f Mbps", (float) ((driver.bytesOut - oldBytesOut) * 8) / 1000000.0f * headerScaling];
    oldBytesOut = driver.bytesOut;


}

@end
