//
//  XTDSPComplexToRealStereo.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/26/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import "XTDSPComplexToRealStereo.h"
#import "XTDSPBlock.h"


@implementation XTDSPComplexToRealStereo

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)performWithComplexSignal: (XTDSPBlock *)signal {
	[[signal imaginaryData] clearElements];
    memcpy([signal imaginaryElements], [signal realElements], [signal blockSize] * sizeof(float));
}

@end
