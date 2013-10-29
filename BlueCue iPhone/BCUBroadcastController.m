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
@property (nonatomic, copy) NSData *dataToSend;

@property (nonatomic, strong) NSMutableArray *subscribedCentrals;

@end


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
	}
	return self;
}

/**
 
Set up services and characteristics on your local peripheral
 
**/

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

/**
 
 
 Start up a peripheral manager object
 
 */

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
	self.peripheralManager = nil;
}

/**
 

Send updated characteristic values to subscribed centrals
 

**/

- (void)setDataForBroadcast:(NSData *)data
{
	self.dataToSend = data;
	NSUInteger bytes[1] = { [data length] };
	NSData *notifyData = [NSData dataWithBytes:bytes length:sizeof(NSUInteger)];
	if(self.notifyNowPlayingChangedCharacteristic)
	{
		[self.peripheralManager updateValue:notifyData forCharacteristic:self.notifyNowPlayingChangedCharacteristic onSubscribedCentrals:nil];
	}
}

#pragma mark - CBPeripheralManagerDelegate methods

/**
 
 
Publish your services and characteristics to your device’s local database
 
 
 **/

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
    
}

/**
 
 
 Advertise your services
  
*/

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
	if (error)
	{
        NSLog(@"Error publishing service: %@", [error localizedDescription]);
    }
	else
	{
		if([service.UUID isEqual:BCUServiceUUID()])
		{
			[self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[BCUServiceUUID()] }];
		}
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
		[self.peripheralManager stopAdvertising];
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
	if([characteristic.UUID isEqual:BCUNotifyNowPlayingChangedCharacteristicUUID()])
	{
		[self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[BCUServiceUUID()] }];
	}
}


/**
 
 Respond to read and write requests from a connected central
 
 */

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



@end
