//
//  XTDSPTransmitter.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 9/17/12.
//
//

#import "XTDSPTransmitter.h"

#import "XTDSPBlock.h"
#import "XTDSPSimpleHilbertTransform.h"
#import "XTDSPBandpassFilter.h"
#import "XTDSPRealOscillator.h"
#import "XTDSPComplexOscillator.h"
#import "XTDSPLowpassFilter.h"

@interface XTDSPTransmitter () {
    NSMutableArray *dspModules;
    
    float sampleRate;
    
    XTDSPBandpassFilter *filter;
}

@end

@implementation XTDSPTransmitter

-(id)initWithSampleRate:(float)initialSampleRate {
    self = [super init];
    if(self) {
        sampleRate = initialSampleRate;
        
        dspModules = [NSMutableArray arrayWithCapacity:2];
        XTDSPSimpleHilbertTransform *hil = [[XTDSPSimpleHilbertTransform alloc] initWithElements:1024 andSampleRate:sampleRate];
        hil.invert = YES;
        [dspModules addObject:hil];
        filter = [[XTDSPBandpassFilter alloc] initWithSize:1024 sampleRate:sampleRate lowCutoff:300.0 andHighCutoff:3000.0];
        [dspModules addObject:filter];
    }
    return self;
}

-(void)processComplexSamples:(XTDSPBlock *)complexData {
    for(XTDSPModule *module in dspModules)
        [module performWithComplexSignal:complexData];
}

-(void)reset {
    [filter clearOverlap];
}

@end
