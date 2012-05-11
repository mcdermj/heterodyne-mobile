//
//  XTOutputAudioUnit.m
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

// $Id:$

#import "XTOutputAudioUnit.h"


@implementation XTOutputAudioUnit

-(void)start {
	OSStatus errNo;
	
	errNo = AudioOutputUnitStart(theUnit);
	if(errNo != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:errNo userInfo:nil];
		NSLog(@"Error starting output unit: %@\n",  [error localizedDescription]);
	}	
}	

-(void)stop {
	OSStatus errNo;
	
	errNo = AudioOutputUnitStop(theUnit);
	if(errNo != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:errNo userInfo:nil];
		NSLog(@"Error stopping output unit: %@\n", [error localizedDescription]);
	}	
}

+(XTOutputAudioUnit *)remoteIOAudioUnit {
	return [[XTOutputAudioUnit alloc] initWithType:kAudioUnitType_Output subType:kAudioUnitSubType_RemoteIO andManufacturer:kAudioUnitManufacturer_Apple];
}

@end
