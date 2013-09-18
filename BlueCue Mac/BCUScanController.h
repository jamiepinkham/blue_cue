//
//  BCUScanController.h
//  BlueCue
//
//  Created by Jamie Pinkham on 9/12/13.
//  Copyright (c) 2013 Jamie Pinkham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
#import <CoreBluetooth/CoreBluetooth.h>
#elif TARGET_OS_MAC
#import <IOBluetooth/IOBluetooth.h>
#endif


@protocol BCUScanControllerDelegate;

@interface BCUScanController : NSObject

- (instancetype)initWithDelegate:(id<BCUScanControllerDelegate>)delegate queue:(dispatch_queue_t)queue;

- (void)startScanning;
- (void)stopScanning;

@property (nonatomic, readonly, getter = isScanning) BOOL scanning;

@end

@protocol BCUScanControllerDelegate <NSObject>

- (void)scanControllerStartedScanningForDevices:(BCUScanController *)scanController;
- (void)scanControllerStoppedScanningForDevices:(BCUScanController *)scanController;
- (void)scanController:(BCUScanController *)scanController failedToScanForDevices:(NSError *)error;
- (void)scanController:(BCUScanController *)scanController foundDevice:(CFUUIDRef)deviceUUID;
- (BOOL)scanController:(BCUScanController *)scanController shouldConnectToPeripheral:(CFUUIDRef)deviceUUID;
- (void)scanController:(BCUScanController *)scanController recievedNowPlayingInfo:(NSDictionary *)info forDevice:(NSString *)device;
- (void)scanControllerFailedToScan:(BCUScanController *)scanController peripheral:(CBPeripheral *)peripheral error:(NSError *)error;

@end
