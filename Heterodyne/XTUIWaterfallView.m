//
//  XTUIWaterfallView.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 3/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "XTUIWaterfallView.h"
#import "NNHAppDelegate.h"

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <QuartzCore/CoreAnimation.h>
#import <Accelerate/Accelerate.h>

#define WATERFALL_SIZE 4096
#define SPECTRUM_BUFFER_SIZE 4096

inline static GLushort toRGBA(float r, float g, float b) {
    return ((int) (b * 15.5) ) + ( (int)(g * 15.5) << 4 ) + ( (int) (r * 15.5) << 8 ) + 0xF000; 
}

inline static GLushort to565(unsigned short r, unsigned short g, unsigned short b) {
    return (b & 0x001F) + ((g & 0x003F) << 5) + ((r & 0x001F) << 11);
}

@interface XTUIWaterfallView () {
    EAGLContext *glContext;
    GLuint framebuffer;
    GLuint renderbuffer;
    GLuint vertexBuffer;
    GLuint depthRenderBuffer;
    GLint width;
    GLint height;
    CADisplayLink *displayLink;
    
    GLushort colorGradientArray[20008];
    
    float sortBuffer[SPECTRUM_BUFFER_SIZE];
    float intensityBuffer[SPECTRUM_BUFFER_SIZE];
    
    int currentLine;
    GLushort line[WATERFALL_SIZE];
    GLuint texture;
    GLuint forwardVertexBuffer;
    GLuint reverseVertexBuffer;
    GLuint texCoordBuffer;
    
    //float textureArray[8];
    
    float negLow;
    float scale;
}

@end

static const float off = 1.0 / 511.0;
static const float low = 0.0;
static const float high = 19999.0;

@implementation XTUIWaterfallView

@synthesize referenceLevel = _referenceLevel;

-(id)initWithCoder:(NSCoder *)aDecoder  {
    self = [super initWithCoder:aDecoder];
    if(self) {
        //  Create an OpenGL Context
        glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        if(!glContext || ![EAGLContext setCurrentContext:glContext]) {
            NSLog(@"Couldn't create context\n");
        }
        
        glGenFramebuffersOES(1, &framebuffer);
        glGenRenderbuffersOES(1, &renderbuffer);
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER_OES, renderbuffer);
        [glContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer *)self.layer];
        glFramebufferRenderbuffer(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, renderbuffer);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &width);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &height);
        
        GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
        if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
            NSLog(@"Framebuffer creation failed %x", status);
        }
        
        [self loadColorGradient];
        
        /* textureArray[0] = 0.0;
        textureArray[2] = 1.0;
        textureArray[4] = 1.0;
        textureArray[6] = 0.0; */
        
        /*textureArray[0] = 0.0;
        textureArray[2] = 1.0;
        textureArray[4] = 0.0;
        textureArray[6] = 1.0; */
        
        self.layer.opaque = YES;
        
        _referenceLevel = -60.0;
        
    }
    return self;
}


