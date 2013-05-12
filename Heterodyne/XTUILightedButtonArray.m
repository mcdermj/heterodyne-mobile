//
//  XTUILightedButtonArray.m
//
// Copyright (c) 2010-2013 - Jeremy C. McDermond (NH6Z)

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

#import "XTUILightedButtonArray.h"

#import "XTUILightedToggleButton.h"

@interface XTUILightedButtonArray ()

@end

@implementation XTUILightedButtonArray
@synthesize delegate;

#pragma mark - Initialization

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self) {
        
    }
    return self;
}

#pragma mark - Accessors

-(NSString *)selected {
    for(UIView *view in self.subviews)
        if([view isKindOfClass:[XTUILightedToggleButton class]])
            if(view.backgroundColor == [UIColor greenColor])
                return [(XTUILightedToggleButton *)view titleForState:UIControlStateNormal];
    
    return @"";
}

-(void)setSelected:(NSString *)selected {
    for(UIView *view in self.subviews)
        if([view isKindOfClass:[XTUILightedToggleButton class]])
            if([[(XTUILightedToggleButton *)view titleForState:UIControlStateNormal] isEqualToString:selected]) {
                view.backgroundColor = [UIColor greenColor];
            } else {
                view.backgroundColor = [UIColor blackColor];
            }

}

#pragma mark - Initialization

-(void)awakeFromNib {
    NSArray *contentArray = [self.delegate contentForButtonArray:self];
    
    NSLog(@"Creating %d buttons", contentArray.count);
    
    float buttonHeight = CGRectGetHeight(self.bounds);
    float buttonWidth = CGRectGetWidth(self.bounds) / contentArray.count;
    float x = 0;
    
    //  Create the buttons
    for(NSString *item in contentArray) {
        CGRect frame = CGRectMake(x, 0, buttonWidth, buttonHeight);
        XTUILightedToggleButton *newButton = [[XTUILightedToggleButton alloc] initWithFrame:frame];
        [newButton setTitle:item forState:UIControlStateNormal];
        [newButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        newButton.backgroundColor = [UIColor blackColor];
        newButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        [self addSubview:newButton];
        NSLog(@"Creating button for %@", item);
        x += buttonWidth;
    }
}

#pragma mark - Actions

-(void)buttonPressed:(id)sender {
    XTUILightedToggleButton *button = (XTUILightedToggleButton *)sender;
    
    for(UIView *view in self.subviews)
        if([view isKindOfClass:[XTUILightedToggleButton class]])
            view.backgroundColor = [UIColor blackColor];
    
    button.backgroundColor = [UIColor greenColor];
    
    [self.delegate buttonPressed:[button titleForState:UIControlStateNormal] forArray:self];
    
    NSLog(@"%@ pressed", [button titleForState:UIControlStateNormal]);
}

@end
