//
//  NNHMetisDriver.m
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

#import "NNHMetisDriver.h"

#import "XTSoftwareDefinedRadio.h"
#import "XTDSPBlock.h"
#import "XTBlockBuffer.h"
#import "XTRingBuffer.h"

#include <arpa/inet.h>
#include <mach/mach_init.h>
#include <mach/mach_time.h>
#include <sys/time.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>

@implementation NNHMetisDriver

@synthesize ep4Buffers;
@synthesize dither;
@synthesize random;
@synthesize tenMHzSource;
@synthesize oneTwentyTwoMHzSource;
@synthesize mercuryPresent;
@synthesize penelopePresent;
@synthesize mercuryVersion;
@synthesize ozyVersion;
@synthesize penelopeVersion;
@synthesize preamp;
@synthesize micGain;
@synthesize txGain;
@synthesize sdr;
@synthesize discoveryStatus;
@synthesize packetsIn;
@synthesize droppedPacketsIn;
@synthesize outOfOrderPacketsIn;
@synthesize packetsOut;
@synthesize bytesIn;
@synthesize bytesOut;

+(NSString *)name {
	return @"Metis Driver";
}

+(float)version {
	return 1.0;
}

+(NSString *)versionString {
	return [NSString stringWithFormat:@"%0.1f", (float) [NNHMetisDriver version]];
}

+(NSString *)IDString {
	return [NSString stringWithFormat:@"%@ v%0.1f", [NNHMetisDriver name], (float) [NNHMetisDriver version]];
}

-(void)loadParams {
	/* dither = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.dither"];
	random = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.random"];
	tenMHzSource = [[NSUserDefaults standardUserDefaults] integerForKey:@"MetisDriver.tenMHzSource"];
	oneTwentyTwoMHzSource = [[NSUserDefaults standardUserDefaults] integerForKey:@"MetisDriver.oneTwentyTwoMHzSource"];
	mercuryPresent = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.mercuryPresent"];
	penelopePresent = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.penelopePresent"];
	micGain = [[NSUserDefaults standardUserDefaults] floatForKey:@"MetisDriver.micGain"];
	txGain = [[NSUserDefaults standardUserDefaults] floatForKey:@"MetisDriver.txGain"];
    lineIn = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.lineIn"];
    micBoost = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.micBoost"];
	[self setSampleRate:[[NSUserDefaults standardUserDefaults] integerForKey:@"MetisDriver.sampleRate"]]; */
    
    dither = NO;
    random = NO;
    tenMHzSource = MERCURY;
    oneTwentyTwoMHzSource = MERCURY;
    mercuryPresent = YES;
    penelopePresent = NO;
    micGain = 0;
    txGain = 0;
    lineIn = NO;
    micBoost = NO;

    receiverFrequency[0] = 550000;
	
	
	openCollectors = 0x00;
	for (int i = 1; i < 8; ++i) {
		NSString *collectorName = [NSString stringWithFormat:@"MetisDriver.oc%d", i];
		if([[NSUserDefaults standardUserDefaults] boolForKey:collectorName] == YES) {
			openCollectors |= (UInt8) (0x01 << i);
		}
	}
}

-(id)initWithSDR:(XTSoftwareDefinedRadio *)newSdr
{
    self = [super init];

	if(self) {	
		
		mox = FALSE;
		preamp = FALSE;
		alexRxOut = FALSE;
		duplex = FALSE;
		classE = FALSE;
		
		micSource = PENELOPE;
		alexAttenuator = 0;
		alexAntenna = 0;
		alexTxRelay = 0;
		driveLevel = 0xff;
		micBoost = 0;
		
		openCollectors = 0x0;
		
		mercuryAudio = TRUE;
		
		micGain = 1.0f;
		txGain = 1.0f;
		
		stopDiscovery = NO;
		
		transmitterFrequency = receiverFrequency[0] = 0;
		
//		NSDictionary *driverDefaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"MetisDefaults" ofType:@"plist"]];

//		[[NSUserDefaults standardUserDefaults] registerDefaults:driverDefaults];
		
		ep4Buffers = [[XTBlockBuffer alloc] initWithSize:BANDSCOPE_BUFFER_SIZE quantity: 16];
				
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(loadParams) name: NSUserDefaultsDidChangeNotification object: nil];

		[self loadParams];
				
		sampleData = [NSMutableData dataWithLength:sizeof(OzySamplesOut) * 128];
		outBuffer = (OzySamplesOut *) [sampleData mutableBytes];		
		
        metisSocket = NULL;
        
		metisAddressStruct.sin_len = sizeof(metisAddressStruct);
		metisAddressStruct.sin_family = AF_INET;
		metisAddressStruct.sin_port = htons(1024);
		
		metisWriteSequence = 0;
		
		sdr = newSdr;
        
        [self setSampleRate:sdr.sampleRate];
        
        processingBlock = [XTDSPBlock dspBlockWithBlockSize:1024]; 
        
        socketServiceLoopLock = [[NSLock alloc] init];
        writeLoopLock = [[NSLock alloc] init];
 	}
	
	return self;
}

