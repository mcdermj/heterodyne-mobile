//
//  XTDSPAutomaticGainControl.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 7/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "XTDSPModule.h"

@interface XTDSPAutomaticGainControl : XTDSPModule

@property float attack;
@property float decay;
@property float slope;
@property float target;
@property float hangTime;
@property float maxGain;
@property float minGain;
@property float currentGain;

@end
