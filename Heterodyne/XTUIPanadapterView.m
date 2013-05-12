//
//  XTUIPanadapterView.m
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

#import "XTUIPanadapterView.h"
#import "NNHMetisDriver.h"
#import "NNHAppDelegate.h"
#import "XTSoftwareDefinedRadio.h"
#import "XTDSPReceiver.h"

#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/CoreAnimation.h>
#import <CoreText/CoreText.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <Accelerate/Accelerate.h>

@interface XTUIPVFilterLayer : CALayer
@property (strong, nonatomic) XTUIPanadapterView *view;
@end

@implementation XTUIPVFilterLayer
@synthesize view = _view;

-(void)drawInContext:(CGContextRef)ctx {
    NNHAppDelegate *delegate = (NNHAppDelegate *) [[UIApplication sharedApplication] delegate];
    NNHMetisDriver *driver = [delegate driver];
    CGMutablePathRef centerLine = CGPathCreateMutable();

    float hzPerUnit = (float) [driver sampleRate] / CGRectGetWidth(self.bounds);
    
    //  Reverse the coordinate system
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    CGContextTranslateCTM(ctx, 0, self.bounds.size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    
    //  Draw the center line
    CGContextSetStrokeColorWithColor(ctx, [[UIColor redColor] CGColor]);
    CGContextSetLineWidth(ctx, 0.5);

    CGPathMoveToPoint(centerLine, NULL, CGRectGetMidX(self.bounds), 0);
    CGPathAddLineToPoint(centerLine, NULL, CGRectGetMidX(self.bounds), CGRectGetHeight(self.bounds));
    
    CGContextSetShouldAntialias(ctx, false);
    CGContextAddPath(ctx, centerLine);
    CGContextStrokePath(ctx);
    
    CFRelease(centerLine);
    
    XTDSPReceiver *mainReceiver = [delegate.sdr.receivers objectAtIndex:0];
    
    //  Draw the filter rectangle
    CGContextSetFillColorWithColor(ctx, [[UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.25] CGColor]);
    CGRect filter = CGRectMake(CGRectGetMidX(self.bounds) + (mainReceiver.lowCut / hzPerUnit), 
                               0, 
                               (mainReceiver.highCut / hzPerUnit) - (mainReceiver.lowCut / hzPerUnit), 
                               CGRectGetHeight(self.bounds));
    CGContextFillRect(ctx, filter);
    
}
@end

@interface XTUIPVTickLayer : CALayer
@property (strong, nonatomic) XTUIPanadapterView *view;
@end


@implementation XTUIPVTickLayer

@synthesize view = _view;

-(void)drawInContext:(CGContextRef)ctx {	
    NNHAppDelegate *delegate = (NNHAppDelegate *) [[UIApplication sharedApplication] delegate];
    NNHMetisDriver *driver = [delegate driver];
    CGMutablePathRef tickMarks = CGPathCreateMutable();
    float position;
    
    float hzPerUnit = (float) [driver sampleRate] / CGRectGetWidth(self.bounds);
    float startFrequency = (float) [driver getFrequency:0] - (CGRectGetMidX(self.bounds) * hzPerUnit);
    float endFrequency = startFrequency + (CGRectGetWidth(self.bounds) * hzPerUnit);
    
    CGContextSetFillColorWithColor(ctx, [[UIColor blackColor] CGColor]);
    CGContextFillRect(ctx, self.bounds);
    
    CGContextSetStrokeColorWithColor(ctx, [[UIColor grayColor] CGColor]);
    CGContextSetLineWidth(ctx, 0.5);
    
    static const CGFloat lineDashes[] = {
        1, 2
    };
    CGContextSetLineDash(ctx, 0, lineDashes, 2);
    
    //  Reverse the coordinate system
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    CGContextTranslateCTM(ctx, 0, self.bounds.size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    
    CTFontRef labelFont = CTFontCreateWithName(CFSTR("Helvetica-Bold"), 9.0, NULL);
    CFMutableDictionaryRef textAttributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(textAttributes, kCTFontAttributeName, labelFont);
    CFDictionarySetValue(textAttributes, kCTForegroundColorAttributeName, [[UIColor lightGrayColor] CGColor]);
    
    for(float mark = ceilf(startFrequency/10000.0f) * 10000.0f; mark < endFrequency; mark += 10000.0) {
        position = (mark - startFrequency) / hzPerUnit;
        
        CGPathMoveToPoint(tickMarks, NULL, position, 0);
        CGPathAddLineToPoint(tickMarks, NULL, position, CGRectGetHeight(self.bounds));
        
        CFStringRef tickMarkLabelString = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%d"), (int) (mark / 1000.0));
        CFAttributedStringRef tickMarkLabel = CFAttributedStringCreate(kCFAllocatorDefault, tickMarkLabelString, textAttributes);
        CFRelease(tickMarkLabelString);
        
        CTLineRef tickMarkLabelLine = CTLineCreateWithAttributedString(tickMarkLabel);
        CGContextSetTextPosition(ctx, position + 4, CGRectGetHeight(self.bounds) - 15);
        CTLineDraw(tickMarkLabelLine, ctx);
        CFRelease(tickMarkLabelLine);
        CFRelease(tickMarkLabel);
    }
    
    float slope = CGRectGetHeight(self.bounds) / self.view.dynamicRange;
    
    for(float mark = ceil(self.view.referenceLevel / 10.0) * 10.0; mark < self.view.referenceLevel + self.view.dynamicRange; mark += 10.0) {
        position = (mark - self.view.referenceLevel) * slope;
        
        CGPathMoveToPoint(tickMarks, NULL, 0, position);
        CGPathAddLineToPoint(tickMarks, NULL, CGRectGetWidth(self.bounds), position);
        
        CFStringRef tickMarkLabelString = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%d dB"), (int) mark);
        CFAttributedStringRef tickMarkLabel = CFAttributedStringCreate(kCFAllocatorDefault, tickMarkLabelString, textAttributes);
        CFRelease(tickMarkLabelString);
        
        CTLineRef tickMarkLabelLine = CTLineCreateWithAttributedString(tickMarkLabel);
        CGContextSetTextPosition(ctx, 4, position - 15);
        CTLineDraw(tickMarkLabelLine, ctx);
        CFRelease(tickMarkLabelLine);
        CFRelease(tickMarkLabel);
    }
    
    //  Draw the frequency display.
    CTFontRef frequencyFont = CTFontCreateWithName(CFSTR("DBLCDTempBlack"), 32.0, NULL);
    
    CFDictionarySetValue(textAttributes, kCTFontAttributeName, frequencyFont);
    if(delegate.sdr.Ptt == YES)
        CFDictionarySetValue(textAttributes, kCTForegroundColorAttributeName, [[UIColor redColor] CGColor]);
    else
        CFDictionarySetValue(textAttributes, kCTForegroundColorAttributeName, [[UIColor greenColor] CGColor]);
    
    int MHz = (int) ([driver getFrequency:0] / 1000000.0f);
    int kHz = (int) (([driver getFrequency:0] - ((float) MHz * 1000000.0f)) / 1000.0f);
    int Hz = (int) ([driver getFrequency:0] - ((float) MHz * 1000000.0f) - ((float) kHz * 1000.0f));

    NSAttributedString *frequencyString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%02d.%03d.%03d", MHz, kHz, Hz]
                                                                          attributes: (__bridge NSDictionary *)(textAttributes)];
    
    NSAttributedString *measuringString = [[NSAttributedString alloc] initWithString:@"00.000.000"
                                                                          attributes:(__bridge NSDictionary *) (textAttributes)];
    CTLineRef measuringLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef) measuringString);
    CTLineRef frequencyLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)(frequencyString));
    double width = CTLineGetTypographicBounds(measuringLine, NULL, NULL, NULL);
    CGContextSetTextPosition(ctx, CGRectGetWidth(self.bounds) - width - 10, CGRectGetHeight(self.bounds) - 75);
    CTLineDraw(frequencyLine, ctx);
    
    CFRelease(measuringLine);
    CFRelease(frequencyFont);
    CFRelease(frequencyLine);
    
    CTFontRef modeFont = CTFontCreateWithName(CFSTR("Helvetica-Bold"), 12.0, NULL);
    CFDictionarySetValue(textAttributes, kCTFontAttributeName, modeFont);
    NSAttributedString *modeString = [[NSAttributedString alloc] initWithString:((XTDSPReceiver *) delegate.sdr.receivers[0]).mode
                                                                     attributes:(__bridge NSDictionary *) textAttributes];
    CTLineRef modeLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef) modeString);
    float height = CTFontGetAscent(modeFont) + CTFontGetDescent(modeFont); //+ CTFontGetXHeight(modeFont);
    CGContextSetTextPosition(ctx, CGRectGetWidth(self.bounds) - width - 10, CGRectGetHeight(self.bounds) - 75 - height);
    CTLineDraw(modeLine, ctx);
    
    CFRelease(modeFont);
    CFRelease(modeLine);
   
    CGContextSetShouldAntialias(ctx, false);
    CGContextAddPath(ctx, tickMarks);
    CGContextStrokePath(ctx);    
    CGContextSetShouldAntialias(ctx, true);
    
    CFRelease(tickMarks);
    CFRelease(labelFont);
    CFRelease(textAttributes);
        
}

