//
//  XTDSPSimpleHilbertTransform.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 9/17/12.
//
//
 
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
                realCoefficients[i] = 0;
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
