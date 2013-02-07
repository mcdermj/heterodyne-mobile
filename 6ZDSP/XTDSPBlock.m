//
//  XTDSPBlock.m
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

#import "XTDSPBlock.h"

@interface XTDSPBlock () {
    DSPSplitComplex signal;
	int fftSize;
	FFTSetup fftSetup;
}
@end

@implementation XTDSPBlock

@synthesize blockSize;
@synthesize realData = real;
@synthesize imaginaryData = imaginary;

-(id)initWithBlockSize: (int)newBlockSize {
	self = [super init];
	if(self) {
		real = [XTRealData realDataWithElements:2 * newBlockSize];
		imaginary = [XTRealData realDataWithElements:2 * newBlockSize];
		blockSize = newBlockSize;
		
		signal.realp = [real elements];
		signal.imagp = [imaginary elements];
		
		fftSize = (int) ceilf(log2f((float) (2 * blockSize)));
		fftSetup = vDSP_create_fftsetup(fftSize, kFFTRadix2);
	}
	return self;
}

+(XTDSPBlock *)dspBlockWithBlockSize: (int)newBlockSize {
	return [[XTDSPBlock alloc] initWithBlockSize:newBlockSize];
}

-(float *)realElements {
	return [real elements];
}

-(float *)imaginaryElements {
	return [imaginary elements];
}

-(void)performFFT: (FFTDirection) direction {	
	vDSP_fft_zip(fftSetup, &signal, 1, fftSize, direction);
}

-(DSPSplitComplex *)signal {
	return &signal;
}

-(void)clearBlock {
	[real clearElements];
	[imaginary clearElements];
	
	signal.realp = [real elements];
	signal.imagp = [imaginary elements];
}

-(void)copyTo:(XTDSPBlock *)destBlock {
    [destBlock clearBlock];
    
    vDSP_zvmov(&signal, 1, [destBlock signal], 1, blockSize);
}

-(id)copyWithZone:(NSZone *)zone {
    XTDSPBlock *copy = [[[self class] allocWithZone: zone] initWithBlockSize:blockSize];
    
    [copy clearBlock];
    vDSP_zvmov(&signal, 1, [copy signal], 1, blockSize);
    
    return copy;
}

@end
