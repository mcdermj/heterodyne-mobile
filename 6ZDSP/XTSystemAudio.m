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
#import "XTRingBuffer.h"

#import <AVFoundation/AVAudioSession.h>

#include <mach/semaphore.h>

#include <mach/mach_init.h>
#include <mach/mach_time.h>
#include <mach/thread_policy.h>

kern_return_t   thread_policy_set(
                                  thread_t                                        thread,
                                  thread_policy_flavor_t          flavor,
                                  thread_policy_t                         policy_info,
                                  mach_msg_type_number_t          count);


OSStatus audioUnitCallback (void *userData, AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
void audioRouteChangeCallback (void *userData, AudioSessionPropertyID propertyID, UInt32 propertyValueSize, const void *propertyValue);

@interface XTSystemAudio () {
    XTRingBuffer *buffer;
    
	XTAudioUnit *equalizerAudioUnit;
	XTOutputAudioUnit *defaultOutputUnit;
    
    AVAudioSession *audioSession;
    
	BOOL running;
	
	int sampleRate;
    
    NSThread *audioThread;
}

@end

@implementation XTSystemAudio

@synthesize running;
@synthesize ready;

-(id)initWithBuffer:(XTRingBuffer *) _buffer andSampleRate:(int)theSampleRate {
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
    
    struct thread_time_constraint_policy ttcpolicy;
	mach_timebase_info_data_t tTBI;
	double mult;
    
    mach_timebase_info(&tTBI);
    mult = ((double)tTBI.denom / (double)tTBI.numer) * 1000000;
    
    ttcpolicy.period = 12 * mult;
    ttcpolicy.computation = 2 * mult;
    ttcpolicy.constraint = 24 * mult;
    ttcpolicy.preemptible = 0;
    
    if((thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t) &ttcpolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT)) != KERN_SUCCESS) {
        NSLog(@" Failed to set realtime priority\n");
    } 
    
    audioSession = [AVAudioSession sharedInstance];
    
    //if([audioSession setPreferredHardwareSampleRate:(float)sampleRate error:&audioSessionError] == NO) {
    if([audioSession setPreferredHardwareSampleRate:48000.0f error:&audioSessionError] == NO) {
            
        NSLog(@"Error setting preferred sample rate: %@\n", [audioSessionError localizedDescription]);
    }
    
    audioSessionError = nil;
    if([audioSession setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError] == NO) {
        NSLog(@"Error setting audio category: %@\n", [audioSessionError localizedDescription]);
    }

	defaultOutputUnit = [XTOutputAudioUnit remoteIOAudioUnit];
	
	AURenderCallbackStruct renderCallback;
	renderCallback.inputProc = audioUnitCallback;
	renderCallback.inputProcRefCon = (__bridge_retained void *) self;
	
	errNo = [defaultOutputUnit setCallback:&renderCallback];
	if(errNo != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:errNo userInfo:nil];
		NSLog(@"Error setting callback: %@\n", [error localizedDescription]);
	}	
	
	AudioStreamBasicDescription format;
	//format.mSampleRate = (float) sampleRate;
    format.mSampleRate = 48000.0f;
	format.mFormatID = kAudioFormatLinearPCM;
	format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
	format.mBytesPerPacket = 8;
	format.mBytesPerFrame = 8;
	format.mFramesPerPacket = 1;
	format.mChannelsPerFrame = 2;
	format.mBitsPerChannel = 32;
	
	errNo = [defaultOutputUnit setInputFormat:&format];
	if(errNo != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:errNo userInfo:nil];
		NSLog(@"Error setting callback: %@\n", [error localizedDescription]);
	}
    
    static const UInt32 doChangeDefaultRoute = 1;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof(doChangeDefaultRoute), &doChangeDefaultRoute);
    
    static const AudioSessionPropertyID routeChangeID = kAudioSessionProperty_AudioRouteChange;
    
    AudioSessionAddPropertyListener(routeChangeID, audioRouteChangeCallback, (__bridge void *) self);
	
	[defaultOutputUnit setMaxFramesPerSlice:8192];
	
	[defaultOutputUnit initialize];
	[defaultOutputUnit start];	
	[buffer clear];	

	[NSThread setThreadPriority:1.0];
		
	//  You need a dummy port added to the run loop so that the thread doesn't freak out
	[[NSRunLoop currentRunLoop] addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
    
    audioSessionError = nil;
    if([audioSession setActive:YES error:&audioSessionError] == NO) {
        NSLog(@"Error activating audio session: %@\n", [audioSessionError localizedDescription]);
    }
	
	running = YES;
	while(running)
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        }
    
    ready = NO;
    [buffer clear];
	NSLog(@"Run Loop Ends\n");
}

-(void)stop {
	NSLog(@"Stopping audio thread\n");
    ready = NO;
    
    [defaultOutputUnit stop];
	[defaultOutputUnit uninitialize];
	[defaultOutputUnit dispose];
	running = NO;
    
    [audioSession setActive:NO error:NULL];
    
    while([audioThread isExecuting])
        usleep(1000);
    NSLog(@"Stop completed");
}

-(void)start {
    audioThread = [[NSThread alloc] initWithTarget:self selector:@selector(audioProcessingLoop) object:nil];
    [audioThread start];
	// [NSThread detachNewThreadSelector:@selector(audioProcessingLoop) toTarget:self withObject:nil];
}


-(void)fillAUBuffer: (AudioBuffer *) auBuffer {
    ready = YES;
    
	@autoreleasepool {
        NSData *audioBuffer = [buffer waitForSize: auBuffer->mDataByteSize withTimeout:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        if(audioBuffer == NULL) {
            NSLog(@"Couldn't get a fresh buffer.\n");
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
		
	for(int i = 0; i < ioData->mNumberBuffers; ++i) {
		[self fillAUBuffer: &(ioData->mBuffers[i])];
	}
	
	return kCVReturnSuccess;
}

void audioRouteChangeCallback (void *userData, AudioSessionPropertyID propertyID, UInt32 propertyValueSize, const void *propertyValue) {
    if(propertyID != kAudioSessionProperty_AudioRouteChange) return;
    
    NSLog(@"Audio Routing Chaged\n");
    
    XTSystemAudio *systemAudio = (__bridge_transfer XTSystemAudio *) userData;
    
    if(systemAudio.running) {
        [systemAudio stop];
        [systemAudio start];
    }
}