-(void)processInputBuffer:(NSData *)buffer {
	OzyPacket *currentOzyPacket;
	OzySamplesIn *inSamples;
    
    float *realSamples = [processingBlock realElements];
    float *imaginarySamples = [processingBlock imaginaryElements];
		
	MetisPacket *packet = (MetisPacket *) [buffer bytes];
	
	for(int i = 0; i < 2; ++i) {
		currentOzyPacket = &(packet->packets[i]);
		
		if(currentOzyPacket->magic[0] != SYNC || currentOzyPacket->magic[1] != SYNC || currentOzyPacket->magic[2] != SYNC) {
			NSLog(@"Invalid Ozy packet received from Metis\n");
			continue;
		}
		
		ptt = (currentOzyPacket->header[0] & 0x01) ? YES : NO;
		dash = (currentOzyPacket->header[0] & 0x02) ? YES : NO;
		dot = (currentOzyPacket->header[0] & 0x04) ? YES : NO;
		
		switch(currentOzyPacket->header[0] >> 3) {
			case 0x00:
				ADCOverflow = (currentOzyPacket->header[1] & 0x01) ? YES : NO;
				if(mercuryVersion != currentOzyPacket->header[2]) {
					[self willChangeValueForKey:@"mercuryVersion"];
					mercuryVersion = currentOzyPacket->header[2];
					[self didChangeValueForKey:@"mercuryVersion"];
				}
				if(penelopeVersion != currentOzyPacket->header[3]) {
					[self willChangeValueForKey:@"penelopeVersion"];
					penelopeVersion = currentOzyPacket->header[3];
					[self didChangeValueForKey:@"penelopeVersion"];
				}
				if(ozyVersion != currentOzyPacket->header[4]) {
					[self willChangeValueForKey:@"ozyVersion"];
					ozyVersion = currentOzyPacket->header[4];
					[self didChangeValueForKey:@"ozyVersion"];
				}
				break;
			case 0x01:
				forwardPower = (currentOzyPacket->header[1] << 8) + currentOzyPacket->header[2];
                // Alex/Apollo forward power in header[3] & header[4]
				break;
            case 0x02:
                // Reverse power from Alex/Apollo in header[1] & header[2]
                // AIN3 from Penny/Hermes in header[3] & header[4]
                break;
            case 0x03:
                //  AIN4 from Penny/Hermes in header[1] & header[2]
                //  AIN6 from Penny/Hermes in header[3] & header[4] (13.8V on Hermes)
                break;
            case 0x04:
                //  Don't know what this is yet?!
                break;
			default:
				NSLog(@"Invalid Ozy packet header: %01x\n", currentOzyPacket->header[0]);
				continue;
		}
		
		for(int j = 0; j < 63; ++j) {
			inSamples = &(currentOzyPacket->samples.in[j]);
			realSamples[samples] = (float)((signed char) inSamples->i[0] << 16 |
											   (unsigned char) inSamples->i[1] << 8 |
											   (unsigned char) inSamples->i[2]) / 8388607.0f;
			imaginarySamples[samples] = (float)((signed char) inSamples->q[0] << 16 |
												(unsigned char) inSamples->q[1] << 8 |
												(unsigned char) inSamples->q[2]) / 8388607.0f;
			leftMicBuffer[samples] = rightMicBuffer[samples] = (float)(CFSwapInt16BigToHost(inSamples->mic)) / 32767.0f * micGain;

			if(++samples == DTTSP_BUFFER_SIZE) {
                [sdr processComplexSamples:processingBlock];
				samples = 0;
			}
		}
	}
}