@end

@interface XTUIPanadapterView () {
    XTUIPVTickLayer *tickLayer;
    XTUIPVFilterLayer *filterLayer;
    CAEAGLLayer *signalLayer;
    EAGLContext *glContext;
    GLuint framebuffer;
    GLuint renderbuffer;
    GLuint vertexBuffer;
    GLuint depthRenderBuffer;
    GLuint vertexArray;
    GLint width;
    GLint height;
    CADisplayLink *displayLink;
    
    float _dynamicRange;
    float _referenceLevel;
    
    NSMutableData *verticiesData;
    float *verticies;
    
    NSMutableData *shadedAreaIndiciesData;
    GLushort *shadedAreaIndicies;
    GLuint shadedAreaIndexBuffer;
    
    NSMutableData *lineIndiciesData;
    GLushort *lineIndicies;
    GLuint lineIndexBuffer;
}

-(void)setupGLContext;

@end

@implementation XTUIPanadapterView

@synthesize textureWidth;

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self) {
        _dynamicRange = 100.0;
        _referenceLevel = -100.0;

        tickLayer = [XTUIPVTickLayer layer];
        tickLayer.frame = self.bounds;
        tickLayer.view = self;
        tickLayer.opaque = YES;
        
        [[self layer] addSublayer:tickLayer];
        [tickLayer setNeedsDisplay];
        
        //  Set up the OpenGL ES Layer
        signalLayer = [CAEAGLLayer layer];
        signalLayer.frame = self.bounds;
        signalLayer.opaque = NO;
        [[self layer] addSublayer:signalLayer];
        //signalLayer = self.layer;
        
        //  Set up the overlay for the filter and frequency marks
        filterLayer = [XTUIPVFilterLayer layer];
        filterLayer.frame = self.bounds;
        filterLayer.view = self;
        filterLayer.opaque = NO;
        [[self layer] addSublayer:filterLayer];
        [filterLayer setNeedsDisplay];
        
        [self setupGLContext];
        
        verticiesData = [NSMutableData dataWithLength:1];
        lineIndiciesData = [NSMutableData dataWithLength:1];
        shadedAreaIndiciesData = [NSMutableData dataWithLength:1];
        
        [[NSNotificationCenter defaultCenter] addObserver:tickLayer selector:@selector(setNeedsDisplay) name:@"XTFrequencyChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:filterLayer selector:@selector(setNeedsDisplay) name:@"XTReceiverFilterDidChange" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:filterLayer selector:@selector(setNeedsDisplay) name:@"XTReceiverFrequencyDidChange" object:nil];


    }
    return self;
}

