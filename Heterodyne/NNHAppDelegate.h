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
@class XTPanadapterDataMUX;
@class UIPanadapterView;

@interface NNHAppDelegate : UIResponder <UIApplicationDelegate> {
    IBOutlet UIPanadapterView *pan;
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) XTSoftwareDefinedRadio *sdr;
@property (strong, nonatomic) NNHMetisDriver *driver;
@property (strong, nonatomic) XTPanadapterDataMUX *mux;

@end