-(void)fillHeader:(char *)header {
	
	memset(header, 0, 5);
	
	switch(headerSequence) {
		case 0:
			if(mox) {
				header[0] = 0x01;
			} else {
				header[0] = 0x00;
			}
			
			if(sampleRate == 192000) {
				header[1] = 0x02;
			} else if(sampleRate == 96000) {
				header[1] = 0x01;
			} else {
				header[1] = 0x00;
			}
			
			if(tenMHzSource == MERCURY) {
				header[1] |= 0x08;
			} else if(tenMHzSource == PENELOPE) {
				header[1] |= 0x04;
			}
			
			if(oneTwentyTwoMHzSource == MERCURY) {
				header[1] |= 0x10;
			}
			
			if(penelopePresent) {
				header[1] |= 0x20;
			} 			
			if (mercuryPresent) {
				header[1] |= 0x40;
			}
			
			if(micSource == PENELOPE) {
				header[1] |= 0x80;
			}
			
			if(classE) {
				header[2] = 0x01;
			} else {
				header[2] = 0x00;
			}
			
			header[2] |= openCollectors;
			
			if(alexAttenuator == 10) {
				header[3] = 0x01;
			} else if(alexAttenuator == 20) {
				header[3] = 0x02;
			} else if(alexAttenuator == 30) {
				header[3] = 0x03;
			} else {
				header[3] = 0x00;
			}
			
			if(preamp) {
				header[3] |= 0x04;
			}
			
			if(dither) {
				header[3] |= 0x08;
			}
			
			if(random) {
				header[3] |= 0x10;
			}
			
			if(alexAntenna == 1) {
				header[3] |= 0x20;
			} else if(alexAntenna == 2) {
				header[3] |= 0x40;
			} else if(alexAntenna == XVERTER) {
				header[3] |= 0x60;
			}
			
			if(alexRxOut) {
				header[3] |= 0x80;
			}
			
			if(alexTxRelay == 1) {
				header[4] = 0x00;
			} else if(alexTxRelay == 2) {
				header[4] = 0x01;
			} else if(alexTxRelay == 3) {
				header[4] = 0x02;
			}
			
			if(duplex) {
				header[4] |= 0x04;
			}
			
			// handle number of receivers here
			
			++headerSequence;
			break;
		case 1:
			header[0] = 0x02;
			
			if(mox) {
				header[0] |= 0x01;
			}
			
			if(duplex == TRUE) {
				header[1] = transmitterFrequency >> 24;
				header[2] = transmitterFrequency >> 16;
				header[3] = transmitterFrequency >> 8;
				header[4] = transmitterFrequency;
				++headerSequence;
			} else {
				header[1] = receiverFrequency[0] >> 24;
				header[2] = receiverFrequency[0] >> 16;
				header[3] = receiverFrequency[0] >> 8;
				header[4] = receiverFrequency[0];
				headerSequence = 9;
			}
			break;
		case 2:
			header[0] = 0x04;
			
			if(mox) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[0] >> 24;
			header[2] = receiverFrequency[0] >> 16;
			header[3] = receiverFrequency[0] >> 8;
			header[4] = receiverFrequency[0];
			
			++headerSequence;
			break;
		case 3:
			header[0] = 0x06;
			
			if(mox) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[1] >> 24;
			header[2] = receiverFrequency[1] >> 16;
			header[3] = receiverFrequency[1] >> 8;
			header[4] = receiverFrequency[1];
			
			++headerSequence;
			break;
		case 4:
			header[0] = 0x08;
			
			if(mox) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[2] >> 24;
			header[2] = receiverFrequency[2] >> 16;
			header[3] = receiverFrequency[2] >> 8;
			header[4] = receiverFrequency[2];
			
			++headerSequence;
			break;
		case 5:
			header[0] = 0x0A;
			
			if(mox) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[3] >> 24;
			header[2] = receiverFrequency[3] >> 16;
			header[3] = receiverFrequency[3] >> 8;
			header[4] = receiverFrequency[3];
			
			++headerSequence;
			break;
		case 6:
			header[0] = 0x0C;
			
			if(mox) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[4] >> 24;
			header[2] = receiverFrequency[4] >> 16;
			header[3] = receiverFrequency[4] >> 8;
			header[4] = receiverFrequency[4];
			
			++headerSequence;
			break;
		case 7:
			header[0] = 0x0E;
			
			if(mox) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[5] >> 24;
			header[2] = receiverFrequency[5] >> 16;
			header[3] = receiverFrequency[5] >> 8;
			header[4] = receiverFrequency[5];
			
			++headerSequence;
			break;			
		case 8:
			header[0] = 0x10;
			
			if(mox) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[6] >> 24;
			header[2] = receiverFrequency[6] >> 16;
			header[3] = receiverFrequency[6] >> 8;
			header[4] = receiverFrequency[6];
			
			++headerSequence;
			break;
		case 9:
			header[0] = 0x12;
			
			if(mox) {
				header[0] |= 0x01;
			}
			
			header[1] = driveLevel;
			
			if(micBoost) {
				header[2] = 0x01;
			}
            
            if(lineIn) {
                header[2] |= 0x02;
            }
			headerSequence = 0;
	}
    
    
}

