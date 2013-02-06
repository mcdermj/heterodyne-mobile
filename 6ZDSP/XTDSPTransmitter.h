//
//  XTDSPTransmitter.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 9/17/12.
//
//

#import <UIKit/UIKit.h>

@class XTDSPBlock;

@interface XTDSPTransmitter : NSObject

-(void)processComplexSamples:(XTDSPBlock *)complexData;
-(id)initWithSampleRate:(float)sampleRate;
-(void)reset;

@end
