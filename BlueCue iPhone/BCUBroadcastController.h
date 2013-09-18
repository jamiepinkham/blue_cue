//
//  BCUBluetoothController.h
//  BlueCue iPhone
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

@protocol BCUBroadcastControllerDelegate;

@interface BCUBroadcastController : NSObject

- (instancetype)initWithDelegate:(id<BCUBroadcastControllerDelegate>)delegate queue:(dispatch_queue_t)queue;

- (void)startBroadcasting;
- (void)stopBroadcasting;
- (void)setDataForBroadcast:(NSData *)data;

@property (nonatomic, readonly, getter = isBroadcasting) BOOL broadcasting;

@end

@protocol BCUBroadcastControllerDelegate <NSObject>

- (void)broadcastControllerDidStartBroadcasting:(BCUBroadcastController *)controller;
- (void)broadcastControllerDidStopBroadcasting:(BCUBroadcastController *)controller;
- (void)broadcastController:(BCUBroadcastController *)controller didRecieveConnectionRequest:(NSString *)centralName;
- (void)broadcastController:(BCUBroadcastController *)controller didFailToStartBroadcasting:(NSError *)error;

@end
