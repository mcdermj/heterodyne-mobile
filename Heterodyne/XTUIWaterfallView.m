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

inline static GLint toRGBA(float r, float g, float b) {
    return ( (int)(r*255.5) << 0) + ( (int)(g*255.5) << 8 ) + ( (int)(b*255.5) << 16 ) + 0xFF000000; 
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
    
    GLuint colorGradientArray[20008];
    
    float *sortBuffer;
    float *intensityBuffer;
    
    int currentLine;
    GLubyte *line;
    GLuint texture;
    GLuint forwardVertexBuffer;
    GLuint reverseVertexBuffer;
    GLuint texCoordBuffer;
    
    GLfloat textureArray[8];
    
    float negLow;
    float scale;
}

-(void)setupGLContext;

@end

static const float off = 1.0 / 511.0;
static const float low = 0.0;
static const float high = 19999.0;

@implementation XTUIWaterfallView

@synthesize referenceLevel = _referenceLevel;
@synthesize textureWidth;
@synthesize dynamicRange;

-(id)initWithCoder:(NSCoder *)aDecoder  {
    self = [super initWithCoder:aDecoder];
    if(self) {
        //  Create an OpenGL Context
        
        [self setupGLContext];
        
        sortBuffer = malloc(textureWidth * sizeof(float));
        intensityBuffer = malloc(textureWidth * sizeof(float));
        line = malloc(textureWidth * 4 * sizeof(GLubyte));
        
        [self loadColorGradient];
        
        /* textureArray[0] = 0.0;
        textureArray[2] = 1.0;
        textureArray[4] = 1.0;
        textureArray[6] = 0.0; */
        
        textureArray[0] = 0.0;
        textureArray[2] = 1.0;
        textureArray[4] = 0.0;
        textureArray[6] = 1.0;
        
        self.layer.opaque = YES;
        
        _referenceLevel = -60.0;
        dynamicRange = 30.0;
        
    }
    return self;
}

-(void)setupGLContext {
    glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    if(!glContext || ![EAGLContext setCurrentContext:glContext]) {
        NSLog(@"Couldn't create context\n");
    }
    
    glGenFramebuffersOES(1, &framebuffer);
    glGenRenderbuffersOES(1, &renderbuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);
    [glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderbuffer);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if(status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Framebuffer creation failed %x", status);
    }
    
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &textureWidth);
    
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    
    char *blankData = (char *) malloc(textureWidth * 512 * 4);
    memset(blankData, 0x88, textureWidth * 512 * 4);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, textureWidth, 512, 0, GL_RGBA, GL_UNSIGNED_BYTE, blankData);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    
    free(blankData);
    
    static const GLfloat verticies [] = {
        1.0, 1.0,
        1.0, 0.0,
        0.0, 1.0,
        0.0, 0.0
    };
    
    glGenBuffers(1, &forwardVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, forwardVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verticies), verticies, GL_STATIC_DRAW);
    glVertexPointer(2, GL_FLOAT, 0, 0);
    
    glGenBuffers(1, &texCoordBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, texCoordBuffer);
    glTexCoordPointer(2, GL_FLOAT, 0, 0);
    
    glClearColor(0.0, 0.0, 0.0, 0.0);
    
    glViewport(0, 0, width, height);
    glBlendFunc(GL_ONE, GL_SRC_COLOR);
    
    glEnable(GL_TEXTURE_2D);
    glDisable(GL_BLEND);
    glDisable(GL_DITHER);
    glDisable(GL_ALPHA_TEST);
    glDisable(GL_STENCIL_TEST);
    glDisable(GL_FOG);
    glDisable(GL_DEPTH_TEST);
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0, width, 0, height, 0, 1);
    glScalef(width, height, 1.0);
    glMatrixMode(GL_MODELVIEW);
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
}

-(void)loadColorGradient {
    int i = 0, j = 0;
    float r = 0, g = 0, b = 0;
    
    for(i = 0; i < 2858; ++i) {
        b = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b);
    }
    
    for(i = 0; i < 2858; ++i) {
        g = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    for(i = 2858; i > -1; --i) {
        b = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    for(i = 0; i < 2858; ++i) {
        r = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    for(i = 2858; i > -1; --i) {
        g = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    for(i = 0; i < 2858; ++i) {
        b = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    }
    
    for(i = 0; i < 2858; ++i) {
        g = (float) i / 2858.0;
        colorGradientArray[j++] = toRGBA(r, g, b); 
    } 
}

-(void)awakeFromNib {
}

+(Class) layerClass {
    return [CAEAGLLayer class];
}

-(void)drawFrameWithData:(NSData *)data {
    
    if(currentLine % 32 == 0) {
        memcpy(sortBuffer, [data bytes], textureWidth * sizeof(float));
        
        // XXX This function is a hog.
        vDSP_vsort(sortBuffer, textureWidth, 1);
        negLow = -sortBuffer[1024];
        
        scale = 20008.0f / dynamicRange; 
        
        //float denominator = sortBuffer[textureWidth - 1] - sortBuffer[textureWidth / 4];
        //scale = denominator == 0 ? 0 : 20008.0f / denominator;
    }
    
    vDSP_vsadd((float *) [data bytes], 1, &negLow, intensityBuffer, 1, textureWidth);
    vDSP_vsmul(intensityBuffer, 1, &scale, intensityBuffer, 1, textureWidth);
    vDSP_vclip(intensityBuffer, 1, (float *) &low, (float *) &high, intensityBuffer, 1, textureWidth);
    
	for(int i = 0; i < textureWidth; i++) 
        memset_pattern4(&line[i*4], &colorGradientArray[(int) intensityBuffer[i]], 4);
    
    //  Set up the framebuffer for drawing
    [EAGLContext setCurrentContext:glContext];
 
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, currentLine, textureWidth, 1, GL_RGBA, GL_UNSIGNED_BYTE, line);

    currentLine = (currentLine + 1) % 512;
    float prop_y = (float) currentLine  / 511.0;
    
    textureArray[2] = 1.0;
    textureArray[3] = prop_y;

    textureArray[0] = 1.0;
    textureArray[1] = prop_y + 1 - off;

    textureArray[6] = 0.0;
    textureArray[7] = prop_y;

    textureArray[4] = 0.0;
    textureArray[5] = prop_y + 1 - off;
    
    glBindBuffer(GL_ARRAY_BUFFER, texCoordBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(textureArray), textureArray, GL_DYNAMIC_DRAW);
     
    glBindBuffer(GL_ARRAY_BUFFER, forwardVertexBuffer);
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [glContext presentRenderbuffer:GL_RENDERBUFFER_OES];
}


@end
