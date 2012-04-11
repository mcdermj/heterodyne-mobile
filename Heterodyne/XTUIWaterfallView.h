//
//  XTUIWaterfallView.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 3/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface XTUIWaterfallView : UIView

@property (nonatomic) float referenceLevel;

-(void)drawFrameWithData:(NSData *)data;

@end
