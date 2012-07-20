//
//  NNHStatsPopoverViewController.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 7/11/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

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
    packetsIn.text = [NSString stringWithFormat:@"%d (%d/sec)", driver.packetsIn, driver.packetsIn - oldPacketsIn];
    oldPacketsIn = driver.packetsIn;
    
    droppedPacketsIn.text = [NSString stringWithFormat:@"%d (%d/sec) %.2f %%", driver.droppedPacketsIn, driver.droppedPacketsIn - oldDroppedPacketsIn, driver.packetsIn / driver.droppedPacketsIn];
    oldDroppedPacketsIn = driver.droppedPacketsIn;

    outOfOrderPacketsIn.text = [NSString stringWithFormat:@"%d (%d/sec)", driver.outOfOrderPacketsIn, driver.outOfOrderPacketsIn - oldOutOfOrderPacketsIn];
    oldOutOfOrderPacketsIn = driver.outOfOrderPacketsIn;

    packetsOut.text = [NSString stringWithFormat:@"%d (%d/sec)", driver.packetsOut, driver.packetsOut - oldPacketsOut];
    oldPacketsOut = driver.packetsOut;
    
    bandwidthIn.text = [NSString stringWithFormat:@"%.2f Mbps", (float) ((driver.bytesIn - oldBytesIn) * 8) / 1000000.0f * headerScaling];
    oldBytesIn = driver.bytesIn;
    
    bandwidthOut.text = [NSString stringWithFormat:@"%.2f Mbps", (float) ((driver.bytesOut - oldBytesOut) * 8) / 1000000.0f * headerScaling];
    oldBytesOut = driver.bytesOut;


}

@end
