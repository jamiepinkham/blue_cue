//
//  BCUViewController.m
//  BlueCue iPhone
//
//  Created by Jamie Pinkham on 9/12/13.
//  Copyright (c) 2013 Jamie Pinkham. All rights reserved.
//

#import "BCUViewController.h"
#import "BCUBroadcastController.h"
#import <MediaPlayer/MediaPlayer.h>

@interface BCUViewController () <BCUBroadcastControllerDelegate>

@property (nonatomic, strong) BCUBroadcastController *broadcastController;
@property (nonatomic, strong) MPMusicPlayerController *ipod;
@property (nonatomic, strong) id nowPlayingChangedObserver;

@end

@implementation BCUViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.broadcastController = [[BCUBroadcastController alloc] initWithDelegate:self queue:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.ipod = [MPMusicPlayerController iPodMusicPlayer];
	[self.ipod beginGeneratingPlaybackNotifications];
	
	__weak typeof (self) weakSelf = self;
	self.nowPlayingChangedObserver = [[NSNotificationCenter defaultCenter] addObserverForName:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:self.ipod queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		typeof(self) strongSelf = weakSelf;
		[strongSelf updateNowPlaying];
	}];
	[self updateNowPlaying];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
	self.nowPlayingChangedObserver = nil;
}

- (void)toggleBroadcast:(id)sender
{
	NSString *title = nil;
	if([self.broadcastController isBroadcasting])
	{
		[self.broadcastController stopBroadcasting];
		title = @"Start Broadcasting";
	}
	else
	{
		[self.broadcastController startBroadcasting];
		title = @"Stop Broadcasting";
	}
	
	[self.toggleBroadcastButton setTitle:title forState:UIControlStateNormal];

}

- (IBAction)previousAction:(id)sender
{
	[self.ipod skipToPreviousItem];
}

- (IBAction)nextAction:(id)sender
{
	[self.ipod skipToNextItem];
}

-(void)broadcastControllerDidStopBroadcasting:(BCUBroadcastController *)controller
{
	NSLog(@"stopped");
}


- (void)broadcastController:(BCUBroadcastController *)controller didFailToStartBroadcasting:(NSError *)error
{
	NSLog(@"error = %@", error);
}

- (void)broadcastController:(BCUBroadcastController *)controller didRecieveConnectionRequest:(NSString *)centralName
{
	NSLog(@"central name = %@", centralName);
}

- (void)broadcastControllerDidStartBroadcasting:(BCUBroadcastController *)controller
{
	NSLog(@"broadcasting");
}


- (void)updateNowPlaying
{
	NSDictionary *response = nil;
	MPMusicPlayerController *ipod = [MPMusicPlayerController iPodMusicPlayer];
	MPMediaItem *item = [ipod nowPlayingItem];
	if(item)
	{
		response = @{@"device_name" : [[UIDevice currentDevice] name],
					 @"now_playing": @{MPMediaItemPropertyArtist : ([item valueForProperty:MPMediaItemPropertyArtist] != nil ? [item valueForProperty:MPMediaItemPropertyArtist]  : [NSNull null]),
									   MPMediaItemPropertyTitle : ([item valueForProperty:MPMediaItemPropertyTitle] != nil ? [item valueForProperty:MPMediaItemPropertyTitle] : [NSNull null]),
									   MPMediaItemPropertyAlbumTitle : ([item valueForProperty:MPMediaItemPropertyAlbumTitle] != nil ? [item valueForProperty:MPMediaItemPropertyAlbumTitle] : [NSNull null]),
									   @"repeat_mode" : @([ipod repeatMode]),
									   @"shuffle_mode" : @([ipod shuffleMode]),
									   @"current_playback_time" : @([ipod currentPlaybackTime]),
									   }
					 };
	}
	else
	{
		response = @{@"device_name" : [[UIDevice currentDevice] name], @"now_playing":[NSNull null]};
	}
	
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
	[self.broadcastingTextView setText:[response description]];
	[self.broadcastController setDataForBroadcast:jsonData];
}



@end
