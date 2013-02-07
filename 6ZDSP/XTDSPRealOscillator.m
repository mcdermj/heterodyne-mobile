//
//  XTDSPRealOscillator.h
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
        realElements[i] = sin(phase) * 0.5;
        imagElements[i] = 0;
        phase += phaseAdvance;
    }
}


@end
