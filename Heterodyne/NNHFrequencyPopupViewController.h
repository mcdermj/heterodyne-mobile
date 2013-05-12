//
//  NNHFrequencyPopupViewController.h
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

#import <UIKit/UIKit.h>

@class XTUIKeypadView;
@class XTUILightedToggleButton;
@class XTUILightedButtonArray;
@class ACVRangeSelector;

@interface NNHFrequencyPopupViewController : UIViewController

@property (nonatomic) UIPopoverController *popover;
@property (nonatomic) UIViewController *masterViewController;
@property (nonatomic) IBOutlet UIPickerView *picker;
@property (nonatomic) IBOutlet XTUILightedToggleButton *preampButton;
@property (nonatomic) IBOutlet XTUIKeypadView *keypad;
@property (nonatomic) IBOutlet ACVRangeSelector *filterWidth;
@property (nonatomic) IBOutlet UILabel *filterLabel;
@property (nonatomic) IBOutlet XTUILightedButtonArray *modeSelector;
@property (nonatomic) IBOutlet UISlider *volumeSlider;
@property (nonatomic) IBOutlet UISlider *micGainSlider;

-(IBAction)frequencyEntered:(id)sender;
-(IBAction)filterWidthChanged:(id)sender;
-(IBAction)micGainSliderChanged:(id)sender;
-(IBAction)volumeSliderChanged:(id)sender;

@end