-(void)loadColorGradient {
    int i = 0, j = 0;
    float r = 0, g = 0, b = 0;
    
    for(i = 0; i < 2858; ++i) {
        b = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    NSLog(@"r = %f, g = %f, b = %f\n", r, g, b);
    
    for(i = 0; i < 2858; ++i) {
        g = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    NSLog(@"r = %f, g = %f, b = %f\n", r, g, b);
    
    for(i = 2858; i > -1; --i) {
        b = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    NSLog(@"r = %f, g = %f, b = %f\n", r, g, b);
    
    for(i = 0; i < 2858; ++i) {
        r = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    NSLog(@"r = %f, g = %f, b = %f\n", r, g, b);

    for(i = 2858; i > -1; --i) {
        g = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    NSLog(@"r = %f, g = %f, b = %f\n", r, g, b);

    for(i = 0; i < 2858; ++i) {
        b = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    NSLog(@"r = %f, g = %f, b = %f\n", r, g, b);

    for(i = 0; i < 2858; ++i) {
        g = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    NSLog(@"r = %f, g = %f, b = %f\n", r, g, b);
    
    NSLog(@"[%@ %s]: %d colors generated\n", [self class], (char *) _cmd, j);
    
    NSLog(@"Testing code\n");
    NSLog(@"r = 31, result = %x\n", to565(31, 0, 0)); 
    NSLog(@"g = 63, result = %x\n", to565(0, 63, 0));
    NSLog(@"b = 31, result = %x\n", to565(0, 0, 31));
    NSLog(@"allones = %x\n", to565(31, 63, 31));

}

-(void)awakeFromNib {
}

+(Class) layerClass {
    return [CAEAGLLayer class];
}

-(void)drawFrameWithData:(NSData *)data {
    
    if(currentLine % 32 == 0) {
        memcpy(sortBuffer, [data bytes], sizeof(sortBuffer));
        
        // XXX This function is a hog.
        vDSP_vsort(sortBuffer, SPECTRUM_BUFFER_SIZE, 1);
        negLow = -sortBuffer[1024];
        
        float denominator = sortBuffer[SPECTRUM_BUFFER_SIZE - 1] - sortBuffer[SPECTRUM_BUFFER_SIZE / 4];
        scale = denominator == 0 ? 0 : 20000.0f / denominator;
    }
    
    vDSP_vsadd((float *) [data bytes], 1, &negLow, intensityBuffer, 1, SPECTRUM_BUFFER_SIZE);
    vDSP_vsmul(intensityBuffer, 1, &scale, intensityBuffer, 1, SPECTRUM_BUFFER_SIZE);
    vDSP_vclip(intensityBuffer, 1, (float *) &low, (float *) &high, intensityBuffer, 1, SPECTRUM_BUFFER_SIZE);
    
	for(int i = 0; i < SPECTRUM_BUFFER_SIZE; i++) 
		line[i] = colorGradientArray[(int) intensityBuffer[i]];
    
    
    
    //  Set up the framebuffer for drawing
    [EAGLContext setCurrentContext:glContext];
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, width, height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0, width, 0, height, 0, 1);
    glPushMatrix();
    
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_SRC_COLOR);
    
    if(glIsTexture(texture) == GL_FALSE) {
		glGenTextures(1, &texture);
		glBindTexture(GL_TEXTURE_2D, texture);
		
		char *blankData = (char *) malloc(WATERFALL_SIZE * 512 * sizeof(GLushort));
		memset(blankData, 1, WATERFALL_SIZE * 512 * sizeof(GLushort));
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WATERFALL_SIZE, 512, 0, GL_RGBA, GL_UNSIGNED_SHORT, blankData);
        glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
	}
    
    //glBindTexture(GL_TEXTURE_2D, texture);
    
    //glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, currentLine, WATERFALL_SIZE, 1, GL_RGBA, GL_UNSIGNED_SHORT_4_4_4_4, line);
    currentLine = (currentLine + 1) % 512;
    
    glScalef(width, height, 1.0);
    glMatrixMode(GL_MODELVIEW);
    glDepthMask(GL_FALSE);
        
    static const GLfloat verticies [] = {
        0.0, 0.0,
        0.0, 1.0,
        1.0, 0.0,
        1.0, 1.0
    };
    
    float prop_y = (float) currentLine  / 511.0;
    
    /*
    textureArray[1] = prop_y;
    textureArray[3] = prop_y;
    textureArray[5] = prop_y + 1 - off;
    textureArray[7] = prop_y + 1 - off;
     */
        
    static const GLfloat textureArray[] = {
        0.0, 0.0,
        0.0, 1.0,
        1.0, 0.0,
        1.0, 1.0
    };
        
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);

    glTexCoordPointer(2, GL_FLOAT, 0, textureArray);
    glVertexPointer(2, GL_FLOAT, 0, verticies);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);
    glDepthMask(GL_TRUE);
    
    glFlush();    
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, renderbuffer);
    [glContext presentRenderbuffer:GL_RENDERBUFFER_OES];
}


@end
