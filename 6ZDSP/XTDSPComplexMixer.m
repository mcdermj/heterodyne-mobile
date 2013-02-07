//
//  XTDSPComplexMixer.m
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

#include <Accelerate/Accelerate.h>

#import "XTDSPComplexMixer.h"
#import "XTDSPBlock.h"
#import "XTDSPComplexOscillator.h"

@interface XTDSPComplexMixer () {
    XTDSPBlock *oscillatorBlock;
    XTDSPComplexOscillator *oscillator;
}
@end

@implementation XTDSPComplexMixer

-(id)initWithSampleRate:(float)initialSampleRate {
    self = [super initWithSampleRate:initialSampleRate];
    if(self) {
        oscillator = [[XTDSPComplexOscillator alloc] initWithSampleRate:initialSampleRate];
        oscillatorBlock = [XTDSPBlock dspBlockWithBlockSize:1024];
    }
    return self;
}

-(void)setLoFrequency:(float)frequency {
    [oscillator setFrequency:frequency];
}

-(float)loFrequency {
    return [oscillator frequency];
}

-(void)performWithComplexSignal:(XTDSPBlock *)signal {
    if([oscillatorBlock blockSize] != [signal blockSize]) 
        oscillatorBlock = [XTDSPBlock dspBlockWithBlockSize:[signal blockSize]];
    
    [oscillatorBlock clearBlock];
    [oscillator performWithComplexSignal:oscillatorBlock];
    
    vDSP_zvmul([signal signal], 1, [oscillatorBlock signal], 1, [signal signal], 1, [signal blockSize], 1);
}

@end