-(void)setFrequency: (int)_frequency forReceiver: (int)_receiver {
	receiverFrequency[_receiver] = _frequency;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XTFrequencyChanged" object:self];
}

-(int)getFrequency: (int)_receiver {
	return receiverFrequency[_receiver];
}

-(void)setSampleRate: (int) _sampleRate {
	if(sampleRate == _sampleRate) return;
	
	switch(_sampleRate){
		case 48000:
			sampleRate = 48000;
			break;
		case 96000:
			sampleRate = 96000;
			break;
		case 192000:
			sampleRate = 192000;
			break;
		default:
			sampleRate = 48000;
			break;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"XTSampleRateChanged" object:self];
}

-(int)sampleRate {
    return sampleRate;
}

-(void)setOpenCollectors:(UInt8)collectorSetting {
	openCollectors = collectorSetting & 0xFE;
}

-(UInt8)openCollectors {
    return openCollectors;
}

-(void)sendDiscover {
	MetisDiscoveryRequest discovery;
	int bytesWritten;
	
	discovery.magic = htons(0xEFFE);
	discovery.opcode = 0x02;
	memset(&(discovery.padding), 0, sizeof(discovery.padding));
	
	struct sockaddr_in broadcastAddressStruct;
	broadcastAddressStruct.sin_len = sizeof(broadcastAddressStruct);
	broadcastAddressStruct.sin_family = AF_INET;
	broadcastAddressStruct.sin_port = htons(1024);
	broadcastAddressStruct.sin_addr.s_addr = htonl(INADDR_BROADCAST);
	
	int yes = 1;
	if(setsockopt(metisSocket, SOL_SOCKET, SO_BROADCAST, (void *)&yes, sizeof(yes)) == -1) {
        NSLog(@"Could not set socket broadcast option: %s", strerror(errno));
    }
	
	bytesWritten = sendto(metisSocket, 
						  &discovery, 
						  sizeof(discovery), 
						  0,
						  (struct sockaddr *) &broadcastAddressStruct, 
						  sizeof(broadcastAddressStruct));
	
	if(bytesWritten == -1) {
		NSLog(@"Network Write Failed: %s\n", strerror(errno));
		return;
	}
	
	if(bytesWritten != sizeof(discovery)) {
		NSLog(@"Short write to network\n");
		return;
	}
}

-(void)kickStart {
	MetisPacket packet;
	int bytesWritten;
	
	packet.header.magic = htons(0xEFFE);
	packet.header.opcode = 0x01;
	packet.header.endpoint = 0x02;
	packet.packets[0].magic[0] = SYNC;
	packet.packets[0].magic[1] = SYNC;
	packet.packets[0].magic[2] = SYNC;
	packet.packets[1].magic[0] = SYNC;
	packet.packets[1].magic[1] = SYNC;
	packet.packets[1].magic[2] = SYNC;	
	
	for(int i = 0; i < 32; ++i) {
		packet.header.sequence = htonl(metisWriteSequence++);
		memset(packet.packets[0].samples.out, 0, sizeof(OzySamplesOut) * 63);
		memset(packet.packets[1].samples.out, 0, sizeof(OzySamplesOut) * 63);
		[self fillHeader:packet.packets[0].header];
		[self fillHeader:packet.packets[1].header];
				
		bytesWritten = send(metisSocket, 
							  &packet, 
							  sizeof(MetisPacket), 
							  0);
		
		if(bytesWritten == -1) {
			NSLog(@" Network Write Failed: %s\n", strerror(errno));
			continue;
		}
		
		if(bytesWritten != sizeof(MetisPacket)) {
			NSLog(@" Short write to network.\n");
			continue;
		}		
	}
}	

