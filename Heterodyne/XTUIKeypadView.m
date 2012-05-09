//
//  XTUIKeypadView.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "XTUIKeypadView.h"
#import "XTUIKeypadButton.h"

@interface XTUIKeypadView ()

@property (nonatomic) UILabel *display;

-(void)commonInit;
-(void)buttonPressed:(id)sender;

@end

@implementation XTUIKeypadView

#pragma mark - Property Synthesizers
@synthesize display = _display;
@synthesize frequency = _frequency;

#pragma mark - Initialization

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self commonInit];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self) {
        [self commonInit];
    }
    return self;
}

-(void)commonInit {
    float x = 0, y = 0;
    float width = 0, height = 0;
    CGRect frame;
    int i = 10;
    
    _frequency = 0;
    
    width = CGRectGetWidth(self.bounds) / 3;
    height = CGRectGetHeight(self.bounds) / 6;
    
    frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), height);
    
    _display = [[UILabel alloc] initWithFrame:frame];
    _display.textAlignment = UITextAlignmentCenter;
    _display.backgroundColor = [UIColor blackColor];
    _display.textColor = [UIColor whiteColor];
    _display.text = @"";
    [self addSubview:_display];
    
    y += height;
    
    NSArray *standardButtons = [NSArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @".", @"0", [UIImage imageNamed:@"delete"], nil];
    
    for(id button in standardButtons) {
        frame = CGRectMake(x, y, width, height);
        XTUIKeypadButton *numberButton = [[XTUIKeypadButton alloc] initWithFrame:frame];
        if([button isKindOfClass:[NSString class]]) {
            numberButton.tag = [button integerValue];
            [numberButton setTitle:button forState:UIControlStateNormal];
        } else if([button isKindOfClass:[UIImage class]]) {
            numberButton.tag = i++;
            [numberButton setImage:button forState:UIControlStateNormal];
        }
        [numberButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        x += width;
        if(x >= CGRectGetWidth(self.bounds)) {
            x = 0;
            y += height;
        }
        [self addSubview:numberButton];
    }

    frame = CGRectMake(x, y, CGRectGetWidth(self.bounds) / 2, height);
    XTUIKeypadButton *mhzButton = [[XTUIKeypadButton alloc] initWithFrame:frame];
    mhzButton.tag = 1000000;
    mhzButton.backgroundColor = [UIColor greenColor];
    [mhzButton setTitle:@"MHz" forState:UIControlStateNormal];
    [mhzButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:mhzButton];
    
    frame.origin.x += CGRectGetWidth(self.bounds) / 2;
    XTUIKeypadButton *khzButton = [[XTUIKeypadButton alloc] initWithFrame:frame];
    khzButton.tag = 1000;
    khzButton.backgroundColor = [UIColor greenColor];
    [khzButton setTitle:@"KHz" forState:UIControlStateNormal];
    [khzButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:khzButton];
}

-(void)buttonPressed:(id)sender {
    XTUIKeypadButton *button = (XTUIKeypadButton *) sender;
    
    NSLog(@"Button with tag %d pressed\n", button.tag);
    if(button.tag < 10) {
        self.display.text = [self.display.text stringByAppendingString:[button titleForState:UIControlStateNormal]];
        return;
    }
    
    switch(button.tag) {
        // Delete Key
        case 10:
            if(self.display.text.length < 1) return;
            
            self.display.text = [self.display.text substringToIndex:self.display.text.length - 1];
            break;
            
        // Enter Keys
        case 1000:
        case 1000000:
            self.frequency = [self.display.text floatValue] * (float) button.tag;
            NSLog("Keypad returns %f\n", self.frequency);
            [self sendActionsForControlEvents:UIControlEventEditingDidEnd];
            break;
        default:
            break;
    }
}

@end
