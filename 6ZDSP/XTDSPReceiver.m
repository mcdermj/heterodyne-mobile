//
//  XTReceiver.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/19/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import "XTDSPReceiver.h"

#import "XTWorkerThread.h"
#import "XTDSPBandpassFilter.h"
#import "XTDSPModule.h"
#import "XTDSPDemodulator.h"
#import "XTDSPComplexMixer.h"
#import "XTDSPBlock.h"
#import "XTDSPComplexToRealStereo.h"
#import "XTDSPAMDemodulator.h"
#import "XTDSPFixedGain.h"

@interface XTDSPReceiver () {
    
    NSMutableArray *dspModules;
    XTWorkerThread *workerThread;
    XTDSPBlock *results;
    
    float sampleRate;
    
    NSString *mode;
    NSDictionary *modeDict;

}

@end

@implementation XTDSPReceiver

@synthesize results;

#pragma mark - Utility functions

+(NSInvocation *)createInvocationOnTarget:(id)target selector:(SEL)selector {
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[target methodSignatureForSelector:selector]];
    
    [invocation setTarget:target];
    [invocation setSelector:selector];
    
    return invocation;
}

#pragma mark - Initialization

- (id)initWithSampleRate: (float)initialSampleRate
{
    self = [super init];
    if (self) {
        sampleRate = initialSampleRate;
        
        workerThread = [[XTWorkerThread alloc] initWithRealtime:YES];
        workerThread.name = @"Receiver";
        [workerThread start];
        
        results = [XTDSPBlock dspBlockWithBlockSize:1024];
        
        dspModules = [NSMutableArray arrayWithCapacity:2];
        
        [dspModules addObject:[[XTDSPBandpassFilter alloc] initWithSize:1024
                                                             sampleRate:sampleRate
                                                              lowCutoff:-300.0f
                                                          andHighCutoff:2700.0f]];
        
        [dspModules addObject:[[XTDSPFixedGain alloc] initWithGain:4.0f]];
        
        [dspModules addObject:[[XTDSPComplexToRealStereo alloc] initWithSampleRate:sampleRate]];
        
        
        modeDict = [NSDictionary dictionaryWithObjectsAndKeys:
                    [XTDSPReceiver createInvocationOnTarget:self selector:@selector(ssbMode:)], @"USB", 
                    [XTDSPReceiver createInvocationOnTarget:self selector:@selector(ssbMode:)], @"LSB",
                    [XTDSPReceiver createInvocationOnTarget:self selector:@selector(amMode:)], @"AM",
                    nil];
        
        mode = @"USB";
    }
    
    return self;
}

#pragma mark - Find modules on the stack

-(XTDSPBandpassFilter *)filter {
    for(XTDSPModule *module in dspModules)
        if([module isKindOfClass:[XTDSPBandpassFilter class]])
            return (XTDSPBandpassFilter *) module;
    
    return nil;
}

-(XTDSPDemodulator *)demodulator {
    for(XTDSPModule *module in dspModules)
        if([module isKindOfClass:[XTDSPDemodulator class]])
            return (XTDSPDemodulator *) module;
    
    return nil;
}

-(XTDSPComplexMixer *)mixer {
    for(XTDSPModule *module in dspModules)
        if([module isKindOfClass:[XTDSPComplexMixer class]])
            return (XTDSPComplexMixer *) module;
    
    return nil;
}

-(XTDSPFixedGain *)amplifier {
    for(XTDSPModule *module in dspModules)
        if([module isKindOfClass:[XTDSPFixedGain class]])
            return (XTDSPFixedGain *) module;
    return nil;
}

#pragma mark - Accessors

-(void)setGain:(float)gain {
    self.amplifier.dBGain = gain;
}

-(float)gain {
    return self.amplifier.dBGain;
}

-(void)setHighCut: (float)highCutoff {
	[[self filter] setHighCut:highCutoff];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XTReceiverFilterDidChange" object:self];
}

-(float)highCut {
    return [[self filter] highCut];
}

