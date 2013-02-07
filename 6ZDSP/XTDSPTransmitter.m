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
