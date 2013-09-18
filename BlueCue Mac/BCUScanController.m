//
//  BCUScanController.m
//  BlueCue
//
//  Created by Jamie Pinkham on 9/12/13.
//  Copyright (c) 2013 Jamie Pinkham. All rights reserved.
//

#import "BCUScanController.h"
#import "BCUServiceIdentifiers.h"
#import <IOBluetooth/IOBluetooth.h>

@interface BCUScanController () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, weak) id<BCUScanControllerDelegate> delegate;
@property (nonatomic, assign, getter = isScanning) BOOL scanning;
@property (nonatomic, strong) CBCharacteristic * notifyNowPlayingChangedCharacteristic;
@property (nonatomic, strong) CBCharacteristic *nowPlayingCharacteristic;
@property (nonatomic, strong) dispatch_queue_t bluetoothQueue;
@property (nonatomic, strong) NSMutableArray *inRangePeripherals;
@property (nonatomic, strong) NSMutableArray *scanningPeripherals;
@property (nonatomic, strong) NSMutableSet *informedPeripherals;

@property (nonatomic, strong) NSMutableData *jsonData;
@property (nonatomic, strong) NSData *eomBytes;

@end

@implementation BCUScanController

- (instancetype)initWithDelegate:(id<BCUScanControllerDelegate>)delegate queue:(dispatch_queue_t)queue
{
	self = [super init];
	if (self)
	{
		if(queue == NULL)
		{
			queue = dispatch_get_main_queue();
		}
		self.callbackQueue = queue;
		self.delegate = delegate;
		self.bluetoothQueue = dispatch_queue_create("com.jamiepinkham.bluecue-scan", NULL);
		uint8_t bytes[2] = {
            0xFF, 0xD9
        };
        self.eomBytes = [NSData dataWithBytes:bytes length:2];
		self.informedPeripherals = [NSMutableSet new];
	}
	return self;
}

- (void)startScanning
{
	self.inRangePeripherals = [NSMutableArray new];
	self.scanningPeripherals = [NSMutableArray new];
	self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.bluetoothQueue];
}

- (void)stopScanning
{
	self.notifyNowPlayingChangedCharacteristic = nil;
	self.nowPlayingCharacteristic = nil;
	self.inRangePeripherals = nil;
	self.scanningPeripherals = nil;
	[self.centralManager stopScan];
	dispatch_async(self.callbackQueue, ^{
		[self.delegate scanControllerStoppedScanningForDevices:self];
	});
	self.scanning = NO;
}

