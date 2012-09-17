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

@interface XTDSPTransmitter () {
    NSMutableArray *dspModules;
    
    float sampleRate;
}

@end

@implementation XTDSPTransmitter

-(id)initWithSampleRate:(float)initialSampleRate {
    self = [super init];
    if(self) {
        sampleRate = initialSampleRate;
        
        dspModules = [NSMutableArray arrayWithCapacity:2];
        [dspModules addObject:[[XTDSPSimpleHilbertTransform alloc] initWithSampleRate:sampleRate]];
        [dspModules addObject:[[XTDSPBandpassFilter alloc] initWithSize:1024 sampleRate:sampleRate lowCutoff:-300.0f andHighCutoff:3000.0f]];
        
    }
    return self;
}

-(void)processComplexSamples:(XTDSPBlock *)complexData {
    for(XTDSPModule *module in dspModules)
        [module performWithComplexSignal:complexData];
}

@end
