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

inline static int toPow(float elements) {
    return (int) ceilf(log2f((float) (elements)));
}

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
    
    UIAlertView *discoveryWindow;
    
    XTWorkerThread *glThread;
    
    int textureSize;
    
    float panVelocity;
    NSTimer *momentumTimer;
    
    BOOL horizontalScrolling;
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
    
    delegate = (NNHAppDelegate *) [[UIApplication sharedApplication] delegate];
    NNHMetisDriver *driver = [delegate driver];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(discoveryComplete) name: @"NNHMetisDriverDidCompleteDiscovery" object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(beginDiscovery) name: @"NNHMetisDriverWillBeginDiscovery" object: nil];
    
    discoveryWindow = nil;
    if(driver.gotDiscovery == NO) 
        [self beginDiscovery];
    
    dataBuffer = [XTRealData realDataWithElements:waterfall.textureWidth];
    spectrumBuffer = [dataBuffer elements];
    
    smoothingFactor = 13;
    initAverage = YES;
    
    averageBuffer = malloc(waterfall.textureWidth * sizeof(float));
    
    smoothBufferData = [NSMutableData dataWithLength:waterfall.textureWidth * sizeof(float)];
    smoothBuffer = [smoothBufferData mutableBytes];
    
    kernel.realp = malloc(waterfall.textureWidth * sizeof(float));
    kernel.imagp = malloc(waterfall.textureWidth * sizeof(float));
    vDSP_vclr(kernel.realp, 1, waterfall.textureWidth);
    vDSP_vclr(kernel.imagp, 1, waterfall.textureWidth);
    
    fftIn.realp = malloc(waterfall.textureWidth * sizeof(float));
    fftIn.imagp = malloc(waterfall.textureWidth * sizeof(float));
    vDSP_vclr(fftIn.realp, 1, waterfall.textureWidth);
    vDSP_vclr(fftIn.imagp, 1, waterfall.textureWidth);

    float filterValue = 1.0f / (float) smoothingFactor;
    vDSP_vfill(&filterValue, kernel.realp + ((waterfall.textureWidth / 2) - ((smoothingFactor - 1) / 2)), 1, smoothingFactor);
    
    fftSetup = vDSP_create_fftsetup(toPow(waterfall.textureWidth), kFFTRadix2);
    vDSP_fft_zip(fftSetup, &kernel, 1, toPow(waterfall.textureWidth), kFFTDirection_Forward);      
    
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
    
    UIPinchGestureRecognizer *waterfallPinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleWaterfallPinchGesture:)];
    [self.waterfall addGestureRecognizer:waterfallPinchGesture];
    
    //UILongPressGestureRecognizer *pandadapterLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];
    //[self.panadapter addGestureRecognizer:pandadapterLongPressGesture];
    
    delegate.sdr.tapSize = waterfall.textureWidth;
    
    panVelocity = 0;
    
    NSLog(@"Finished viewDidLoad\n");
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
    
    glThread = [[XTWorkerThread alloc] init];
    glThread.name = @"OpenGL Processing";
    [glThread start];
    [self performSelector:@selector(setupDisplayLink) onThread:glThread withObject:nil waitUntilDone:NO];
    
}

-(void)pauseDisplayLink {
    displayLink.paused = YES;
}

-(void)resumeDisplayLink {
    displayLink.paused = NO;
    displayLink.frameInterval = [[NSUserDefaults standardUserDefaults] integerForKey:@"refreshRate"];
}

- (void)setupDisplayLink {
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawFrame)];
    
    NSLog(@"Refresh Rate is %d\n", [[NSUserDefaults standardUserDefaults] integerForKey:@"refreshRate"]); 
/*    if([[NNHAppDelegate getHardwareVersion] isEqualToString:@"iPad1,1"]) {
        NSLog(@"iPad 1 detected, cranking down framerate\n");
        displayLink.frameInterval = 1;
    } */
    displayLink.frameInterval = [[NSUserDefaults standardUserDefaults] integerForKey:@"refreshRate"];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
    
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

-(BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark - Drawing Subviews

static const float scaling = 0.66;

- (void)drawFrame {
    [dataBuffer clearElements];
    
    [[delegate sdr] tapSpectrumWithRealData:dataBuffer];
    
    if(initAverage == YES) {
        memcpy(averageBuffer, spectrumBuffer, waterfall.textureWidth * sizeof(float));
        initAverage = NO;
    } else {
        vDSP_vavlin(spectrumBuffer, 1, (float *) &scaling, averageBuffer, 1, waterfall.textureWidth);
    }
    
    vDSP_vclr(fftIn.realp, 1, waterfall.textureWidth);
    vDSP_vclr(fftIn.imagp, 1, waterfall.textureWidth);
    memcpy(fftIn.realp, averageBuffer, waterfall.textureWidth * sizeof(float));
    
    //  Perform a convolution by doing an FFT and multiplying.
    vDSP_fft_zip(fftSetup, &fftIn, 1, toPow(waterfall.textureWidth), kFFTDirection_Forward);
    vDSP_zvmul(&fftIn, 1, &kernel, 1, &fftIn, 1, waterfall.textureWidth, 1);
    vDSP_fft_zip(fftSetup, &fftIn, 1, toPow(waterfall.textureWidth), kFFTDirection_Inverse);
    
    //  We have to divide by the scaling factor to account for the offset
    //  in the inverse FFT.
    float scale = (float) waterfall.textureWidth;
    vDSP_vsdiv(fftIn.realp, 1, &scale, fftIn.realp, 1, waterfall.textureWidth);
    
    //  Flip the sides since the center frequency is at the edges because
    //  our filter kernel is centered.
    memcpy(smoothBuffer, fftIn.realp + (waterfall.textureWidth / 2), (waterfall.textureWidth / 2) * sizeof(float));
    memcpy(smoothBuffer + (waterfall.textureWidth / 2), fftIn.realp, (waterfall.textureWidth / 2) * sizeof(float));
    
    //  Apply any user calibration
    //vDSP_vsadd(smoothBuffer, 1, &receiveCalibrationOffset, smoothBuffer, 1, SPECTRUM_BUFFER_SIZE);
    
    [self.panadapter drawFrameWithData:smoothBufferData];
    [self.waterfall drawFrameWithData:smoothBufferData];
}

#pragma mark - Gesture Handling

-(void)handlePanGesture:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:recognizer.view.superview];
    
    // Figure out whether the touch was primarily in the horizontal or vertical direction
    if(recognizer.state == UIGestureRecognizerStateBegan) {
        if(abs(translation.x) >= abs(translation.y))
            horizontalScrolling = YES;
         else 
            horizontalScrolling = NO;
    }
    
    if(horizontalScrolling == YES) 
        [self handleHorizontalScroll:recognizer];
    else 
        [self handleVerticalScroll:recognizer];
    
    [recognizer setTranslation:CGPointMake(0, 0) inView:recognizer.view.superview];
}

