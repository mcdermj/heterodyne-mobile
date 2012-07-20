//
//  OzyRingBuffer.m
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

// $Id: OzyRingBuffer.m 169 2010-11-06 00:36:49Z mcdermj $

#import "XTRingBuffer.h"

#import <mach/semaphore.h>
#import <mach/task.h>

@interface XTRingBuffer () {
    unsigned char *buffer;
    unsigned int insertIndex;
    unsigned int removeIndex;
    
    // unsigned int size;
    // unsigned int entries;
	
	NSCondition *sizeLock;
	
	NSString *name;
}

@end

@implementation XTRingBuffer

@synthesize size;
@synthesize entries;

-(id)initWithEntries: (int)_size {
	self = [super init];
	if(self) {
        buffer = malloc(_size);
        entries = insertIndex = removeIndex = 0;
        size = _size;
		
		sizeLock = [[NSCondition alloc] init];
	}
	
	return self;
}

-(id)initWithEntries: (int)_size andName: (NSString *)theName {
	self = [super init];
	if(self) {
        buffer = malloc(_size);
        entries = insertIndex = removeIndex = 0;
        size = _size;
		
		sizeLock = [[NSCondition alloc] init];
		
		name = theName;
	}
	
	return self;
}

-(void)dealloc {
    free(buffer);
}

-(unsigned int)space {
	return size - entries;
}

-(void)clear {
	@synchronized(self) {
		insertIndex = 0;
		removeIndex = 0;
        entries = 0;
	}
}

-(void)put: (NSData *) _data {
	@synchronized(self) {
		if([self space] < [_data length]) {
			NSLog(@"buffer: %@ space=%d, wanted=%d, entries=%d, length=%d\n", name, [self space], (int) [_data length], entries, size);
			return;
		}
        
        const void *dataBytes = [_data bytes];
        		
		if(insertIndex + [_data length] <= size) {  // We can fit the whole thing in one go.
            memcpy(&(buffer[insertIndex]), [_data bytes], [_data length]);            
			insertIndex += [_data length];
		} else {
			int firstFragmentLength = size - insertIndex;
			int secondFragmentLength = [_data length] - firstFragmentLength;
			
            memcpy(&(buffer[insertIndex]), [_data bytes], firstFragmentLength);
            memcpy(buffer, dataBytes + firstFragmentLength, secondFragmentLength);            
			insertIndex = secondFragmentLength;
		}
        entries += [_data length];
	}
	
	[sizeLock lock];
	[sizeLock signal];
	[sizeLock unlock];
}

-(NSData *)get: (int)_size {
	NSData *outboundData;
	
	@synchronized(self) {
		if(entries < _size) {
			NSLog(@"buffer %@ wanted=%d, have=%d\n", name, _size, entries);
			return nil;
		}
        
		if(removeIndex + _size <= size) {
            outboundData = [NSData dataWithBytes:&(buffer[removeIndex]) length:_size];
			removeIndex += _size;
		} else {
			int firstFragmentLength = size - removeIndex;
			int secondFragmentLength = _size - firstFragmentLength;
            
            NSMutableData *newData = [NSMutableData dataWithBytes:&(buffer[removeIndex]) length:firstFragmentLength];
            [newData appendBytes:buffer length:secondFragmentLength];
            outboundData = [NSData dataWithData:newData];
			
			removeIndex = secondFragmentLength;
		}
        entries -= _size;
	}
	
	return outboundData;
}

-(NSData *)waitForSize: (int) requestedSize withTimeout:(NSDate *)timeout{
	[sizeLock lock];
	while(entries < requestedSize) 
		if([sizeLock waitUntilDate:timeout] == NO) {
            [sizeLock unlock];
            //NSLog(@"Timeout expired\n", [self class], (char *) _cmd);
            return NULL;
        }
		
	[sizeLock unlock];
	return [self get: requestedSize];

}

-(NSData *)waitForSize:(int)requestedSize {
    return [self waitForSize:requestedSize withTimeout:[NSDate distantFuture]];
}

@end
