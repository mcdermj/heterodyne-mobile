//
//  XTDSPSimpleHilbertTransform.m
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

#import "XTDSPSimpleHilbertTransform.h"
#import "XTDSPBlackmanHarrisWindow.h"
#import "XTDSPBlock.h"

@interface XTDSPSimpleHilbertTransform () {
}

@end

@implementation XTDSPSimpleHilbertTransform

@synthesize invert;

-(id)initWithElements:(int)_size andSampleRate:(float)newSampleRate {
    self = [super initWithElements:_size andSampleRate:newSampleRate];
    if(self) {
        [self calculateCoefficients];
        invert = NO;
    }
    
    return self;
}

-(void)calculateCoefficients {
	int i;
    
	XTDSPBlackmanHarrisWindow *windowData =
    [XTDSPBlackmanHarrisWindow blackmanHarrisWindowWithElements:size];
	const float *window = [windowData bytes];
	
	@synchronized(realKernel) {
		[realKernel clearElements];
		[imaginaryKernel clearElements];
		float *realCoefficients = [realKernel elements];
		float *imaginaryCoefficients = [imaginaryKernel elements];
        
        int midpoint = size >> 1;
		
        for(i = 0; i < size; ++i) {
            if(i < midpoint) {
                realCoefficients[i] = -1;
                imaginaryCoefficients[i] = -1;
            } else if(i > midpoint) {
                realCoefficients[i] = 1;
                imaginaryCoefficients[i] = 1;
            } else {
                realCoefficients[i] = 0;
                imaginaryCoefficients[i] = 0;
            }
            
        }
        
 		//vDSP_fft_zip(fftSetup, &kernel, 1, fftSize, kFFTDirection_Forward);
 	}

}

-(void)performWithComplexSignal: (XTDSPBlock *)signal {
    [super performWithComplexSignal:signal];
    
    if(invert) {
        //  This should be for USB.  LSB can be used unchanged.
        float *imaginaryElements = [signal imaginaryElements];
        float negOne = -1;
        vDSP_vsmul(imaginaryElements, 1, &negOne, imaginaryElements, 1, [signal blockSize]);
    }
}

@end