-(void)performDiscovery {
	discoveryStatus = DISCOVERY_IN_PROGRESS;
	MetisDiscoveryReply reply;
	struct sockaddr_in replyAddress;
	socklen_t replyAddressLen;
	int bytesReceived;
		
	struct timeval timeout;
	timeout.tv_sec = 1;
	timeout.tv_usec = 0;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NNHMetisDriverWillPerformDiscovery" object:self];
	
	while(setsockopt(metisSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) == -1) {
		NSLog(@"Setting receive timeout failed: %s\n", strerror(errno));
		//return NO;
	}
		
	while(discoveryStatus == DISCOVERY_IN_PROGRESS && stopDiscovery == NO) {
		char ipAddr[32];
		
		[self sendDiscover];		
		
		replyAddressLen = sizeof(replyAddress);
		bytesReceived = recvfrom(metisSocket, 
								 &reply, 
								 sizeof(reply), 
								 0, 
								 (struct sockaddr *) &replyAddress, 
								 &replyAddressLen);
		
		
		if(bytesReceived == -1) {
			if(errno == EAGAIN) {
				NSLog(@"Discovery timeout after 1 second, retrying\n");
			} else {
				NSLog(@"Network read failed: %s (%d)\n", strerror(errno), errno);
			}
			continue;
		}
		
		if(ntohs(reply.magic) == 0xEFFE && reply.status == 0x02) {
			if(replyAddress.sin_addr.s_addr == 0) {
				NSLog(@"Null IP address received\n");
				sleep(1);
				continue;
			}
			if(inet_ntop(AF_INET, &(replyAddress.sin_addr.s_addr), ipAddr, 32) == NULL) {
				NSLog(@"Could not parse IP address: %s\n", strerror(errno));
			} else {
				NSLog(@"Discovered Metis at: %s:%d\n", ipAddr, ntohs(replyAddress.sin_port));
				metisAddressStruct.sin_addr.s_addr = replyAddress.sin_addr.s_addr;
				running = YES;
				
				discoveryStatus = DISCOVERY_COMPLETE;
			}
		} else {
			if(inet_ntop(AF_INET, &(replyAddress.sin_addr.s_addr), ipAddr, 32) == NULL) {
				NSLog(@"Invalid packet from unknown IP: %s\n", strerror(errno));
			} else {				
				NSLog(@"Invalid packet received from %s magic = %#hx status = %#hhx.\n", ipAddr, reply.magic, reply.status);
			}
		}
	}
    
    if(reply.version < latestFirmware) {
        NSLog(@"Detected old firmware %d\n", reply.version);
    }
	
	timeout.tv_sec = 0;
	if(setsockopt(metisSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) == -1) {
		NSLog(@"Resetting receive timeout failed: %s\n", strerror(errno));
		return;
	}	
	
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NNHMetisDriverDidCompleteDiscovery" object:self];
    
	return;
}


-(BOOL) sendStartPacket {
    int bytesWritten;
	MetisStartStop startPacket;

	startPacket.magic = htons(0xEFFE);
	startPacket.opcode = 0x04;
	startPacket.startStop = 0x01;
	memset(&(startPacket.padding), 0, sizeof(startPacket.padding));
	   
    bytesWritten = send(metisSocket,
     &startPacket,
     sizeof(startPacket),
     0);
    
    if(bytesWritten == -1) {
		NSLog(@"Network write failed: %s\n", strerror(errno));
		return NO;
	}
	
	if(bytesWritten != sizeof(startPacket)) {
		NSLog(@"Short write to network.\n");
		return NO;
	}

    return YES;
}

-(void)discoveryComplete {
    
    int result = connect(metisSocket, (struct sockaddr *) &metisAddressStruct, sizeof(metisAddressStruct));
    if(result != 0) {
        NSLog(@"Couldn't exec connect call: %s\n", strerror(errno));
    }
    
    if([self sendStartPacket] == NO) 
        return;
    
	[self kickStart];
    [NSThread detachNewThreadSelector:@selector(socketWriteLoop) toTarget:self withObject:nil];	
	[NSThread detachNewThreadSelector:@selector(socketServiceLoop) toTarget:self withObject:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"NNHMetisDriverDidCompleteDiscovery" object:nil];
}

