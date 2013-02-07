//
//  NNHMetisDriver.h
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

#include <netinet/in.h>
#include <mach/thread_policy.h>

#define BANDSCOPE_BUFFER_SIZE 8192

#define SYNC 0x7F

#define DTTSP_BUFFER_SIZE 1024

#define MERCURY 0
#define PENELOPE 1
#define JANUS 2
#define ATLAS 4
#define BOTH 5

#define XVERTER 3

#define DISCOVERY_NOT_ACTIVE 0
#define DISCOVERY_IN_PROGRESS 1
#define DISCOVERY_COMPLETE 2

typedef struct _ozySamplesOut {
	int16_t leftRx;
	int16_t rightRx;
	int16_t leftTx;
	int16_t rightTx;
} __attribute__((packed)) OzySamplesOut;

typedef struct _metisDataHeader {
	unsigned short magic;
	char opcode;
	char endpoint;
	unsigned int sequence;
} __attribute__((packed)) MetisDataHeader;

typedef struct _ozySamplesIn {
	char i[3];
	char q[3];
	short mic;
} __attribute__((packed)) OzySamplesIn;

typedef struct _ozyPacket {
	char magic[3];
	char header[5];
    union _samples {
        OzySamplesIn in[63];
        OzySamplesOut out[63];
    } samples;
} __attribute__((packed)) OzyPacket;

typedef struct _metisPacket {
	MetisDataHeader header;
	OzyPacket packets[2];
} __attribute__((packed)) MetisPacket;

typedef struct _metisDiscoveryRequest{
	short magic;
	char opcode;
	char padding[60];
} __attribute__((packed)) MetisDiscoveryRequest;

typedef struct _metisDiscoveryReply {
	short magic;
	char status;
	char mac[6];
    char version;
    char padding[50];
} __attribute__((packed)) MetisDiscoveryReply;

typedef struct _metisStartStop {
	short magic;
	char opcode;
	char startStop;
	char padding[60];
} __attribute__((packed)) MetisStartStop;

//  This probably isn't the exact right way to do this, but the OS header has this commented out for some reason.
kern_return_t   thread_policy_set(
                                  thread_t                                        thread,
                                  thread_policy_flavor_t          flavor,
                                  thread_policy_t                         policy_info,
                                  mach_msg_type_number_t          count);

typedef struct _metisErase {
    short magic;
    char opcode;
    char command;
    char padding[60];
} __attribute__((packed)) MetisErase;

typedef struct _metisProgramRequest {
    short magic;
    char opcode;
    char command;
    int size;
    char data[256];
} __attribute__((packed)) MetisProgramRequest;

typedef struct _metisProgramReply {
    short magic;
    char reply;
    char mac[6];
    char padding[51];
} __attribute__((packed)) MetisProgramReply;

@class XTSoftwareDefinedRadio;
@class XTDSPBlock;
@class XTBlockBuffer;
@class XTRingBuffer;

@interface NNHMetisDriver : NSObject {
	NSMutableData *sampleData;
	OzySamplesOut *outBuffer;
	
	int transmitterFrequency;
	int receiverFrequency[8];	
	
	XTBlockBuffer *ep4Buffers;
			
	BOOL ADCOverflow;
	
	int mercuryVersion;
	int penelopeVersion;
	int ozyVersion;
	
	int forwardPower;
    
    XTDSPBlock *processingBlock;
	
	float leftMicBuffer[DTTSP_BUFFER_SIZE];
	float rightMicBuffer[DTTSP_BUFFER_SIZE];
	int samples;
	
	int headerSequence;
	
	BOOL mox;
	BOOL preamp;
	BOOL dither;
	BOOL random;
	BOOL alexRxOut;
	BOOL duplex;
	BOOL classE;
	BOOL mercuryAudio;
	BOOL mercuryPresent;
	BOOL penelopePresent;
    
    BOOL micBoost;
    BOOL lineIn;
	
	BOOL ptt;
	BOOL dot;
	BOOL dash;
	
	BOOL stopDiscovery;
	
	int sampleRate;
	short tenMHzSource;	
	short oneTwentyTwoMHzSource;		
	short micSource;	
	short alexAttenuator;	
	short alexAntenna;	
	short alexTxRelay;	
	short driveLevel;
	
	UInt8 openCollectors;
	
	float micGain;
	float txGain;
	
	int metisSocket;
	unsigned int metisWriteSequence;
	struct sockaddr_in metisAddressStruct;
	
	BOOL running;
	
    NSLock *socketServiceLoopLock;
    NSLock *writeLoopLock;
        
    char latestFirmware;
}

-(id)initWithSDR:(XTSoftwareDefinedRadio *)newSdr;
-(int)getFrequency: (int)_receiver;
-(void)setFrequency: (int)_frequency forReceiver: (int)_receiver;
-(BOOL)start;
-(BOOL)stop;

@property (readonly) XTBlockBuffer *ep4Buffers;
@property (readonly) int mercuryVersion;
@property (readonly) int ozyVersion;
@property (readonly) int penelopeVersion;
@property (retain) XTSoftwareDefinedRadio *sdr;

@property (assign) int sampleRate;

@property BOOL dither;
@property BOOL random;
@property short tenMHzSource;
@property short oneTwentyTwoMHzSource;
@property BOOL mercuryPresent;
@property BOOL penelopePresent;
@property BOOL preamp;

@property UInt8 openCollectors;

@property float micGain;
@property float txGain;

@property int discoveryStatus;

@property unsigned long packetsIn;
@property unsigned long droppedPacketsIn;
@property unsigned long outOfOrderPacketsIn;
@property unsigned long packetsOut;
@property unsigned long bytesIn;
@property unsigned long bytesOut;

@end