-(void)setupGLContext {
    //  Create an OpenGL Context
    glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    if(!glContext || ![EAGLContext setCurrentContext:glContext]) {
        NSLog(@"Couldn't create context\n");
    }
    
    glGenFramebuffersOES(1, &framebuffer);
    glGenRenderbuffersOES(1, &renderbuffer);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER_OES, renderbuffer);
    
    [glContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:signalLayer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, renderbuffer);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &height);
    
    GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
    if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
        NSLog(@"Framebuffer creation failed %x", status);
    }
    
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &textureWidth);
    
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    
    glGenVertexArraysOES(1, &vertexArray);
    glBindVertexArrayOES(vertexArray);
    
    glGenBuffers(1, &lineIndexBuffer);
    
    glGenBuffers(1, &shadedAreaIndexBuffer);
    
    glViewport(0, 0, width, height);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
    glShadeModel(GL_SMOOTH);
    glLineWidth(0.5);
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0.0, width, 0.0, height, 0, 1);
    
    glScalef(width, height, 1.0);
    glMatrixMode(GL_MODELVIEW);
    
    glDepthMask(GL_FALSE);
    
    GLfloat lineSizes[2];
    glGetFloatv(GL_SMOOTH_LINE_WIDTH_RANGE, lineSizes);
    
    glEnable(GL_BLEND);
    glEnable(GL_LINE_SMOOTH);
    glDisable(GL_DITHER);
    glDisable(GL_ALPHA_TEST);
    glDisable(GL_STENCIL_TEST);
    glDisable(GL_FOG);
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_DEPTH_TEST);
    
    glEnableClientState(GL_VERTEX_ARRAY);
    
    NSLog(@"Maximum Texture Size for this platform is %d\n", [self textureWidth]);
}

