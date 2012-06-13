//
//  NNHAppDelegate.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 3/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XTSoftwareDefinedRadio;
@class NNHMetisDriver;

@interface NNHAppDelegate : UIResponder <UIApplicationDelegate> 

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) XTSoftwareDefinedRadio *sdr;
@property (strong, nonatomic) NNHMetisDriver *driver;

+(NSString *)getHardwareVersion;

@end
