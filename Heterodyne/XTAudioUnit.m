//
//  XTAudioUnit.m
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

// $Id: XTAudioUnit.m 196 2011-03-04 08:09:25Z mcdermj $

#import "XTAudioUnit.h"

#define kOutputBus 0
#define kInputBus 1

@implementation XTAudioUnit

+(id)audioUnitWithType:(OSType)type subType:(OSType)subType andManufacturer:(OSType)manufacturer {
	return [[XTAudioUnit alloc] initWithType:type subType:subType andManufacturer:manufacturer];
}

-(id)initWithType:(OSType)type subType:(OSType)subType andManufacturer:(OSType)manufacturer {
	OSStatus errNo;

	self = [super init];
	
	if(self) {
		AudioComponentDescription componentDescription;
		AudioComponent component;
		
		componentDescription.componentType = type;
		componentDescription.componentSubType = subType;
		componentDescription.componentManufacturer = manufacturer;
		componentDescription.componentFlags = 0;
		componentDescription.componentFlagsMask = 0;

		component = AudioComponentFindNext(NULL, &componentDescription);
		errNo = AudioComponentInstanceNew(component, &theUnit);
		if(errNo != noErr) {
            NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:errNo userInfo:nil];
			NSLog(@"Error creating audio unit: %@\n", [error localizedDescription]);
        }
	}
	
	return self;
}

-(void)dispose {
	NSLog(@"Diposing of audio unit\n");
	AudioComponentInstanceDispose(theUnit);
}

-(void)initialize {
	OSStatus errNo;
	
	errNo = AudioUnitInitialize(theUnit);
	if(errNo != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:errNo userInfo:nil];
        NSLog(@"Error initializing audio unit: %@\n", [error localizedDescription]);
    }
}

-(void)uninitialize {
	OSStatus errNo;
	
	errNo = AudioUnitUninitialize(theUnit);
	if(errNo != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:errNo userInfo:nil];
		NSLog(@"Error uninitializing audio unit: %@\n", [error localizedDescription]);
	}
}


-(AudioUnit *) unit {
	return &theUnit;
}

-(OSStatus)setProperty:(AudioUnitPropertyID)property withScope:(AudioUnitScope)scope bus:(UInt32)bus andData:(NSData *)data {
	return AudioUnitSetProperty(theUnit, property, scope, bus, [data bytes], [data length]);
}

-(OSStatus)setInputFormat:(AudioStreamBasicDescription *)format {
	return [self setProperty:kAudioUnitProperty_StreamFormat withScope:kAudioUnitScope_Input bus:kOutputBus andData:[NSData dataWithBytes:format length:sizeof(AudioStreamBasicDescription)]];
}

-(OSStatus)setOutputFormat:(AudioStreamBasicDescription *)format {
    return [self setProperty:kAudioUnitProperty_StreamFormat withScope:kAudioUnitScope_Output bus:kInputBus andData:[NSData dataWithBytes:format length:sizeof(AudioStreamBasicDescription)]];
}

-(OSStatus)enableRecording {
    UInt32 flag = 1;
    
    return [self setProperty:kAudioOutputUnitProperty_EnableIO withScope:kAudioUnitScope_Input bus:kInputBus andData:[NSData dataWithBytes:&flag length:sizeof(flag)]];
}

-(OSStatus)enablePlayback {
    UInt32 flag = 1;
    
    return [self setProperty:kAudioOutputUnitProperty_EnableIO withScope:kAudioUnitScope_Output bus:kOutputBus andData:[NSData dataWithBytes:&flag length:sizeof(flag)]];
}

-(OSStatus)setMaxFramesPerSlice:(UInt32)frames {
	return [self setProperty:kAudioUnitProperty_MaximumFramesPerSlice withScope:kAudioUnitScope_Global bus:kOutputBus andData:[NSData dataWithBytes:&frames length:sizeof(frames)]];
}

-(OSStatus)setOutputCallback:(AURenderCallbackStruct *)callback {
	return [self setProperty:kAudioUnitProperty_SetRenderCallback withScope:kAudioUnitScope_Global bus:kOutputBus andData:[NSData dataWithBytes:callback length:sizeof(AURenderCallbackStruct)]];
}

-(OSStatus)setInputCallback:(AURenderCallbackStruct *)callback {
	return [self setProperty:kAudioOutputUnitProperty_SetInputCallback withScope:kAudioUnitScope_Global bus:kInputBus andData:[NSData dataWithBytes:callback length:sizeof(AURenderCallbackStruct)]];
}


@end
