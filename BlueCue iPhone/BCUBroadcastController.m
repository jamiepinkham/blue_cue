//
//  BCUBluetoothController.m
//  BlueCue iPhone
//
//  Created by Jamie Pinkham on 9/12/13.
//  Copyright (c) 2013 Jamie Pinkham. All rights reserved.
//

#import "BCUBroadcastController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "BCUServiceIdentifiers.h"
#import <MediaPlayer/MediaPlayer.h>

@interface BCUBroadcastController () <CBPeripheralManagerDelegate>

@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property (nonatomic, weak) id<BCUBroadcastControllerDelegate> delegate;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, strong) CBMutableCharacteristic *nowPlayingCharacteristic;
@property (nonatomic, strong) CBMutableCharacteristic *notifyNowPlayingChangedCharacteristic;
@property (nonatomic, strong) CBMutableService *bcuService;
@property (nonatomic, strong) dispatch_queue_t bluetoothQueue;
@property (nonatomic, strong) NSData *dataToSend;
@property (nonatomic, readwrite) NSInteger sendDataIndex;

@property (nonatomic, strong) NSMutableArray *subscribedCentrals;

@property (nonatomic, strong) NSData *eomBytes;

#define MTU 20

@end

//static NSString const * kBCUBroadcastControllerRestoreIdentifier  = @"797215EF-51E3-4DA3-B0F8-39D6EFA7FDA9";

@implementation BCUBroadcastController

- (instancetype)initWithDelegate:(id<BCUBroadcastControllerDelegate>)delegate queue:(dispatch_queue_t)queue
{
	self = [super init];
	if (self)
	{
		if(queue == NULL)
		{
			queue = dispatch_get_main_queue();
		}
		self.delegate = delegate;
		self.callbackQueue = queue;
		self.subscribedCentrals = [[NSMutableArray alloc] init];
		self.bluetoothQueue = dispatch_queue_create("com.jamiepinkham.bluecue-broadcast", NULL);
		uint8_t bytes[2] = {
            0xFF, 0xD9
        };
        self.eomBytes = [NSData dataWithBytes:bytes length:2];
	}
	return self;
}

- (CBMutableService *)bcuService
{
	if(_bcuService == nil)
	{
		_bcuService = [[CBMutableService alloc] initWithType:BCUServiceUUID() primary:YES];
		[_bcuService setCharacteristics:@[self.nowPlayingCharacteristic, self.fetchNowPlayingCharacteristic]];
	}
	return _bcuService;
}

- (CBMutableCharacteristic *)nowPlayingCharacteristic
{
	if(_nowPlayingCharacteristic == nil)
	{
		_nowPlayingCharacteristic = [[CBMutableCharacteristic alloc] initWithType:BCUNowPlayingCharacteristicUUID() properties:CBCharacteristicPropertyRead value:nil permissions:CBAttributePermissionsReadable];
	}
	return _nowPlayingCharacteristic;
}

- (CBMutableCharacteristic *)fetchNowPlayingCharacteristic
{
	if(_notifyNowPlayingChangedCharacteristic == nil)
	{
		_notifyNowPlayingChangedCharacteristic = [[CBMutableCharacteristic alloc] initWithType:BCUNotifyNowPlayingChangedCharacteristicUUID() properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
	}
	return _notifyNowPlayingChangedCharacteristic;
}

- (BOOL)isBroadcasting
{
	return self.peripheralManager != nil && [self.peripheralManager isAdvertising];
}

- (void)startBroadcasting
{
	if([self.peripheralManager isAdvertising])
	{
		[self stopBroadcasting];
	}
	NSDictionary *options = @{ CBPeripheralManagerOptionShowPowerAlertKey : @(YES),
//							   CBPeripheralManagerOptionRestoreIdentifierKey : kBCUBroadcastControllerRestoreIdentifier
							};
	self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.bluetoothQueue options:options];
	
}

- (void)stopBroadcasting
{
	[self.peripheralManager stopAdvertising];
	dispatch_async(self.callbackQueue, ^{
		[self.delegate broadcastControllerDidStopBroadcasting:self];
	});
}

- (void)setDataForBroadcast:(NSData *)data
{
	self.dataToSend = data;
	NSUInteger bytes[1] = { [data length] };
	NSData *notifyData = [NSData dataWithBytes:bytes length:sizeof(NSUInteger)];
 	[self.peripheralManager updateValue:notifyData forCharacteristic:self.notifyNowPlayingChangedCharacteristic onSubscribedCentrals:nil];
}

