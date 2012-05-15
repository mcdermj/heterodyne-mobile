//
//  NNHAppDelegate.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 3/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NNHAppDelegate.h"
#import "XTSoftwareDefinedRadio.h"
#import "NNHMetisDriver.h"
#import "XTReceiver.h"
#import "NNHViewController.h"

@implementation NNHAppDelegate

@synthesize window = _window;
@synthesize sdr = _sdr;
@synthesize driver = _driver;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    [TestFlight takeOff:@"1e048c6ad62b04bb4e756edd399064ef_NzkzMTcyMDEyLTA0LTA5IDIyOjEwOjQ0LjM4MTE4OA"];
    [TestFlight setDeviceIdentifier:[[UIDevice currentDevice] uniqueIdentifier]];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    NSString *defaultsFilename = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsFilename];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    
    _sdr = [[XTSoftwareDefinedRadio alloc] initWithSampleRate:192000.0f];
    _driver = [[NNHMetisDriver alloc] initWithSDR:_sdr];
    XTReceiver *mainReceiver = [_sdr.receivers objectAtIndex:0];
    
    [_driver setFrequency:[[NSUserDefaults standardUserDefaults] floatForKey:@"frequency"] forReceiver:0];
    _driver.preamp = [[NSUserDefaults standardUserDefaults] boolForKey:@"preamp"];
    
    mainReceiver.highCut = [[NSUserDefaults standardUserDefaults] floatForKey:@"highCut"];
    mainReceiver.lowCut = [[NSUserDefaults standardUserDefaults] floatForKey:@"LowCut"];
    mainReceiver.mode = [[NSUserDefaults standardUserDefaults] stringForKey:@"mode"];
    
    [_driver start];
    [_sdr start];
    
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
    
    XTReceiver *mainReceiver = [self.sdr.receivers objectAtIndex:0];
    
    [[NSUserDefaults standardUserDefaults] setFloat:[self.driver getFrequency:0] forKey:@"frequency"];
    [[NSUserDefaults standardUserDefaults] setBool:self.driver.preamp forKey:@"preamp"];
    
    [[NSUserDefaults standardUserDefaults] setFloat:mainReceiver.highCut forKey:@"highCut"];
    [[NSUserDefaults standardUserDefaults] setFloat:mainReceiver.lowCut forKey:@"lowCut"];
    [[NSUserDefaults standardUserDefaults] setObject:mainReceiver.mode forKey:@"mode"];
    
    NNHViewController *rootController = (NNHViewController *) self.window.rootViewController;
    [rootController pauseDisplayLink];
    
    [self.driver stop];
    [self.sdr stop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
    
    NSLog(@"Entering Foreground\n");
    
    XTReceiver *mainReceiver = [_sdr.receivers objectAtIndex:0];
    
    [_driver setFrequency:[[NSUserDefaults standardUserDefaults] floatForKey:@"frequency"] forReceiver:0];
    _driver.preamp = [[NSUserDefaults standardUserDefaults] boolForKey:@"preamp"];
    
    mainReceiver.highCut = [[NSUserDefaults standardUserDefaults] floatForKey:@"highCut"];
    mainReceiver.lowCut = [[NSUserDefaults standardUserDefaults] floatForKey:@"LowCut"];
    mainReceiver.mode = [[NSUserDefaults standardUserDefaults] stringForKey:@"mode"];
    
    NNHViewController *rootController = (NNHViewController *) self.window.rootViewController;
    [rootController resumeDisplayLink];
    
    [_driver start];
    [_sdr start];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
    
    NSLog(@"App Terminated\n");
    
    XTReceiver *mainReceiver = [self.sdr.receivers objectAtIndex:0];
    
    [[NSUserDefaults standardUserDefaults] setFloat:[self.driver getFrequency:0] forKey:@"frequency"];
    [[NSUserDefaults standardUserDefaults] setBool:self.driver.preamp forKey:@"preamp"];
    
    [[NSUserDefaults standardUserDefaults] setFloat:mainReceiver.highCut forKey:@"highCut"];
    [[NSUserDefaults standardUserDefaults] setFloat:mainReceiver.lowCut forKey:@"lowCut"];
    [[NSUserDefaults standardUserDefaults] setObject:mainReceiver.mode forKey:@"mode"];
    
    [self.driver stop];
    [self.sdr stop];
}

@end
