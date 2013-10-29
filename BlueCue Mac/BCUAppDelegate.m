//
//  BCUAppDelegate.m
//  BlueCue Mac
//
//  Created by Jamie Pinkham on 9/12/13.
//  Copyright (c) 2013 Jamie Pinkham. All rights reserved.
//

#import "BCUAppDelegate.h"
#import "BCUScanController.h"

@interface BCUAppDelegate () <BCUScanControllerDelegate>

@property (nonatomic, strong) BCUScanController *scanController;
@property (nonatomic, weak) IBOutlet NSButton *scanToggleButton;
@property (nonatomic, weak) IBOutlet NSTextField *responseField;
@property (nonatomic, weak) IBOutlet NSImageCell *imageCell;
@property (nonatomic, strong) NSMutableSet *foundDevices;
//@property (nonatomic, strong) iTunesApplication *iTunes;
//@property (nonatomic, strong) iTunesLibraryPlaylist *iTunesLibraryPlaylist;

- (IBAction)toggleScanning:(id)sender;

@end

@implementation BCUAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	self.scanController = [[BCUScanController alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
	self.foundDevices = [NSMutableSet new];
	[self.scanController startScanning];
}


- (void)applicationWillTerminate:(NSNotification *)notification
{
	[self.scanController stopScanning];
}

- (IBAction)toggleScanning:(id)sender
{
	NSString *title = nil;
	if([self.scanController isScanning])
	{
		[self.scanController stopScanning];
		title = @"Scan";
	}
	else
	{
		[self.scanController startScanning];
		title = @"Stop";
	}
	[self.scanToggleButton setTitle:title];
	[self.scanToggleButton sizeToFit];
}


- (void)scanControllerStartedScanningForDevices:(BCUScanController *)scanController
{
	NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)scanController:(BCUScanController *)scanController failedToScanForDevices:(NSError *)error
{
	NSLog(@"%@", NSStringFromSelector(_cmd));
	NSLog(@"error = %@", error);
}

- (void)scanControllerStoppedScanningForDevices:(BCUScanController *)scanController
{
	NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)scanController:(BCUScanController *)scanController foundDevice:(CFUUIDRef)deviceUUID
{
	NSLog(@"%@", NSStringFromSelector(_cmd));
	NSString *uuid = CFBridgingRelease(CFUUIDCreateString(NULL, deviceUUID));
	NSLog(@"uuid = %@", uuid);
	[self.foundDevices addObject:CFBridgingRelease(CFUUIDCreateString(NULL, deviceUUID))];
}


- (void)scanControllerFailedToScan:(BCUScanController *)scanController peripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
	NSLog(@"%@", NSStringFromSelector(_cmd));
	NSLog(@"%@", error);
}

- (void)scanController:(BCUScanController *)scanController recievedNowPlayingInfo:(NSDictionary *)info forDevice:(NSString *)device
{
	NSLog(@"info = %@, device = %@", info, device);
	NSString *string = [NSString stringWithFormat:@"%@\r\n%@", [info description], [[NSDate date] description]];
	[self.responseField setStringValue:string];
	if(![info isEqual:[NSNull null]])
	{
		[self playSongWithArtist:info[@"artist"] title:info[@"title"] playbackTime:[info[@"current_playback_time"] doubleValue]];
	}
	
}

- (BOOL)scanController:(BCUScanController *)scanController shouldConnectToPeripheral:(CFUUIDRef)deviceUUID
{
	return YES;
}


- (void)playSongWithArtist:(NSString *)artist title:(NSString *)title playbackTime:(double)time
{
	NSString *script = [NSString stringWithFormat:@"tell application \"iTunes\"\ncopy (a reference to (current track)) to current_track\nset trks to (tracks of playlist 1 whose name = \"%@\" and artist is \"%@\")\nset trk to item 1 of trks\nif current_track is {} or trk is not equal to current_track\nplay trk\nset player position to %f\nif exists artworks of trk then\nreturn get data of artwork 1 of trk\nend if\nend if\nend tell",title, artist, time];
	NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
	NSDictionary *returnDict = nil;
	NSAppleEventDescriptor *eventDescriptor = [appleScript executeAndReturnError:&returnDict];
	
	NSImage *albumArtImage = [[NSImage alloc] initWithData:[eventDescriptor data]];
	self.imageCell.image = albumArtImage;

}

@end
