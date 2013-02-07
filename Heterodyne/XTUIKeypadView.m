//
//  XTUIKeypadView.m
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

#import "XTUIKeypadView.h"
#import "XTUIKeypadButton.h"

@interface XTUIKeypadView () {
    BOOL editing;
    float frequency;
}

@property (nonatomic) UILabel *display;

-(void)commonInit;
-(void)buttonPressed:(id)sender;

@end

@implementation XTUIKeypadView

#pragma mark - Property Synthesizers
@synthesize display = _display;

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
    
    frequency = 0;
    
    editing = NO;
    
    width = CGRectGetWidth(self.bounds) / 3;
    height = CGRectGetHeight(self.bounds) / 6;
    
    frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), height);
    
    _display = [[UILabel alloc] initWithFrame:frame];
    _display.textAlignment = UITextAlignmentCenter;
    _display.backgroundColor = [UIColor blackColor];
    _display.textColor = [UIColor redColor];
    _display.text = [self formattedFrequency];
    _display.minimumFontSize = 18.0;
    _display.adjustsFontSizeToFitWidth = YES;
    _display.numberOfLines = 1;
    _display.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    _display.font = [UIFont fontWithName:@"DBLCDTempBlack" size:28.0];
    [self addSubview:_display];
    
    y += height;
    
    NSArray *standardButtons = [NSArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @".", @"0", [UIImage imageNamed:@"Delete"], nil];
    
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

#pragma mark - Accessors

-(float) frequency {
    return frequency;
}

-(void)setFrequency:(float)_frequency {
    frequency = _frequency;
    
    self.display.text = [self formattedFrequency];
}

-(void)buttonPressed:(id)sender {
    XTUIKeypadButton *button = (XTUIKeypadButton *) sender;
    
    if(button.tag < 10) {
        if(editing == NO)
            self.display.text = @"";
        
        self.display.text = [self.display.text stringByAppendingString:[button titleForState:UIControlStateNormal]];
        editing = YES;
        return;
    }
    
    switch(button.tag) {
        // Delete Key
        case 10:
            if(self.display.text.length < 1) return;
            
            if(editing == NO) 
                self.display.text = @"";
            else
                self.display.text = [self.display.text substringToIndex:self.display.text.length - 1];
            
            editing = YES;
            break;
            
        // Enter Keys
        case 1000:
        case 1000000:
            self.frequency = [self.display.text floatValue] * (float) button.tag;
            [self sendActionsForControlEvents:UIControlEventEditingDidEnd];
            self.display.text = [self formattedFrequency];
            editing = NO;
            break;
        default:
            break;
    }
}

-(NSString *)formattedFrequency {    
    int MHz = (int) (frequency / 1000000.0f);
    int kHz = (int) ((frequency - ((float) MHz * 1000000.0f)) / 1000.0f);
    int Hz = (int) (frequency - ((float) MHz * 1000000.0f) - ((float) kHz * 1000.0f));
    
    return [NSString stringWithFormat:@"%02d.%03d.%03d\n", MHz, kHz, Hz];
}

@end
