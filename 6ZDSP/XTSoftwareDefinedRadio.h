//
//  XTSoftwareDefinedRadio.h
//  MacHPSDR
//
//  Copyright (c) 2010 - Jeremy C. McDermond (NH6Z)

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

// $Id: XTSoftwareDefinedRadio.h 141 2010-03-18 21:19:57Z mcdermj $

#import <Accelerate/Accelerate.h>

@class XTDSPBlock;
@class XTDSPSpectrumTap;
@class XTRealData;
@class XTSystemAudio;
@class XTRingBuffer;

@interface XTSoftwareDefinedRadio : NSObject {
	
	NSMutableArray *receivers;
    NSCondition *receiverCondition;
    int pendingReceivers;
	
	float sampleRate;
	
	XTDSPSpectrumTap *spectrumTap;
    
    BOOL systemAudioState;
    XTSystemAudio *audioThread;
    XTRingBuffer *audioBuffer;
    
    NSMutableData *sampleBufferData;
	DSPComplex *sampleBuffer;
}

@property float sampleRate;
@property (readonly) NSArray *receivers;
@property (nonatomic) int tapSize;

-(id)initWithSampleRate: (float)initialSampleRate;
-(void)processComplexSamples: (XTDSPBlock *)complexData;
-(void)tapSpectrumWithRealData:(XTRealData *)spectrumData;
-(void)start;
-(void)stop;

@end