-(void)emptyMetisSocket {
    unsigned char garbage[1520];
    int bytesRead;
    
    if(fcntl(metisSocket, F_SETFL, O_NONBLOCK) == -1) {
        NSLog(@"Couldn't set the metis socket to nonblocking\n");
    }
        
    while((bytesRead = recvfrom(metisSocket, (void *) garbage, sizeof(garbage), 0, NULL, NULL)) > 0);
    
    if(fcntl(metisSocket, F_SETFL, 0) == -1) {
        NSLog(@"Couldn't set the metis socket to nonblocking\n");
    }
    
}

-(BOOL) start {
	
	stopDiscovery = NO;
    
    //  Find out our network interfaces so that we can find the WiFi interface
    struct ifaddrs *interfaces;
    struct sockaddr_in bindAddress;
    
    bindAddress.sin_len = sizeof(bindAddress);
    bindAddress.sin_family = AF_INET;
    bindAddress.sin_addr.s_addr = htonl(INADDR_ANY);
    
    if(getifaddrs(&interfaces)) {
        NSLog(@"Couldn't get interface list: %s\n", strerror(errno));
    }
    
    for(struct ifaddrs *iterator = interfaces; iterator->ifa_next != NULL; iterator = iterator->ifa_next) {
        struct sockaddr_in *interfaceAddress = (struct sockaddr_in *) iterator->ifa_addr;
        
        if(interfaceAddress->sin_family != AF_INET) continue;
        
        if(!strcmp("en0", iterator->ifa_name)) {
            NSLog(@"Found WiFi Interface at IP %s\n", inet_ntoa(interfaceAddress->sin_addr));
            memcpy(&bindAddress, interfaceAddress, sizeof(bindAddress));
        }
    }
    
    freeifaddrs(interfaces);
    
    bindAddress.sin_port = 0;
    
    //  Create a socket to communicate with Metis
    metisSocket = socket(PF_INET, SOCK_DGRAM, 0);
    
    int one = 1;
    if(setsockopt(metisSocket, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one)) == -1) {
        NSLog(@"Couldn't set socket to NOSIGPIPE: %s", strerror(errno));
    }
    
    if(setsockopt(metisSocket, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one)) == -1) {
        NSLog(@"Couldn't set SO_REUSEADDR: %s", strerror(errno));
    }
    
    if(bind(metisSocket, (struct sockaddr *) &bindAddress, sizeof(bindAddress)) == -1)
        NSLog(@"Couldn'g bind socket: %s\n", strerror(errno));
    
    // [self emptyMetisSocket];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(discoveryComplete) name: @"NNHMetisDriverDidCompleteDiscovery" object: nil];
    
    [NSThread detachNewThreadSelector:@selector(performDiscovery) toTarget:self withObject:nil];
	
	return YES;
}

-(BOOL) stop {
	MetisStartStop stopPacket;
	int bytesWritten;
	
	stopDiscovery = YES;
    running = NO;
    
    while(![writeLoopLock tryLock] || ![socketServiceLoopLock tryLock]);
	
	stopPacket.magic = htons(0xEFFE);
	stopPacket.opcode = 0x04;
	stopPacket.startStop = 0x00;
	memset(&(stopPacket.padding), 0, sizeof(stopPacket.padding));
	
	bytesWritten = send(metisSocket,
						  &stopPacket,
						  sizeof(stopPacket),
						  0);
	
	if(bytesWritten == -1) {
		NSLog(@"Network write failed: %s\n", strerror(errno));
		return NO;
	}
	
	if(bytesWritten != sizeof(stopPacket)) {
		NSLog(@"Short write to network.\n");
		return NO;
	}
    
    [writeLoopLock unlock];
    [socketServiceLoopLock unlock];
    
    close(metisSocket);
    
    discoveryStatus = DISCOVERY_NOT_ACTIVE;

	return YES;
}	

