//
//  NNHViewController.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 3/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NNHViewController.h"
#import "XTUIPanadapterView.h"
#import "XTUIWaterfallView.h"
#import "NNHAppDelegate.h"
#import "XTRealData.h"
#import "XTSoftwareDefinedRadio.h"

#import <QuartzCore/CoreAnimation.h>
#import <Accelerate/Accelerate.h>


// XXX Bleh
#define SPECTRUM_BUFFER_SIZE 4096

@interface NNHViewController () {
    CADisplayLink *displayLink;
    
    float *averageBuffer;
    float *smoothBuffer;
    
    NSMutableData *smoothBufferData;
    
    DSPSplitComplex kernel;
    DSPSplitComplex fftIn;
    FFTSetup fftSetup;
    
    int smoothingFactor;
    
    BOOL initAverage;
    NNHAppDelegate *delegate;
}
@end

@implementation NNHViewController

@synthesize waterfall;
@synthesize panadapter;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    smoothingFactor = 13;
    initAverage = YES;
    
    averageBuffer = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
    
    smoothBufferData = [NSMutableData dataWithLength:SPECTRUM_BUFFER_SIZE * sizeof(float)];
    smoothBuffer = [smoothBufferData mutableBytes];
    
    kernel.realp = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
    kernel.imagp = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
    vDSP_vclr(kernel.realp, 1, SPECTRUM_BUFFER_SIZE);
    vDSP_vclr(kernel.imagp, 1, SPECTRUM_BUFFER_SIZE);
    
    fftIn.realp = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
    fftIn.imagp = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
    vDSP_vclr(fftIn.realp, 1, SPECTRUM_BUFFER_SIZE);
    vDSP_vclr(fftIn.imagp, 1, SPECTRUM_BUFFER_SIZE);

    float filterValue = 1.0f / (float) smoothingFactor;
    vDSP_vfill(&filterValue, kernel.realp + ((SPECTRUM_BUFFER_SIZE / 2) - ((smoothingFactor - 1) / 2)), 1, smoothingFactor);
    
    fftSetup = vDSP_create_fftsetup(12, kFFTRadix2);
    vDSP_fft_zip(fftSetup, &kernel, 1, 12, kFFTDirection_Forward);      
    
    delegate = [[UIApplication sharedApplication] delegate];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawFrame)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

static const float scaling = 0.66;

- (void)drawFrame {
    XTRealData *dataBuffer = [XTRealData realDataWithElements:SPECTRUM_BUFFER_SIZE];
    float *spectrumBuffer = [dataBuffer elements];
    
    [[delegate sdr] tapSpectrumWithRealData:dataBuffer];
    
    if(initAverage == YES) {
        memcpy(averageBuffer, spectrumBuffer, SPECTRUM_BUFFER_SIZE);
        initAverage = NO;
    } else {
        vDSP_vavlin(spectrumBuffer, 1, &scaling, averageBuffer, 1, SPECTRUM_BUFFER_SIZE);
    }
    
    vDSP_vclr(fftIn.realp, 1, SPECTRUM_BUFFER_SIZE);
    vDSP_vclr(fftIn.imagp, 1, SPECTRUM_BUFFER_SIZE);
    memcpy(fftIn.realp, averageBuffer, SPECTRUM_BUFFER_SIZE * sizeof(float));
    
    //  Perform a convolution by doing an FFT and multiplying.
    vDSP_fft_zip(fftSetup, &fftIn, 1, 12, kFFTDirection_Forward);
    vDSP_zvmul(&fftIn, 1, &kernel, 1, &fftIn, 1, SPECTRUM_BUFFER_SIZE, 1);
    vDSP_fft_zip(fftSetup, &fftIn, 1, 12, kFFTDirection_Inverse);
    
    //  We have to divide by the scaling factor to account for the offset
    //  in the inverse FFT.
    float scale = (float) SPECTRUM_BUFFER_SIZE;
    vDSP_vsdiv(fftIn.realp, 1, &scale, fftIn.realp, 1, SPECTRUM_BUFFER_SIZE);
    
    //  Flip the sides since the center frequency is at the edges because
    //  our filter kernel is centered.
    memcpy(smoothBuffer, fftIn.realp + (SPECTRUM_BUFFER_SIZE / 2), (SPECTRUM_BUFFER_SIZE / 2) * sizeof(float));
    memcpy(smoothBuffer + (SPECTRUM_BUFFER_SIZE / 2), fftIn.realp, (SPECTRUM_BUFFER_SIZE / 2) * sizeof(float));
    
    //  Apply any user calibration
    //vDSP_vsadd(smoothBuffer, 1, &receiveCalibrationOffset, smoothBuffer, 1, SPECTRUM_BUFFER_SIZE);
    
    [self.panadapter drawFrameWithData:smoothBufferData];
    [self.waterfall drawFrameWithData:smoothBufferData];
}

@end
