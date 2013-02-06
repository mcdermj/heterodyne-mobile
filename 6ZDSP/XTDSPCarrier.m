//
//  XTDSPCarrier.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 12/23/12.
//
//

#import "XTDSPCarrier.h"
#import "XTDSPBlock.h"

@implementation XTDSPCarrier

-(void)performWithComplexSignal:(XTDSPBlock *)signal {
    for(int i = 0; i < signal.blockSize; ++i) {
        signal.realElements[i] = 0.5;
        signal.imaginaryElements[i] = 0.0;
    }
}

@end
