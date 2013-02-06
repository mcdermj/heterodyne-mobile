//
//  XTDSPRealOscillator.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 2/6/13.
//
//

#import "XTDSPRealOscillator.h"
#import "XTDSPBlock.h"

@interface XTDSPRealOscillator () {
    double frequency;
    double phase;
    double phaseAdvance;

}

@end

@implementation XTDSPRealOscillator

-(void)setFrequency:(double)newFrequency {
    frequency = newFrequency;
    phaseAdvance = 2.0 * M_PI * frequency / sampleRate;
}

-(double)frequency {
    return frequency;
}

-(void)performWithComplexSignal:(XTDSPBlock *)signal {
    
    phase = phase > 2.0 * M_PI ? phase - (2.0 * M_PI) : phase;
    phase = phase < -2.0 * M_PI ? phase + (2.0 * M_PI) : phase;
    
    float *realElements = [signal realElements];
    float *imagElements = [signal imaginaryElements];
    
    for(int i = 0; i < [signal blockSize]; ++i) {
        realElements[i] = sin(phase);
        imagElements[i] = 0;
        phase += phaseAdvance;
    }
}


@end
