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
@property (nonatomic, strong) NSMutableSet *foundDevices;

- (IBAction)toggleScanning:(id)sender;

@end

@implementation BCUAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	self.scanController = [[BCUScanController alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
	self.foundDevices = [NSMutableSet new];
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
	
	
	NSString *script = [NSString stringWithFormat:@"tell application \"iTunes\"\n\tplay (every track of playlist 1 whose name is \"%@\" and artist is \"%@\")\nset player position to %ld\nend tell",info[@"title"], info[@"artist"], (long)[info[@"current_playback_time"] integerValue]];
	NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
	NSDictionary *returnDict = nil;
	[appleScript executeAndReturnError:&returnDict];
}

- (BOOL)scanController:(BCUScanController *)scanController shouldConnectToPeripheral:(CFUUIDRef)deviceUUID
{
	return [self.foundDevices containsObject:CFBridgingRelease(CFUUIDCreateString(NULL, deviceUUID))];
}

@end
