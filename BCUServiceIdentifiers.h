//
//  BCUServiceIdentifiers.h
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


extern CBUUID* BCUServiceUUID(void);
extern CBUUID* BCUNowPlayingCharacteristicUUID(void);
extern CBUUID* BCUNotifyNowPlayingChangedCharacteristicUUID(void);