-(void)handleHorizontalScroll:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:recognizer.view.superview];
    float hzPerUnit = [delegate.driver sampleRate] / CGRectGetWidth(recognizer.view.bounds);
    CGPoint velocity = [recognizer velocityInView:self.panadapter];

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
    
    //  Code to handle momentum scrolling.  Does not activate if the velocity is too low, or you're doing fine tuning.
    if(recognizer.state == UIGestureRecognizerStateEnded && abs(velocity.x) > 50) {
        panVelocity = velocity.x;
        momentumTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(panMomentumScroll) userInfo:nil repeats:YES];
    }
}

-(void)handleVerticalScroll:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:recognizer.view.superview];

    if(recognizer.view == self.panadapter) {
        float dbPerUnit = self.panadapter.dynamicRange / CGRectGetHeight(self.panadapter.bounds);
        self.panadapter.referenceLevel += translation.y * dbPerUnit;
    }
}

-(void)panMomentumScroll {
    float hzPerUnit = [delegate.driver sampleRate] / CGRectGetWidth(panadapter.bounds);
    float distance = panVelocity * 0.1;
    
    if(abs(panVelocity) < .0001) {
        [momentumTimer invalidate];
        return;
    }
    
    [delegate.driver setFrequency:[delegate.driver getFrequency:0] - (distance * hzPerUnit) forReceiver:0];
    
    panVelocity /= 4;
}

-(void)handleTapGesture:(UITapGestureRecognizer *)recognizer {
    CGPoint position = [recognizer locationInView:recognizer.view.superview];
    
    float hzPerUnit = [delegate.driver sampleRate] / CGRectGetWidth(recognizer.view.bounds);
    float frequencySlew = (position.x - CGRectGetMidX(recognizer.view.bounds)) * hzPerUnit;
    
    [delegate.driver setFrequency:[[delegate driver] getFrequency:0] + frequencySlew forReceiver:0];
}

-(void)handlePanPinchGesture:(UIPinchGestureRecognizer *)recognizer {
    self.panadapter.dynamicRange /= recognizer.scale;
    recognizer.scale = 1.0;
}

-(void)handleWaterfallPinchGesture:(UIPinchGestureRecognizer *)recognizer {
    self.waterfall.dynamicRange /= recognizer.scale;
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

-(void)displayVolumeControl:(id)sender {
    if([currentPopover isPopoverVisible]) {
        [currentPopover dismissPopoverAnimated:YES];
    } else {
        [self performSegueWithIdentifier:@"volumePopover" sender:sender];
    }
}

-(void)displayModeControl:(id)sender {
    if([currentPopover isPopoverVisible]) {
        [currentPopover dismissPopoverAnimated:YES];
    } else {
        [self performSegueWithIdentifier:@"modePopover" sender:sender];
    }
}

-(void)displayStatsControl:(id)sender {
    if([currentPopover isPopoverVisible]) {
        [currentPopover dismissPopoverAnimated:YES];
    } else {
        [self performSegueWithIdentifier:@"statsPopover" sender:sender];
    }
}

#pragma mark - Remote control handling

-(void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if(event.type != UIEventTypeRemoteControl) 
        return;
        
    switch(event.subtype) {
        case UIEventSubtypeRemoteControlTogglePlayPause:
            NSLog(@"Toggled Play/Pause\n");
            break;
        case UIEventSubtypeRemoteControlPlay:
            NSLog(@"Pressed Play\n");
            break;
        case UIEventSubtypeRemoteControlPause:
            NSLog(@"Pressed Pause\n");
            break;
        default:
            NSLog(@"Other remote event\n");
            break;
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

#pragma mark - Discovery handling

-(void)discoveryComplete {
    [discoveryWindow dismissWithClickedButtonIndex:0 animated:YES];
}

-(void)beginDiscovery {
    discoveryWindow = [[UIAlertView alloc] initWithTitle:@"Peforming Discovery" message:@"Heterodyne is attempting to discover openHPSDR hardware on the network.\nPlease Wait." delegate:nil cancelButtonTitle:nil otherButtonTitles:nil, nil];
    
    [discoveryWindow show];

}

@end
