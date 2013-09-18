//
//  BCUViewController.h
//  BlueCue iPhone
//
//  Created by Jamie Pinkham on 9/12/13.
//  Copyright (c) 2013 Jamie Pinkham. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BCUViewController : UIViewController

@property (nonatomic, weak) IBOutlet UIButton *toggleBroadcastButton;
@property (nonatomic, weak) IBOutlet UITextView *broadcastingTextView;

- (IBAction)toggleBroadcast:(id)sender;
- (IBAction)previousAction:(id)sender;
- (IBAction)nextAction:(id)sender;

@end