-(void)setLowCut: (float)lowCutoff {
	[[self filter] setLowCut:lowCutoff];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XTReceiverFilterDidChange" object:self];
}

-(float)lowCut {
    return [[self filter] lowCut];
}

-(float)filterWidth {
    return self.filter.highCut - self.filter.lowCut;
}

-(void)setFilterWidth:(float)width {
    if([mode isEqualToString:@"USB"]) {
        self.filter.lowCut = -300;
        self.filter.highCut = width + self.filter.lowCut;
    } else if([mode isEqualToString:@"LSB"]) {
        self.filter.highCut = 300;
        self.filter.lowCut = -(width - self.filter.highCut);
    } else if([mode isEqualToString:@"AM"]) {
        self.filter.highCut = width / 2.0f;
        self.filter.lowCut = -self.filter.highCut;
    } else {
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XTReceiverFilterDidChange" object:self];

    return;
}

-(void)setFrequency:(float)frequency {
    if(frequency == 0.0) {
        [dspModules removeObject:[self mixer]];
        return;
    }
    
    if([self mixer] == nil) {
        [dspModules insertObject:[[XTDSPComplexMixer alloc] initWithSampleRate:sampleRate] atIndex:0];
    }
    
    [[self mixer] setLoFrequency:frequency];
}

-(float)frequency {
    if([self mixer] == nil) return 0.0;
    
    return [[self mixer] loFrequency];
}

-(void)setSampleRate:(float)newSampleRate {
	sampleRate = newSampleRate;
    
	for(XTDSPModule *module in dspModules) 
		[module setSampleRate:newSampleRate];
}

-(float)sampleRate {
    return sampleRate;
}

-(NSString *) mode {
    return mode;
}

-(void)setMode:(NSString *)newMode {
    if([newMode isEqualToString:self.mode]) return;
    
    NSInvocation *method = [modeDict objectForKey:newMode];
    if(method == nil) {
        NSLog(@"Mode %@ not found\n", newMode);
        return;
    }
    
    [method setArgument:&newMode atIndex:2];
    [method invoke];
    
    mode = newMode;
}

-(NSArray *) modes {
    return modeDict.allKeys;
}

#pragma mark - Mode handling functions

-(void)ssbMode:(NSString *)newMode {
    NSLog(@"Changing mode to %@\n", newMode);
    float filterWidth = self.highCut - self.lowCut;
    
    [dspModules removeObject:[self demodulator]];
    
    if([newMode isEqualToString:@"LSB"]) {
        self.highCut = 300;
        self.lowCut = -filterWidth + self.highCut;
    } else {
        self.lowCut = -300;
        self.highCut = filterWidth + self.lowCut;
    }
}

-(void)amMode:(NSString *)newMode {
    NSLog(@"Changing mode to %@\n", newMode);
    if([self demodulator]) {
        [dspModules replaceObjectAtIndex:[dspModules indexOfObject:[self demodulator]] withObject:[[XTDSPAMDemodulator alloc] initWithSampleRate:sampleRate]];
    } else {
        [dspModules insertObject:[[XTDSPAMDemodulator alloc] initWithSampleRate:sampleRate] atIndex:[dspModules indexOfObject:[self filter]]+ 1];
    }
    
    float filterWidth = self.highCut - self.lowCut;
    self.lowCut = -filterWidth;
    self.highCut = filterWidth;
}

#pragma mark - DSP Processing functions

-(void)processComplexSamples: (XTDSPBlock *)complexData withCompletionSelector:(SEL) completion onObject:(id)callbackObject {
    if([results blockSize] != [complexData blockSize])
        results = [XTDSPBlock dspBlockWithBlockSize:[complexData blockSize]];
    
    [complexData copyTo:results];
    
	for(XTDSPModule *module in dspModules)
		[module performSelector: @selector(performWithComplexSignal:) 
					   onThread: workerThread 
					 withObject: results
				  waitUntilDone: NO];
	
    [callbackObject performSelector:completion
                           onThread:workerThread
                         withObject:nil
                      waitUntilDone:NO];
}

@end
