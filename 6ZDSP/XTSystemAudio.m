//
//  XTSystemAudioThread.m
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

// $Id: XTSystemAudio.m 240 2011-04-12 13:29:38Z mcdermj $

#import "XTSystemAudio.h"
#import "XTOutputAudioUnit.h"
#import "NNHMetisDriver.h"
#import "OzyRingBuffer.h"

#import <AVFoundation/AVAudioSession.h>

#define SYSTEM_AUDIO_BUFFERS 4

#include <mach/semaphore.h>

OSStatus audioUnitCallback (void *userData, AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

@interface XTSystemAudio () {
    OzyRingBuffer *buffer;
    
	XTAudioUnit *equalizerAudioUnit;
	XTOutputAudioUnit *defaultOutputUnit;
    
    AVAudioSession *audioSession;
    
	BOOL running;
	
	int sampleRate;
}

@end

@implementation XTSystemAudio

@synthesize running;

-(id)initWithBuffer:(OzyRingBuffer *) _buffer andSampleRate:(int)theSampleRate {
	self = [super init];
	if(self) {
		buffer = _buffer;
		running = NO;
		
		sampleRate = theSampleRate;
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(newSampleRate:)
													 name:@"XTSampleRateChanged"
												   object: nil];	
        
        [[AVAudioSession sharedInstance] setDelegate:self];
	}
	
	return self;
}

-(void)audioProcessingLoop {	
	OSStatus errNo;
    NSError *audioSessionError = nil;
    
    audioSession = [AVAudioSession sharedInstance];
    [audioSession setPreferredHardwareSampleRate:(float)sampleRate error:&audioSessionError];
    [audioSession setCategory:AVAudioSessionCategorySoloAmbient error:&audioSessionError];
    [audioSession setActive:YES error:&audioSessionError];
	
	NSLog(@"Creating Audio Units\n");
	defaultOutputUnit = [XTOutputAudioUnit remoteIOAudioUnit];
	
	NSLog(@"Setting the render callback\n");
	AURenderCallbackStruct renderCallback;
	renderCallback.inputProc = audioUnitCallback;
	renderCallback.inputProcRefCon = (__bridge_retained void *) self;
	
	errNo = [defaultOutputUnit setCallback:&renderCallback];
	if(errNo != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:errNo userInfo:nil];
		NSLog(@"Error setting callback: %@\n", [error localizedDescription]);
	}	
	
	AudioStreamBasicDescription format;
	format.mSampleRate = (float) sampleRate;
	format.mFormatID = kAudioFormatLinearPCM;
	format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
	format.mBytesPerPacket = 8;
	format.mBytesPerFrame = 8;
	format.mFramesPerPacket = 1;
	format.mChannelsPerFrame = 2;
	format.mBitsPerChannel = 32;
	
	NSLog(@"Setting input format\n");
	errNo = [defaultOutputUnit setInputFormat:&format];
	if(errNo != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:errNo userInfo:nil];
		NSLog(@"Error setting callback: %@\n", [error localizedDescription]);
	}	
	
	NSLog(@"Setting up slice size\n");
	[defaultOutputUnit setMaxFramesPerSlice:8192];
	
	NSLog(@"Initializing the audio unit\n");
	[defaultOutputUnit initialize];
	NSLog(@"Starting the audio unit\n");
	[defaultOutputUnit start];	
	[buffer clear];	

	[NSThread setThreadPriority:1.0];
		
	//  You need a dummy port added to the run loop so that the thread doesn't freak out
	[[NSRunLoop currentRunLoop] addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
	
	running = YES;
	while(running == YES) 
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	
	NSLog(@"Run Loop Ends\n");
}

-(void)stop {
	NSLog(@"Stopping audio thread\n");
	[defaultOutputUnit stop];
	[defaultOutputUnit uninitialize];
	[defaultOutputUnit dispose];
    
    [audioSession setActive:NO error:NULL];
	
	running = NO;
}

-(void)start {
	[NSThread detachNewThreadSelector:@selector(audioProcessingLoop) toTarget:self withObject:nil];
}


-(void)fillAUBuffer: (AudioBuffer *) auBuffer {
	@autoreleasepool {
        NSData *audioBuffer = [buffer waitForSize: auBuffer->mDataByteSize withTimeout:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        if(audioBuffer == NULL) {
            // NSLog(@"[%@ %s]: Couldn't get a fresh buffer.\n", [self class], (char *) _cmd);
            return;
        }
	
        memcpy(auBuffer->mData, [audioBuffer bytes], [audioBuffer length]);
    }
	
	return;
}

#pragma mark - Interruption handling

-(void)beginInterruption {
    NSLog(@"Interrupting Audio\n"); 
    [self stop];
}

-(void)endInterruption {
    NSLog(@"Ending Audio\n");
    [self start];
    
}

#pragma mark - Notification Handling

-(void)newSampleRate:(NSNotification *)notification {
	NNHMetisDriver *interface = [notification object];
	
	[self setSampleRate: [interface sampleRate]];
}


#pragma mark - Accessors

-(void)setSampleRate:(int)newSampleRate {
	if(newSampleRate == sampleRate) return;
	
	sampleRate = newSampleRate;
	if(running) {
		[self stop];
		[self start];
	}
    
}

-(int)sampleRate {
    return sampleRate;
}


@end

OSStatus audioUnitCallback (void *userData, AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
	XTSystemAudio *self = (__bridge XTSystemAudio *) userData;
		
	int i;
	for(i = 0; i < ioData->mNumberBuffers; ++i) {
		[self fillAUBuffer: &(ioData->mBuffers[i])];
	}
	
	return kCVReturnSuccess;
}