#pragma mark - Accessors
-(void)setDynamicRange:(float)dynamicRange {
    _dynamicRange = dynamicRange;
    [self setNeedsDisplay];
}

-(float)dynamicRange {
    return _dynamicRange;
}

-(void)setReferenceLevel:(float)referenceLevel {
    _referenceLevel = referenceLevel;
    [self setNeedsDisplay];
}

-(float)referenceLevel {
    return _referenceLevel;
}

-(void)awakeFromNib {
}

-(void)setNeedsDisplay {
    [super setNeedsDisplay];
    [tickLayer setNeedsDisplay];
}
static const float zero = 0.0f;

-(void)drawFrameWithData:(NSData *) inputData {
    float negativeReferenceLevel;
    
    const float *smoothBuffer = [inputData bytes];
    
    int numSamples = [inputData length] / sizeof(float);
    
    //  Set up the framebuffer for drawing
    [EAGLContext setCurrentContext:glContext];
            
    if(verticiesData.length != inputData.length * 4) {
        verticiesData.length = inputData.length * 4;
        verticies = (float *) verticiesData.mutableBytes;
        glVertexPointer(2, GL_FLOAT, 0, 0);
        
        lineIndiciesData.length = numSamples * sizeof(GLushort);
        lineIndicies = lineIndiciesData.mutableBytes;
        for(int i = 0, j = 1; i < numSamples; ++i, j += 2)
            lineIndicies[i] = j;
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, lineIndexBuffer);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, numSamples * sizeof(GLushort), lineIndicies, GL_STATIC_DRAW);
                
        shadedAreaIndiciesData.length = numSamples * sizeof(GLushort) * 2;
        shadedAreaIndicies = shadedAreaIndiciesData.mutableBytes;
        for(int i = 0; i < numSamples * 2; ++i)
            shadedAreaIndicies[i] = i;
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, shadedAreaIndexBuffer);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, numSamples * sizeof(GLushort) * 2, shadedAreaIndicies, GL_STATIC_DRAW);
        
        float increment = 1.0f / numSamples;
        vDSP_vfill((float *) &zero, &verticies[1], 4, numSamples);
        vDSP_vramp((float *) &zero, &increment, verticies, 4, numSamples);
        vDSP_vramp((float *) &zero, &increment, &verticies[2], 4, numSamples);
    }
    
    negativeReferenceLevel = -self.referenceLevel;
    vDSP_vsadd((float *) smoothBuffer, 1, &negativeReferenceLevel, &verticies[3], 4, numSamples);
    vDSP_vsdiv(&verticies[3], 4, &_dynamicRange, &verticies[3], 4, numSamples);
        
    glBufferData(GL_ARRAY_BUFFER, [inputData length] * 4, verticies, GL_DYNAMIC_DRAW);
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glColor4f(1.0, 1.0, 1.0, 1.0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, lineIndexBuffer);
    glDrawElements(GL_LINE_STRIP, numSamples, GL_UNSIGNED_SHORT, 0);
    
    glColor4f(1.0, 1.0, 1.0, 0.25);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, shadedAreaIndexBuffer);
    glDrawElements(GL_TRIANGLE_STRIP, numSamples * 2, GL_UNSIGNED_SHORT, 0);
        
    [glContext presentRenderbuffer:GL_RENDERBUFFER_OES];
}

@end
