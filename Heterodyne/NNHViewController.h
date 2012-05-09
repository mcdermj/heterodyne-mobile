//
//  NNHViewController.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 3/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XTUIPanadapterView;
@class XTUIWaterfallView;

@interface NNHViewController : UIViewController

@property (nonatomic) IBOutlet XTUIPanadapterView *panadapter;
@property (nonatomic) IBOutlet XTUIWaterfallView *waterfall;

-(IBAction)displayFrequencyControl:(id)sender;
@end