#pragma mark - CBPeripheralManagerDelegate methods

-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
	// Opt out from any other state
	if(peripheral.state == CBPeripheralManagerStateUnsupported || peripheral.state == CBPeripheralManagerStateUnauthorized)
	{
		[self handleAdvertisingFailed:nil];
		return;
	}
	
	if(peripheral.state == CBPeripheralManagerStateResetting)
	{
		NSLog(@"resetting");
	}
	
	if (peripheral.state != CBPeripheralManagerStatePoweredOn)
	{
        return;
    }
    
	[self.peripheralManager addService:self.bcuService];
	[self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[BCUServiceUUID()] }];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
	if (error)
	{
        NSLog(@"Error publishing service: %@", [error localizedDescription]);
    }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
	if(![self.peripheralManager isAdvertising])
	{
		[self handleAdvertisingFailed:error];
	}
	else
	{
		dispatch_async(self.callbackQueue, ^{
			[self.delegate broadcastControllerDidStartBroadcasting:self];
		});
	}
}

-(void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
	NSLog(@"updating subscribers");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
	if([characteristic.UUID isEqual:BCUNotifyNowPlayingChangedCharacteristicUUID()])
	{
		NSLog(@"central subscribed = %@", [central.identifier description]);
	}
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
	if([request.characteristic.UUID isEqual:BCUNowPlayingCharacteristicUUID()])
	{
		if(request.offset > self.dataToSend.length)
		{
			[self.peripheralManager respondToRequest:request withResult:CBATTErrorInvalidOffset];
		}
		else
		{
			request.value = [self.dataToSend subdataWithRange:NSMakeRange(request.offset, self.dataToSend.length - request.offset)];
			[peripheral respondToRequest:request withResult:CBATTErrorSuccess];
		}
		
	}
}

#pragma mark - helpers

- (void)handleAdvertisingFailed:(NSError *)error
{
	if(error == nil)
	{
		error = [NSError errorWithDomain:@"com.jamiepinkham.bluecue" code:-1001 userInfo:@{NSLocalizedDescriptionKey : @"Unable to start bluetooth broadcast"}];
	}
	dispatch_async(self.callbackQueue, ^{
		[self.delegate broadcastController:self didFailToStartBroadcasting:error];
	});
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
		NSLog(@"response = %@", response);
	}
	else
	{
		response = @{@"device_name" : [[UIDevice currentDevice] name], @"now_playing":[NSNull null]};
	}
	
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
	self.dataToSend = jsonData;
}

//- (void)writeDataToCentral:(CBCentral *)central
//{
//	NSArray *centrals = nil;
//	if(central)
//	{
//		centrals = @[central];
//	}
//	NSLog(@"writing data");
//	static BOOL sendingEOM = NO;
//	if(sendingEOM)
//	{
//		BOOL didSend = [self.peripheralManager updateValue:self.eomBytes forCharacteristic:self.nowPlayingCharacteristic onSubscribedCentrals:centrals];
//		
//		if(didSend)
//		{
//			sendingEOM = NO;
//		}
//		
//	}
//	
//	if(self.sendDataIndex >= self.dataToSend.length)
//	{
//		return;
//	}
//	
//	BOOL didSend = YES;
//	while (didSend)
//	{
//		NSInteger amountToSend = self.dataToSend.length - self.sendDataIndex;
//		if(amountToSend > MTU)
//		{
//			amountToSend = MTU;
//		}
//		
//		NSData *chunk = [NSData dataWithBytes:self.dataToSend.bytes + self.sendDataIndex length:amountToSend];
//		didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.nowPlayingCharacteristic onSubscribedCentrals:centrals];
//		if(!didSend)
//		{
//			return;
//		}
//		
//		NSLog(@"wrote chunk = %@", [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding]);
//		
//		self.sendDataIndex += amountToSend;
//		if(self.sendDataIndex >= self.dataToSend.length)
//		{
//			sendingEOM = YES;
//			BOOL eomSent = [self.peripheralManager updateValue:self.eomBytes forCharacteristic:self.nowPlayingCharacteristic onSubscribedCentrals:centrals];
//			if(eomSent)
//			{
//				sendingEOM = NO;
//			}
//			return;
//		}
//	}
//}


@end