- (void)handleFailToScan:(NSError *)error
{
	if(error == nil)
	{
		error = [NSError errorWithDomain:@"com.jamiepinkham.bluecue" code:-1002 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to start bluetooth scan" }];
	}
	dispatch_async(self.callbackQueue, ^{
		[self.delegate scanController:self failedToScanForDevices:error];
	});
}

- (void)handleFailToConnect:(CBPeripheral *)aPeripheral underlyingError:(NSError *)error
{
	NSMutableDictionary *userInfo = [NSMutableDictionary new];
	if(aPeripheral == nil)
	{
		[userInfo setObject:@"No peripheral to connect to" forKey:NSLocalizedDescriptionKey];
	}
	else if(!aPeripheral.isConnected)
	{
		[userInfo setObject:@"Connect to peripheral first" forKey:NSLocalizedDescriptionKey];
	}
	else if(self.notifyNowPlayingChangedCharacteristic == nil)
	{
		[userInfo setObject:@"No now playing characteristic available" forKey:NSLocalizedDescriptionKey];
	}
	
	if(error != nil)
	{
		[userInfo setObject:error forKey:NSUnderlyingErrorKey];
	}
	NSError *finalError = [NSError errorWithDomain:@"com.jamiepinkha.bluecue" code:-1003 userInfo:userInfo];
	dispatch_async(self.callbackQueue, ^{
		[self.delegate scanControllerFailedToScan:self peripheral:aPeripheral error:finalError];
	});
}

#pragma mark - CBCentralManagerDelegate methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
	
	if(central.state == CBCentralManagerStateUnauthorized || central.state == CBCentralManagerStateUnsupported)
	{
		[self handleFailToScan:nil];
	}
	
	if(central.state != CBCentralManagerStatePoweredOn)
	{
		return;
	}
	
	[self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
	dispatch_async(self.callbackQueue, ^{
		[self.delegate scanControllerStartedScanningForDevices:self];
	});
	self.scanning = YES;
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
	NSArray *services = [advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
	if([services containsObject:BCUServiceUUID()])
	{
		if(![self.informedPeripherals containsObject:CFBridgingRelease(CFUUIDCreateString(NULL, peripheral.UUID))])
		{
			[self.informedPeripherals addObject:CFBridgingRelease(CFUUIDCreateString(NULL, peripheral.UUID))];
			[self.delegate scanController:self foundDevice:peripheral.UUID];
		}
	}
	if([RSSI integerValue] >= -60)
	{
		if(![self.inRangePeripherals containsObject:peripheral])
		{
			[self.inRangePeripherals addObject:peripheral];
			
			if(![self.scanningPeripherals containsObject:peripheral])
			{
				BOOL shouldConnect = [self.delegate scanController:self shouldConnectToPeripheral:peripheral.UUID];
				if(shouldConnect)
				{
					[self.scanningPeripherals addObject:peripheral];
					[self.centralManager connectPeripheral:peripheral options:nil];
				}
			}
		}
	}
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
//	[peripheral readRSSI];
	[peripheral setDelegate:self];
	[peripheral discoverServices:@[BCUServiceUUID()]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
	NSLog(@"disconnecting peripheral = %@", CFBridgingRelease(CFUUIDCreateString(NULL, peripheral.UUID)));
	[self.scanningPeripherals removeObject:peripheral];
	[self.inRangePeripherals removeObject:peripheral];
}

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
	[self.scanningPeripherals removeObject:peripheral];
	[self handleFailToConnect:peripheral underlyingError:error];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
	for(CBService *aService in peripheral.services)
	if([aService.UUID isEqual:BCUServiceUUID()])
	{
		[peripheral discoverCharacteristics:@[BCUNowPlayingCharacteristicUUID(), BCUNotifyNowPlayingChangedCharacteristicUUID()] forService:aService];
	}
	else
	{
		[self handleFailToConnect:peripheral underlyingError:nil];
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
	if([service.UUID isEqual:BCUServiceUUID()])
	{
		for(CBCharacteristic *aChar in service.characteristics)
		{
			if([aChar.UUID isEqual:BCUNowPlayingCharacteristicUUID()])
			{
				self.nowPlayingCharacteristic = aChar;
				[peripheral readValueForCharacteristic:aChar];
			}
			if([aChar.UUID isEqual:BCUNotifyNowPlayingChangedCharacteristicUUID()])
			{
				self.notifyNowPlayingChangedCharacteristic = aChar;
				[peripheral setNotifyValue:YES forCharacteristic:aChar];
			}
		}
	}
	
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	if([characteristic.UUID isEqual:BCUNotifyNowPlayingChangedCharacteristicUUID()])
	{
		if(!characteristic.isNotifying)
		{
			[self.centralManager cancelPeripheralConnection:peripheral];
		}
			
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	if([characteristic.UUID isEqual:BCUNowPlayingCharacteristicUUID()])
	{
		if(characteristic.value)
		{
			NSError *jsonError = nil;
			NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:characteristic.value options:0 error:&jsonError];
			if(dict)
			{
				[self.delegate scanController:self recievedNowPlayingInfo:dict[@"now_playing"] forDevice:dict[@"device_name"]];
				[self.scanningPeripherals removeObject:peripheral];
			}
			else
			{
				NSString *response = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
				NSLog(@"error parsing this response: %@\r\nerror: %@", response, error);
			}
			
		}
	}
	else if ([characteristic.UUID isEqual:BCUNotifyNowPlayingChangedCharacteristicUUID()])
	{
		NSLog(@"notify changed");
		[peripheral readValueForCharacteristic:self.nowPlayingCharacteristic];
	}
}


- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
	NSLog(@"rssi = %@",[peripheral RSSI]);
	NSInteger rssiValue = [[peripheral RSSI] integerValue];
	if(rssiValue < -70 && peripheral.isConnected)
	{
		[self.inRangePeripherals removeObject:peripheral];
		[self.centralManager cancelPeripheralConnection:peripheral];
	}
	double delayInSeconds = 2.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		[peripheral readRSSI];
	});
}



@end
