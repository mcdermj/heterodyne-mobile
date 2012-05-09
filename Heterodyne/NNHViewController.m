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
#import "NNHMetisDriver.h"
#import "XTWorkerThread.h"
#import "NNHFrequencyPopupViewController.h"

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
    
    XTRealData *dataBuffer;
    float *spectrumBuffer;
}

@property (weak) UIPopoverController *currentPopover;
@end

@implementation NNHViewController

@synthesize waterfall;
@synthesize panadapter;
@synthesize currentPopover;

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
    
    dataBuffer = [XTRealData realDataWithElements:SPECTRUM_BUFFER_SIZE];
    spectrumBuffer = [dataBuffer elements];
    
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
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    panGesture.maximumNumberOfTouches = NSUIntegerMax;
    panGesture.minimumNumberOfTouches = 1;
    [self.panadapter addGestureRecognizer:panGesture];
    
    UIPanGestureRecognizer *waterfallPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    panGesture.maximumNumberOfTouches = NSUIntegerMax;
    panGesture.minimumNumberOfTouches = 1;
    [self.waterfall addGestureRecognizer:waterfallPanGesture];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.panadapter addGestureRecognizer:tapGesture];
    
    UITapGestureRecognizer *waterfallTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    waterfallTapGesture.numberOfTapsRequired = 2;
    [self.waterfall addGestureRecognizer:waterfallTapGesture];
    
    UIPinchGestureRecognizer *panadapterPinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanPinchGesture:)];
    [self.panadapter addGestureRecognizer:panadapterPinchGesture];
    
    UILongPressGestureRecognizer *pandadapterLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];
    [self.panadapter addGestureRecognizer:pandadapterLongPressGesture];
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
    
    XTWorkerThread *glThread = [[XTWorkerThread alloc] init];
    [glThread start];
    [self performSelector:@selector(setupDisplayLink) onThread:glThread withObject:nil waitUntilDone:NO];
    
}

- (void)setupDisplayLink {
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawFrame)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
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

#pragma mark - Drawing Subviews

static const float scaling = 0.66;

- (void)drawFrame {
    [dataBuffer clearElements];
    
    [[delegate sdr] tapSpectrumWithRealData:dataBuffer];
    
    if(initAverage == YES) {
        memcpy(averageBuffer, spectrumBuffer, SPECTRUM_BUFFER_SIZE);
        initAverage = NO;
    } else {
        vDSP_vavlin(spectrumBuffer, 1, (float *) &scaling, averageBuffer, 1, SPECTRUM_BUFFER_SIZE);
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

#pragma mark - Gesture Handling

-(void)handlePanGesture:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:recognizer.view.superview];
    float hzPerUnit = [delegate.driver sampleRate] / CGRectGetWidth(recognizer.view.bounds);

    switch(recognizer.numberOfTouches) {
        case 1:
            break;
        case 2:
            translation.x /= 10;
            translation.y /= 10;
            break;
        default:
            break;
    }
    
    [delegate.driver setFrequency:[delegate.driver getFrequency:0] - (translation.x * hzPerUnit) forReceiver:0];
    if(recognizer.view == self.panadapter) {
        float dbPerUnit = self.panadapter.dynamicRange / CGRectGetHeight(self.panadapter.bounds);
        self.panadapter.referenceLevel += translation.y * dbPerUnit;
    }
    [recognizer setTranslation:CGPointMake(0, 0) inView:recognizer.view.superview];
}

-(void)handleTapGesture:(UITapGestureRecognizer *)recognizer {
    CGPoint position = [recognizer locationInView:recognizer.view.superview];
    
    float hzPerUnit = [delegate.driver sampleRate] / CGRectGetWidth(recognizer.view.bounds);
    float frequencySlew = (position.x - CGRectGetMidX(recognizer.view.bounds)) * hzPerUnit;
    
    [delegate.driver setFrequency:[[delegate driver] getFrequency:0] + frequencySlew forReceiver:0];
}

-(void)handlePanPinchGesture:(UIPinchGestureRecognizer *)recognizer {
    self.panadapter.dynamicRange *= recognizer.scale;
    recognizer.scale = 1.0;
}

-(void)handleLongPressGesture:(UILongPressGestureRecognizer *) recognizer {
    NSLog(@"Long press on the panadapter\n");
}

#pragma mark - Button handling

-(void)displayFrequencyControl:(id)sender {
    if([currentPopover isPopoverVisible]) {
        [currentPopover dismissPopoverAnimated:YES];
    } else {
        [self performSegueWithIdentifier:@"frequencyPopup" sender:sender];
    }
}

#pragma mark - Segues for menu items

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue isKindOfClass:[UIStoryboardPopoverSegue class]]) {
        currentPopover = [(UIStoryboardPopoverSegue *)segue popoverController];
    }
    
    if([sender isKindOfClass:[UIBarButtonItem class]]) {
        UIStoryboardPopoverSegue *popoverSegue = (UIStoryboardPopoverSegue *)segue;
        NNHFrequencyPopupViewController *controller = (NNHFrequencyPopupViewController *) popoverSegue.destinationViewController;
        
        controller.popover = popoverSegue.popoverController;
        controller.masterViewController = popoverSegue.sourceViewController;
    } else {
        
    }
}

@end
