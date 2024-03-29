//
//  NNHAppDelegate.m
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

#import "NNHAppDelegate.h"
#import "XTSoftwareDefinedRadio.h"
#import "NNHMetisDriver.h"
#import "XTDSPReceiver.h"
#import "NNHViewController.h"
#import "SWRevealViewController.h"
#import "TestFlight.h"

#import <Crashlytics/Crashlytics.h>
#import <AVFoundation/AVFoundation.h>

#include <sys/utsname.h>

@interface NNHAppDelegate () {
    UIAlertView *discoveryWindow;
    
    NSTimer *refreshTimer;
}

@end

@implementation NNHAppDelegate

@synthesize window = _window;
@synthesize sdr = _sdr;
@synthesize driver = _driver;

+(NSString *)getHardwareVersion {
    struct utsname u;
    uname(&u);
    
    return [NSString stringWithCString:u.machine encoding:NSASCIIStringEncoding];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    discoveryWindow = nil;
    
    [TestFlight setDeviceIdentifier:[[UIDevice currentDevice] uniqueIdentifier]];
    [TestFlight takeOff:@"240d7b94-a7d4-461c-9961-2d9a0592ab7f"];
        
    NSLog(@"Device is: %@\n", [[UIDevice currentDevice] model]);
    
    NSLog(@"Machine is: %@\n", [NNHAppDelegate getHardwareVersion]);
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    NSString *defaultsFilename = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsFilename];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    
    float sampleRate = [[NNHAppDelegate getHardwareVersion] isEqualToString:@"iPad1,1"] ? 96000.0f : 192000.0f;
    _sdr = [[XTSoftwareDefinedRadio alloc] initWithSampleRate:sampleRate];
    _driver = [[NNHMetisDriver alloc] initWithSDR:_sdr];
    XTDSPReceiver *mainReceiver = [_sdr.receivers objectAtIndex:0];
    
    [_driver setFrequency:[[NSUserDefaults standardUserDefaults] floatForKey:@"frequency"] forReceiver:0];
    _driver.preamp = [[NSUserDefaults standardUserDefaults] boolForKey:@"preamp"];
    
    mainReceiver.highCut = [[NSUserDefaults standardUserDefaults] floatForKey:@"highCut"];
    mainReceiver.lowCut = [[NSUserDefaults standardUserDefaults] floatForKey:@"LowCut"];
    mainReceiver.mode = [[NSUserDefaults standardUserDefaults] stringForKey:@"mode"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(discoveryComplete) name: @"NNHMetisDriverDidCompleteDiscovery" object: nil];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(beginDiscovery) name: @"NNHMetisDriverWillBeginDiscovery" object: nil];
    
    [_driver start];
    [_sdr start];
    
    [Crashlytics startWithAPIKey:@"5b451701f153f15de9b9741676f90fc9846e5206"];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
    
    NSLog(@"Entered background\n");
    
    XTDSPReceiver *mainReceiver = [self.sdr.receivers objectAtIndex:0];
    
    [[NSUserDefaults standardUserDefaults] setFloat:[self.driver getFrequency:0] forKey:@"frequency"];
    [[NSUserDefaults standardUserDefaults] setBool:self.driver.preamp forKey:@"preamp"];
    
    [[NSUserDefaults standardUserDefaults] setFloat:mainReceiver.highCut forKey:@"highCut"];
    [[NSUserDefaults standardUserDefaults] setFloat:mainReceiver.lowCut forKey:@"lowCut"];
    [[NSUserDefaults standardUserDefaults] setObject:mainReceiver.mode forKey:@"mode"];
    
    NNHViewController *rootController = (NNHViewController *) ((SWRevealViewController *) self.window.rootViewController).frontViewController;
    [rootController pauseDisplayLink];
    
    [self.driver stop];
    [self.sdr stop];
    
    [refreshTimer invalidate];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
    
    NSLog(@"Entering Foreground\n");
    
    XTDSPReceiver *mainReceiver = [_sdr.receivers objectAtIndex:0];
    
    [_driver setFrequency:[[NSUserDefaults standardUserDefaults] floatForKey:@"frequency"] forReceiver:0];
    _driver.preamp = [[NSUserDefaults standardUserDefaults] boolForKey:@"preamp"];
    
    mainReceiver.highCut = [[NSUserDefaults standardUserDefaults] floatForKey:@"highCut"];
    mainReceiver.lowCut = [[NSUserDefaults standardUserDefaults] floatForKey:@"LowCut"];
    mainReceiver.mode = [[NSUserDefaults standardUserDefaults] stringForKey:@"mode"];
    
    NNHViewController *rootController = (NNHViewController *) ((SWRevealViewController *) self.window.rootViewController).frontViewController;
    [rootController resumeDisplayLink];
    
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    [_driver start];
    [_sdr start];
    
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    
    discoveryWindow = [[UIAlertView alloc] initWithTitle:@"Peforming Discovery" message:@"Heterodyne is attempting to discover openHPSDR hardware on the network.\nPlease Wait." delegate:nil cancelButtonTitle:nil otherButtonTitles:nil, nil];
    [discoveryWindow show];
    
    refreshTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(updateStats) userInfo:nil repeats:YES];

    //[rootController discoveryStarted];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
    
    NSLog(@"App Terminated\n");
    
    XTDSPReceiver *mainReceiver = [self.sdr.receivers objectAtIndex:0];
    
    [[NSUserDefaults standardUserDefaults] setFloat:[self.driver getFrequency:0] forKey:@"frequency"];
    [[NSUserDefaults standardUserDefaults] setBool:self.driver.preamp forKey:@"preamp"];
    
    [[NSUserDefaults standardUserDefaults] setFloat:mainReceiver.highCut forKey:@"highCut"];
    [[NSUserDefaults standardUserDefaults] setFloat:mainReceiver.lowCut forKey:@"lowCut"];
    [[NSUserDefaults standardUserDefaults] setObject:mainReceiver.mode forKey:@"mode"];
    
    [self.driver stop];
    [self.sdr stop];
}

#pragma mark - Discovery handling

-(void)discoveryComplete {
    [self performSelectorOnMainThread:@selector(dismissDiscoveryWindow) withObject:nil waitUntilDone:NO];
}

-(void)dismissDiscoveryWindow {
    if(discoveryWindow != nil) {
        [discoveryWindow dismissWithClickedButtonIndex:0 animated:YES];
        discoveryWindow = nil;
    }
}

-(void)updateStats {
    NSLog(@"In: %lu Dropped: %lu OOO: %lu Out: %lu", self.driver.packetsIn, self.driver.droppedPacketsIn, self.driver.outOfOrderPacketsIn, self.driver.packetsOut);
}

@end
