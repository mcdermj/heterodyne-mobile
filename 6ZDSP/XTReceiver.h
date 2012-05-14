//
//  XTReceiver.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/19/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XTDSPBlock;

@interface XTReceiver : NSObject 

@property float sampleRate;
@property float frequency;
@property float highCut;
@property float lowCut;
@property float gain;
@property (readonly) XTDSPBlock *results;
@property (readonly) NSArray *modes;
@property NSString *mode;
@property float filterWidth;

-(void)processComplexSamples:(XTDSPBlock *)complexData withCompletionSelector:(SEL)completion onObject:(id)callbackObject;
-(id)initWithSampleRate:(float)sampleRate;

@end
