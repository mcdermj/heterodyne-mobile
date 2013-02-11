//
//  XTDSPRealNoiseGenerator.m
//
// Copyright (c) 2010-2013 - Jeremy C. McDermond (NH6Z)

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

#import "XTDSPRealNoiseGenerator.h"
#import "XTDSPBlock.h"

#define MAX_RAND (pow(2, 31) - 1)

@implementation XTDSPRealNoiseGenerator

+(float)randomValueWithMean:(float) mean andStandardDeviation:(float)dev {
    float result = 0;
    
    for(int i = 0; i < 12; ++i)
        result += (double) random() / MAX_RAND;
    
    return ((result - 6.0) * dev) + mean;
}

-(void)performWithComplexSignal:(XTDSPBlock *)signal {
        
    float *realElements = [signal realElements];
    float *imagElements = [signal imaginaryElements];
    
    for(int i = 0; i < [signal blockSize]; ++i) {
        realElements[i] = [XTDSPRealNoiseGenerator randomValueWithMean:0.5 andStandardDeviation:0.29];
        imagElements[i] = 0.0;
    }
}

@end
