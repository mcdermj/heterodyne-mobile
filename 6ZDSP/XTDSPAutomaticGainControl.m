//
//  XTDSPAutomaticGainControl.m
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

#import "XTDSPAutomaticGainControl.h"
#import "XTDSPBlock.h"

#define FAST_ATTACK_TIME 0.2
#define FAST_DECAY_TIME 3.0

#define TO_EXPONENT(value) (1.0 - exp(-1000.0 / (value * sampleRate)))
#define FROM_EXPONENT(value) (-1000.0 / (log(1.0 - value) * sampleRate))
#define ADVANCE_INDEX(value) value = (value + mask) & mask

typedef struct _AGCParams {
    float attack;
    float oneMinusAttack;
    float decay;
    float oneMinusDecay;

    float hangTime;
    float hangThreshold;
    float hangGate;
    int hangTimeSamples;

    float currentGain;

    int index;
    int hangIndex;    
} AGCParams;

@interface XTDSPAutomaticGainControl () {
    
    //  Parameters for each AGC path.  0 is slow and 1 is fast.
    AGCParams params[2];
    
    int outIndex;
        
    int mask;
    
    float *realBuffer;
    float *imagBuffer;
    
    XTDSPBlock *ringBuffer;
    
    int iterations;
    
    float maxGain;
    float minGain;
}

@end

@implementation XTDSPAutomaticGainControl

@synthesize slope;
@synthesize target;
@synthesize currentGain;

-(id)initWithSampleRate:(float)newSampleRate {
    self = [super initWithSampleRate:newSampleRate];
    
    if(self) {
        sampleRate = newSampleRate;
        
        params[0].attack = TO_EXPONENT(2.0f);                               //  Adjustable Parameter
        params[0].oneMinusAttack = 1.0 - params[0].attack;
                
        params[0].decay = TO_EXPONENT(250.0f);                              //  Adjustable Parameter
        params[0].oneMinusDecay = 1.0 - params[0].decay;
                
        params[1].attack = TO_EXPONENT(FAST_ATTACK_TIME);
        params[1].oneMinusAttack = 1.0 - params[1].attack;
                
        params[1].decay = TO_EXPONENT(FAST_DECAY_TIME);
        params[1].oneMinusDecay = 1.0 - params[1].decay;
                
        params[1].hangIndex = params[0].hangIndex = params[0].index = 0;
        
        params[0].hangTime = 250.0f * 0.001f;                               //  Adjustable Parameter
        params[0].hangTimeSamples = (int) (params[0].hangTime * sampleRate);
        
        outIndex = (int) (sampleRate * params[0].attack * 0.003f);
        
        params[1].index = (int) (sampleRate * 0.0027f);
        
        target = 0.5f;                                                      //  Adjustable Parameter
        slope = 1.0f;                                                       //  Adjustable Parameter
        
        maxGain = 31622.8f;                                                 //  Adjustable Parameter
        
        params[0].hangThreshold = params[1].hangThreshold = minGain = 0.00001f;
        params[0].hangGate = params[1].hangGate = maxGain * params[0].hangThreshold + minGain * (float) (1.0 - params[0].hangThreshold);
        
        params[1].currentGain = params[0].currentGain = 1.0f;
        
        params[1].hangIndex = 0;
        params[1].hangTime = 0.1f * params[0].hangTime;
        params[1].hangTimeSamples = (int) (params[1].hangTime * sampleRate);
        
    }
    
    return self;
}

#pragma mark - Accessors

-(void) setAttack:(float)newAttack {
    params[0].attack = TO_EXPONENT(newAttack);
    params[0].oneMinusAttack = 1.0 - params[0].attack;
}

-(float)attack {
    return FROM_EXPONENT(params[0].attack);
}

-(void) setDecay:(float)newDecay {
    params[0].decay = TO_EXPONENT(newDecay);
    params[0].oneMinusDecay = 1.0 - params[0].decay;
}

-(float)decay {
    return FROM_EXPONENT(params[0].decay);
}

-(void)setHangTime:(float)newHangTime {
    params[0].hangTime = newHangTime * 0.001f;
}

-(float)hangTime {
    return params[0].hangTime / 0.001f;
}

-(void)setMaxGain:(float)_maxGain {
    maxGain = _maxGain;
    
    params[0].hangGate = params[1].hangGate = maxGain * params[0].hangThreshold + minGain * (float) (1.0 - params[0].hangThreshold);
}

-(float)maxGain {
    return maxGain;
}

-(void)setMinGain:(float)_minGain {
    params[0].hangThreshold = params[1].hangThreshold = minGain = _minGain;
    params[0].hangGate = params[1].hangGate = maxGain * params[0].hangThreshold + minGain * (float) (1.0 - params[0].hangThreshold);
}

-(float)minGain {
    return minGain;
}

#pragma mark - DSP Functions

-(void)performWithComplexSignal:(XTDSPBlock *)signal {
    float *realSignal = [signal realElements];
    float *imagSignal = [signal imaginaryElements];
    
    if([ringBuffer blockSize] != [signal blockSize] * 2) {
        ringBuffer = [[XTDSPBlock alloc] initWithBlockSize:[signal blockSize] * 2];
        mask = [ringBuffer blockSize] - 1;
        realBuffer = [ringBuffer realElements];
        imagBuffer = [ringBuffer imaginaryElements];

    }
    
    for(int i = 0; i < [signal blockSize]; ++i) {
        realBuffer[params[0].index] = realSignal[i];
        imagBuffer[params[0].index] = imagSignal[i];
        
        for(int j = 0; j < 2; ++j) {
            AGCParams *agc = &params[j];
            
            float tmp = hypot(realBuffer[agc->index], imagBuffer[agc->index]);
            
            if(tmp > 0.0f)
                tmp = target / tmp;
            else
                tmp = agc->currentGain;
            
            if(tmp < agc->hangGate && j == 0)
                agc->hangIndex = agc->hangTimeSamples;
            
            if(tmp >= agc->currentGain) {
                if(agc->hangIndex++ > agc->hangTimeSamples)
                    agc->currentGain = agc->oneMinusDecay * agc->currentGain + agc->decay * fmin(maxGain, tmp);
            } else {
                agc->hangIndex = 0;
                agc->currentGain = agc->oneMinusAttack * agc->currentGain + agc->attack * fmax(tmp, minGain);
            }
            ADVANCE_INDEX(agc->index);
        }
         
        float scaleFactor = fmin(params[1].currentGain, slope * params[0].currentGain);
        realSignal[i] = realBuffer[outIndex] * scaleFactor;
        imagSignal[i] = imagBuffer[outIndex] * scaleFactor;
        
        ADVANCE_INDEX(outIndex);
    }
}

@end