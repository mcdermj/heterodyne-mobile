//
//  XTUIPanadapterView.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 3/23/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface XTUIPanadapterView : UIView

@property (assign, nonatomic) float dynamicRange;
@property (assign, nonatomic) float referenceLevel;

-(void)drawFrameWithData:(NSData *)data;

@end
