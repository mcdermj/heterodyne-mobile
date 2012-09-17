//
//  XTDSPSimpleHilbertTransform.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 9/17/12.
//
//
 
#import "XTDSPSimpleHilbertTransform.h"
#import "XTDSPBlock.h"

@interface XTDSPSimpleHilbertTransform () {
    float x[4];
    float y[6];
    float d[6];
    
    BOOL invert;
}

@end

@implementation XTDSPSimpleHilbertTransform

-(void)performWithComplexSignal: (XTDSPBlock *)signal {
    float *xin = [signal realElements];
    float *yin = [signal imaginaryElements];
    
    for(int i = 0; i < [signal blockSize]; ++i) {
        x[0] = d[1] - xin[i];
        x[1] = d[0] - x[0] * 0.00196f;
        x[2] = d[3] - x[1];
        x[3] = d[1] + x[2] * 0.737f;
        
        d[1] = x[1];
        d[3] = x[3];
        
        y[0] = d[2] - xin[i];
        y[1] = d[0] + y[0] * 0.924f;
        y[2] = d[4] - y[1];
        y[3] = d[2] + y[2] * 0.439f;
        y[4] = d[5] - y[3];
        y[5] = d[4] - y[4] * 0.586f;
        
        d[2] = y[1];
        d[4] = y[3];
        d[5] = y[5];
        
        d[0] = xin[i];
        
        xin[i] = x[3];
        yin[i] = y[5];
    }
}

@end
