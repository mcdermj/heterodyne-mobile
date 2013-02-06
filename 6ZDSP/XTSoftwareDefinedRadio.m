//
//  XTSoftwareDefinedRadio.m
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

// $Id: XTSoftwareDefinedRadio.m 243 2011-04-13 14:40:14Z mcdermj $

#import "XTSoftwareDefinedRadio.h"

#import <Accelerate/Accelerate.h>

#import "XTDSPReceiver.h"
#import "XTDSPSpectrumTap.h"
#import "XTDSPBlock.h"
#import "XTRingBuffer.h"
#import "XTSystemAudio.h"
#import "XTDSPTransmitter.h"

@interface XTSoftwareDefinedRadio () {
	NSMutableArray *receivers;
    NSCondition *receiverCondition;
    NSCondition *pttCondition;
    int pendingReceivers;
	
	float sampleRate;
    int audioDecimationFactor;
	
	XTDSPSpectrumTap *spectrumTap;
    
    BOOL systemAudioState;
    XTSystemAudio *audioThread;
    XTRingBuffer *audioBuffer;
    
    NSMutableData *sampleBufferData;
	DSPComplex *sampleBuffer;
    
    BOOL transmitterRunning;
    BOOL Ptt;
    BOOL resetTransmitter;
}

@end

@implementation XTSoftwareDefinedRadio

@synthesize receivers;
@synthesize outputBuffer;
@synthesize Ptt;
@synthesize transmitterBuffer;

-(id)initWithSampleRate: (float)initialSampleRate {
	self = [super init];
	if(self) {
		sampleRate = initialSampleRate;
        audioDecimationFactor = (int) (sampleRate / 48000.0f);
        NSLog(@"Audio Decimation Factor is %d\n", audioDecimationFactor);
        
        systemAudioState = NO;
		
		//sampleBufferData = [NSMutableData dataWithLength:sizeof(float) * 2048];
		sampleBufferData = [NSMutableData dataWithLength:sizeof(float) * 2048 / audioDecimationFactor];
		sampleBuffer = (DSPComplex *) [sampleBufferData mutableBytes];
				
		receivers = [NSMutableArray arrayWithCapacity:1];
        [receivers addObject:[[XTDSPReceiver alloc] initWithSampleRate:sampleRate]];
        // [receivers addObject:[[XTReceiver alloc] initWithSampleRate:sampleRate]];
		
		spectrumTap = [[XTDSPSpectrumTap alloc] initWithSampleRate: sampleRate andSize: 4096];
        
        receiverCondition = [[NSCondition alloc] init];
        pttCondition = [[NSCondition alloc] init];
        
        outputBuffer = [[XTRingBuffer alloc] initWithEntries:sizeof(float) * 2048 * 32 andName: @"output"];
        transmitterBuffer = [[XTRingBuffer alloc] initWithEntries:sizeof(float) * 2048 * 64 andName:@"transmitter"];
        
        Ptt = NO;
        resetTransmitter = NO;
	}
	return self;
}

-(void)start {
    audioBuffer = [[XTRingBuffer alloc] initWithEntries:sizeof(float) * 2048 * 32 andName: @"audio"];
    audioThread = [[XTSystemAudio alloc] initWithBuffer:audioBuffer andSampleRate: sampleRate];
    [audioThread start];
    
    [NSThread detachNewThreadSelector:@selector(transmitterLoop) toTarget:self withObject:nil];
}

-(void)stop {
    transmitterRunning = NO;
	[audioThread stop];
}

-(void)completionCallback {
    [receiverCondition lock];
    --pendingReceivers;
    [receiverCondition signal];
    [receiverCondition unlock];
}

-(void)processComplexSamples: (XTDSPBlock *)complexData {
    [spectrumTap performWithComplexSignal:complexData];
    
    [receiverCondition lock];
    
    pendingReceivers = [receivers count];
    
    for(XTDSPReceiver *receiver in receivers) 
        [receiver processComplexSamples:complexData withCompletionSelector:@selector(completionCallback) onObject:self];

    while(pendingReceivers > 0)
        [receiverCondition wait];
    
    [receiverCondition unlock];
    
    [complexData clearBlock];
    
    //  Mix the receiver signals together for audio out.
    for(XTDSPReceiver *receiver in receivers)
        vDSP_zvadd([[receiver results] signal], 1, [complexData signal], 1, [complexData signal], 1, [complexData blockSize]);
    //[[(XTReceiver *) [receivers objectAtIndex:1] results] copyTo:complexData];
    
    //  Copy signal into the audio buffer
    if(audioThread.ready == YES) {
        //vDSP_ztoc([complexData signal], 1, sampleBuffer, 2, [complexData blockSize]);
		vDSP_ztoc([complexData signal], audioDecimationFactor, sampleBuffer, 2, [complexData blockSize] / audioDecimationFactor);
		[audioBuffer put:sampleBufferData];
        [outputBuffer put:sampleBufferData];
	}
}

-(void)tapSpectrumWithRealData: (XTRealData *)spectrumData {
	[spectrumTap tapBufferWithRealData:spectrumData];
}

-(void)setSampleRate:(float)newSampleRate {
	sampleRate = newSampleRate;
    audioDecimationFactor = (int) (sampleRate / 48000.0f);
    NSLog(@"Audio Decimation Factor is %d\n", audioDecimationFactor);
    
    sampleBufferData = [NSMutableData dataWithLength:sizeof(float) * 2048 / audioDecimationFactor];
    sampleBuffer = (DSPComplex *) [sampleBufferData mutableBytes];
    
	for(XTDSPReceiver *receiver in receivers) {
		[receiver setSampleRate:newSampleRate];
	}
}

-(float)sampleRate {
    return sampleRate;
}

-(void)setTapSize:(int)elements {
    spectrumTap = [[XTDSPSpectrumTap alloc] initWithSampleRate: sampleRate andSize: elements];
}

-(int)tapSize {
    return [spectrumTap elements];
}

-(void)transmitterLoop {
    NSData *micData;
    XTDSPBlock *transmitterBlock = [XTDSPBlock dspBlockWithBlockSize:1024];
    XTDSPTransmitter *transmitter = [[XTDSPTransmitter alloc] initWithSampleRate: 48000.0f];
    NSMutableData *bufferData = [NSMutableData dataWithLength:[transmitterBlock blockSize] * sizeof(float) * 2];
    float *buffer = [bufferData mutableBytes];
    
    [NSThread setThreadPriority:1.0];
    
    transmitterRunning = YES;
    
    while(transmitterRunning) {
        [pttCondition lock];
        while(!Ptt)
            [pttCondition wait];
        
        if(resetTransmitter == YES) {
            [transmitter reset];
            resetTransmitter = NO;
        }
 
        micData = [audioThread.inputBuffer waitForSize:1024 * sizeof(float)];
        memcpy(transmitterBlock.realData.elements, micData.bytes, micData.length);
        memset(transmitterBlock.imaginaryData.elements, 0, transmitterBlock.imaginaryData.length);
        [transmitter processComplexSamples:transmitterBlock];
        
        vDSP_ztoc([transmitterBlock signal], 1, (DSPComplex *) buffer, 2, [transmitterBlock blockSize]);
        [transmitterBuffer put:bufferData];
        [pttCondition unlock];
    }
    
    NSLog(@"Transmitter thread done\n");
}

-(void)togglePtt {
    [pttCondition lock];
    Ptt = !Ptt;
    resetTransmitter = YES;
    [pttCondition signal];
    [pttCondition unlock];
}

@end