-(void)socketServiceLoop {
    unsigned int sequenceNumber = 0;
    
	struct thread_time_constraint_policy ttcpolicy;
	mach_timebase_info_data_t tTBI;
	double mult;
	
	struct sockaddr_in packetFromAddress;
	socklen_t addressLength;
	
	ssize_t bytesRead;
	
	mach_timebase_info(&tTBI);
	mult = ((double)tTBI.denom / (double)tTBI.numer) * 1000000;
	
	ttcpolicy.period = 12 * mult;
	ttcpolicy.computation = 2 * mult;
	ttcpolicy.constraint = 24 * mult;
	ttcpolicy.preemptible = 0;
	
	if((thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t) &ttcpolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT)) != KERN_SUCCESS) {
		NSLog(@" Failed to set realtime priority\n");
	} 
	
	struct timeval timeout;
	timeout.tv_sec = 1;
	timeout.tv_usec = 0;	
	
	if(setsockopt(metisSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) == -1) {
		NSLog(@"Resetting receive timeout failed: %s\n", strerror(errno));
	}
    
    NSMutableData *metisData = [NSMutableData dataWithLength:sizeof(MetisPacket)];
    MetisPacket *buffer = (MetisPacket *) [metisData bytes];
	
    NSLog(@"Beginning Socket Service Thread\n");
    if(![socketServiceLoopLock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:5.0]]) {
        NSLog(@"Timeout acquiring thread lock\n");
        return;
    }
    
	while(running == YES) {
				
		bytesRead = recvfrom(metisSocket, 
							 (void *) buffer, 
							 sizeof(MetisPacket), 
							 0, 
							 (struct sockaddr *) &packetFromAddress, 
							 &addressLength);
		
		if(bytesRead == -1) {
			if(errno == EAGAIN) {
				NSLog(@"No data from Metis in 1 second, retrying\n");
                if(running) {
                    [self sendStartPacket];
                    [self kickStart];
                }
			} else {
				NSLog(@"Network Read Failed: %s\n", strerror(errno));
			}
			continue;
		}
        
        bytesIn += bytesRead;
		
		if(bytesRead != sizeof(MetisPacket)) {
			NSLog(@"Short read from network.\n");
			continue;
        }
        
        ++packetsIn;
        
		if(ntohs(buffer->header.magic) == 0xEFFE) {
            buffer->header.sequence = CFSwapInt32BigToHost(buffer->header.sequence);
            if(sequenceNumber == 0)
                sequenceNumber = buffer->header.sequence;
            
            if(buffer->header.sequence < sequenceNumber) {
                //NSLog(@"Out of order packet.  Expected sequence %u, got %u\n", sequenceNumber, buffer->header.sequence);
                ++outOfOrderPacketsIn;
                continue;
            } else if(buffer->header.sequence > sequenceNumber) {
                //NSLog(@"Skipped packet. Expected sequence %u, got %u\n", sequenceNumber, buffer->header.sequence);
                droppedPacketsIn += buffer->header.sequence - sequenceNumber;
                sequenceNumber = buffer->header.sequence;
            }
            
            ++sequenceNumber;
            
			switch(buffer->header.endpoint) {
				case 6:
					[self processInputBuffer:metisData];
					break;
                default:
                    NSLog(@"Received packet for invalid endpoint %d\n", buffer->header.endpoint);
			}
		} else {
			NSLog(@"Invalid packet received: %@\n", metisData);
		}
	}
    [socketServiceLoopLock unlock];
    NSLog(@"Socket service loop ending\n");
}

