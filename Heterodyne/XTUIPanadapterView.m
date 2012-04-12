//
//  XTUIPanadapterView.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 3/23/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "XTUIPanadapterView.h"
#import "NNHMetisDriver.h"
#import "NNHAppDelegate.h"

#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/CoreAnimation.h>
#import <CoreText/CoreText.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <Accelerate/Accelerate.h>


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
    
    CGContextSetStrokeColorWithColor(ctx, [[UIColor whiteColor] CGColor]);
    CGContextSetLineWidth(ctx, 0.5);
    
    //  Reverse the coordinate system
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    CGContextTranslateCTM(ctx, 0, self.bounds.size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    
    CTFontRef labelFont = CTFontCreateWithName(CFSTR("Helvetica"), 8.0, NULL);
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
   
    CGContextAddPath(ctx, tickMarks);
    CGContextStrokePath(ctx);    
    
    CFRelease(tickMarks);
    CFRelease(labelFont);
    CFRelease(textAttributes);
        
}

@end

@interface XTUIPanadapterView () {
    XTUIPVTickLayer *tickLayer;
    CAEAGLLayer *signalLayer;
    EAGLContext *glContext;
    GLuint framebuffer;
    GLuint renderbuffer;
    GLuint vertexBuffer;
    GLuint depthRenderBuffer;
    GLint width;
    GLint height;
    CADisplayLink *displayLink;
}
@end

@implementation XTUIPanadapterView

@synthesize dynamicRange = _dynamicRange;
@synthesize referenceLevel = _referenceLevel;

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
        
        //  Create an OpenGL Context
        glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        if(!glContext || ![EAGLContext setCurrentContext:glContext]) {
            NSLog(@"Couldn't create context\n");
        }
        
        glGenFramebuffersOES(1, &framebuffer);
        glGenRenderbuffersOES(1, &renderbuffer);
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER_OES, renderbuffer);
        //[glContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer *)self.layer];
        [glContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:signalLayer];
        glFramebufferRenderbuffer(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, renderbuffer);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &width);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &height);
        
        GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
        if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
            NSLog(@"Framebuffer creation failed %x", status);
        }
        
    }
    return self;
}

-(void)awakeFromNib {
}

-(void)setNeedsDisplay {
    [super setNeedsDisplay];
    [tickLayer setNeedsDisplay];
}
static const float zero = 0.0f;

-(void)drawFrameWithData:(NSData *) inputData {
    float *verticies;
    float negativeReferenceLevel;
    
    const float *smoothBuffer = [inputData bytes];
    
    int numSamples = [inputData length] / sizeof(float);
    verticies = malloc(([inputData length] * 2) + 4);
    verticies[(numSamples * 2)] = 1.0;
    verticies[(numSamples * 2) + 1] = 0.0;
    verticies[(numSamples * 2) + 2] = 0.0;
    verticies[(numSamples * 2) + 3] = 0.0;
    
    negativeReferenceLevel = -self.referenceLevel;
    vDSP_vsadd((float *) smoothBuffer, 1, &negativeReferenceLevel, &verticies[1], 2, numSamples);
    
    vDSP_vsdiv(&verticies[1], 2, &_dynamicRange, &verticies[1], 2, numSamples);
    
    float increment = 1.0f / numSamples;
    vDSP_vramp((float *) &zero, &increment, verticies, 2, numSamples);
    
    //  Set up the framebuffer for drawing
    [EAGLContext setCurrentContext:glContext];
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    
    if(glIsBuffer(vertexBuffer) == GL_FALSE) {
        glGenBuffers(1, &vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    }
    
    glClearColor(0, 0, 0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
    glViewport(0, 0, width, height);
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0.0, width, 0.0, height, 0, 1);
    glPushMatrix();
    glScalef(width, height, 1.0);
    glMatrixMode(GL_MODELVIEW); 
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_LINE_SMOOTH);
    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
    glDepthMask(GL_FALSE);
    glShadeModel(GL_SMOOTH);
    
    GLfloat lineSizes[2];
    GLfloat lineStep;
    glGetFloatv(GL_SMOOTH_LINE_WIDTH_RANGE, lineSizes);
    // glGetFloatv(GL_SMOOTH_LINE_WIDTH_GRANULARITY, linestep);
    glLineWidth(0.5);
    glColor4f(1.0, 1.0, 1.0, 1.0);
    
    glEnableClientState(GL_VERTEX_ARRAY);
     glBufferData(GL_ARRAY_BUFFER, [inputData length] * 2, verticies, GL_STREAM_DRAW);
    glVertexPointer(2, GL_FLOAT, 0, 0);
    glDrawArrays(GL_LINE_STRIP, 0, numSamples);
    //glDrawArrays(GL_TRIANGLE_STRIP, 0, numSamples + 2);
    glDisableClientState(GL_VERTEX_ARRAY);
    
    glDepthMask(GL_TRUE);
    glDisable(GL_LINE_SMOOTH);
    glDisable(GL_BLEND);
    
    glPopMatrix();
    glFlush();
    free(verticies);
    
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, renderbuffer);
    [glContext presentRenderbuffer:GL_RENDERBUFFER_OES];
    
}

@end
