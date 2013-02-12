//
//  XTDSPTransmitter.m
//
//  Copyright (c) 2010-2013 - Jeremy C. McDermond (NH6Z)

// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

#import "XTDSPTransmitter.h"

#import "XTDSPBlock.h"
#import "XTDSPSimpleHilbertTransform.h"
#import "XTDSPBandpassFilter.h"
#import "XTDSPRealOscillator.h"
#import "XTDSPComplexOscillator.h"
#import "XTDSPRealNoiseGenerator.h"
#import "XTDSPFixedGain.h"
#import "XTDSPAutomaticGainControl.h"
#import "XTDSPModulator.h"

@interface XTDSPTransmitter () {
    NSMutableArray *dspModules;
    
    float sampleRate;
    
    NSString *mode;
    NSDictionary *modeDict;
}

@property (readonly) XTDSPSimpleHilbertTransform *hilbert;
@property (readonly) XTDSPBandpassFilter *filter;
@property (readonly) XTDSPModulator *modulator;

@end

@implementation XTDSPTransmitter

#pragma mark - Utility functions

+(NSInvocation *)createInvocationOnTarget:(id)target selector:(SEL)selector {
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[target methodSignatureForSelector:selector]];
    
    [invocation setTarget:target];
    [invocation setSelector:selector];
    
    return invocation;
}

#pragma mark - Initialization

-(id)initWithSampleRate:(float)initialSampleRate {
    self = [super init];
    if(self) {
        sampleRate = initialSampleRate;
        
        dspModules = [NSMutableArray arrayWithCapacity:4];
        //[dspModules addObject:[[XTDSPRealNoiseGenerator alloc] initWithSampleRate:sampleRate]];
        XTDSPSimpleHilbertTransform *hil = [[XTDSPSimpleHilbertTransform alloc] initWithElements:1024 andSampleRate:sampleRate];
        hil.invert = YES;
        [dspModules addObject:hil];
        XTDSPBandpassFilter *filter = [[XTDSPBandpassFilter alloc] initWithSize:1024 sampleRate:sampleRate lowCutoff:300.0 andHighCutoff:3000.0];
        [dspModules addObject:filter];
        XTDSPFixedGain *amp = [[XTDSPFixedGain alloc] initWithSampleRate:sampleRate];
        amp.dBGain = -10;
        [dspModules addObject:amp];
        XTDSPAutomaticGainControl *alc = [[XTDSPAutomaticGainControl alloc] initWithSampleRate:sampleRate];
        alc.target = 1.2;
        alc.attack = 2;
        alc.decay = 10;
        alc.slope = 1;
        alc.maxGain = 1.0;
        alc.minGain = .00001;
        alc.currentGain = 1.0;
        alc.hangTime = 500;
        [dspModules addObject:alc];
        //[dspModules addObject:[[XTDSPAutomaticGainControl alloc] initWithSampleRate:sampleRate]];
        
        modeDict = [NSDictionary dictionaryWithObjectsAndKeys:
                    [XTDSPTransmitter createInvocationOnTarget:self selector:@selector(ssbMode:)], @"USB",
                    [XTDSPTransmitter createInvocationOnTarget:self selector:@selector(ssbMode:)], @"LSB",
                    nil];
        mode = @"USB";
    }
    return self;
}

-(void)processComplexSamples:(XTDSPBlock *)complexData {
    for(XTDSPModule *module in dspModules)
        [module performWithComplexSignal:complexData];
}

-(void)reset {
    [self.filter clearOverlap];
}

#pragma mark - Find modules on the stack

-(XTDSPBandpassFilter *)filter {
    for(XTDSPModule *module in dspModules)
        if([module isKindOfClass:[XTDSPBandpassFilter class]])
            return (XTDSPBandpassFilter *) module;
    
    return nil;
}

-(XTDSPSimpleHilbertTransform *)hilbert {
    for(XTDSPModule *module in dspModules)
        if([module isKindOfClass:[XTDSPSimpleHilbertTransform class]])
            return (XTDSPSimpleHilbertTransform *) module;
    
    return nil;
}

-(XTDSPModulator *)modulator {
    for(XTDSPModule *module in dspModules)
        if([module isKindOfClass:[XTDSPModulator class]])
            return (XTDSPModulator *) module;
    
    return nil;
}

#pragma mark - Accessors

-(NSString *) mode {
    return mode;
}

-(void)setMode:(NSString *)newMode {
    if([newMode isEqualToString:self.mode]) return;
    
    NSInvocation *method = [modeDict objectForKey:newMode];
    if(method == nil) {
        NSLog(@"Mode %@ not found\n", newMode);
        return;
    }
    
    [method setArgument:&newMode atIndex:2];
    [method invoke];
    
    mode = newMode;
}

-(NSArray *) modes {
    return modeDict.allKeys;
}

-(void)setSampleRate:(float)newSampleRate {
    NSLog(@"Changing Sample Rate in Transmitter");
	sampleRate = newSampleRate;
    
	for(XTDSPModule *module in dspModules)
		[module setSampleRate:newSampleRate];
}

-(float)sampleRate {
    return sampleRate;
}

#pragma mark - Mode Handling Functions

-(void)ssbMode:(NSString *)newMode {
    NSLog(@"Changing transmitter mode to %@", newMode);
    
    [dspModules removeObject:self.modulator];
    
    if([newMode isEqualToString:@"LSB"]) {
        self.hilbert.invert = NO;
        self.filter.highCut = -300;
        self.filter.lowCut = -3000;
    } else {
        self.hilbert.invert = YES;
        self.filter.highCut = 3000;
        self.filter.lowCut = 300;
    }
}

@end