-(void)socketWriteLoop {
	struct thread_time_constraint_policy ttcpolicy;
	mach_timebase_info_data_t tTBI;
	double mult;
	NSMutableData *packetData = [NSMutableData dataWithLength:sizeof(MetisPacket)];
	MetisPacket *packet = (MetisPacket *) [packetData mutableBytes];
    
	NSData *bufferData;
    NSData *transmitterData = nil;
    
	int bytesWritten;
    int i, j, samplesProcessed;
	
	mach_timebase_info(&tTBI);
	mult = ((double)tTBI.denom / (double)tTBI.numer) * 1000000;
	
	ttcpolicy.period = 12 * mult;
	ttcpolicy.computation = 2 * mult;
	ttcpolicy.constraint = 24 * mult;
	ttcpolicy.preemptible = 0;
	
	packet->header.magic = htons(0xEFFE);
	packet->header.opcode = 0x01;
	packet->header.endpoint = 0x02;
	packet->packets[0].magic[0] = SYNC;
	packet->packets[0].magic[1] = SYNC;
	packet->packets[0].magic[2] = SYNC;
	packet->packets[1].magic[0] = SYNC;
	packet->packets[1].magic[1] = SYNC;
	packet->packets[1].magic[2] = SYNC;
    
    static const size_t maxTransmitBufferSize = 63 * 2 * 2 * sizeof(float);
	
	if((thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t) &ttcpolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT)) != KERN_SUCCESS) {
		NSLog(@" Failed to set realtime priority\n");
	} 
	NSLog(@"Beginning write thread\n");
	
    if(![writeLoopLock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:5.0]]) {
        NSLog(@"Timeout acquiring thread lock\n");
        return;
    }
    
	while(running == YES) {
        @autoreleasepool {
            bufferData = [sdr.outputBuffer waitForSize:63 * 4 * sizeof(float) withTimeout:[NSDate dateWithTimeIntervalSinceNow:1.0]];
            if(bufferData == NULL) {
                NSLog(@"Write loop timeout\n");
                continue;
            }
            const float *buffer = [bufferData bytes];
            const float *transmitterBuffer;
            
            transmitterBuffer = nil;
            mox = NO;
            
            if(sdr.transmitterBuffer.entries > 0) {
                // NSLog(@"Entries = %d", sdr.transmitterBuffer.entries);
                if(sdr.transmitterBuffer.entries >= maxTransmitBufferSize) {
                    transmitterData = [sdr.transmitterBuffer get:maxTransmitBufferSize];
                    // NSLog(@"Removing %d bytes from buffer", maxTransmitBufferSize);
                    transmitterBuffer = (const float *) [transmitterData bytes];
                 } else {
                    //NSLog(@"Sending blank packet");
                    transmitterData = [NSData dataWithData:[NSMutableData dataWithLength:maxTransmitBufferSize]];
                    transmitterBuffer = [transmitterData bytes];
                }
                
                mox = YES;
            }
            
            packet->header.sequence = htonl(metisWriteSequence++);	
            [self fillHeader:packet->packets[0].header];
            [self fillHeader:packet->packets[1].header];
            
            for(j = 0, samplesProcessed = 0; j < 2; ++j)
                for(i = 0; i < 63; ++i) {
                    if(transmitterBuffer) {
                        packet->packets[j].samples.out[i].leftTx = CFSwapInt16HostToBig((int16_t)(transmitterBuffer[samplesProcessed] * 32767.0f));
                        // NSLog(@"I sample = %f", transmitterBuffer[samplesProcessed]);
                        packet->packets[j].samples.out[i].leftRx = CFSwapInt16HostToBig((int16_t)(buffer[samplesProcessed++] * 32767.0f));
                        
                        packet->packets[j].samples.out[i].rightTx = CFSwapInt16HostToBig((int16_t)(transmitterBuffer[samplesProcessed] * 32767.0f));
                        packet->packets[j].samples.out[i].rightRx = CFSwapInt16HostToBig((int16_t)(buffer[samplesProcessed++] * 32767.0f));
                        
                        //packet->packets[j].samples.out[i].rightTx = CFSwapInt16HostToBig((int16_t)(transmitterBuffer[samplesProcessed] * 32767.0f));
                        //packet->packets[j].samples.out[i].rightRx = CFSwapInt16HostToBig(32767);
                        

                    } else {
                        packet->packets[j].samples.out[i].leftRx = CFSwapInt16HostToBig((int16_t)(buffer[samplesProcessed++] * 32767.0f));
                        packet->packets[j].samples.out[i].rightRx = CFSwapInt16HostToBig((int16_t)(buffer[samplesProcessed++] * 32767.0f));
                        packet->packets[j].samples.out[i].leftTx = 0;
                        packet->packets[j].samples.out[i].rightTx = 0;
                    }
                }
                       
            bytesWritten = send(metisSocket, 
                                  packet, 
                                  sizeof(MetisPacket), 
                                  0);
            
            if(bytesWritten == -1) {
                NSLog(@"Network Write Failed: %s\n", strerror(errno));
                continue;
            }
            
            if(bytesWritten != sizeof(MetisPacket)) {
                NSLog(@"Short write to network.\n");
                continue;
            }
            
            bytesOut += bytesWritten;
            ++packetsOut;
        }
	}
    [writeLoopLock unlock];
	
	NSLog(@"Write Loop ends\n");
}

-(NSString *)metisIPAddressString {
	char ipString[16];
	
	if(inet_ntop(AF_INET, &(metisAddressStruct.sin_addr.s_addr), ipString, sizeof(ipString)) == NULL)
		strcpy(ipString, "0.0.0.0\0");

	return [NSString stringWithCString:ipString encoding: NSASCIIStringEncoding];
}

@end
