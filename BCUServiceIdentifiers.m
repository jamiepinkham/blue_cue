//
//  BCUServiceIdentifiers.m
//  BlueCue iPhone
//
//  Created by Jamie Pinkham on 9/12/13.
//  Copyright (c) 2013 Jamie Pinkham. All rights reserved.
//

#import "BCUServiceIdentifiers.h"

static CBUUID *_serviceUUID;

extern CBUUID* BCUServiceUUID(void)
{
	if(_serviceUUID == nil)
	{
		_serviceUUID = [CBUUID UUIDWithString:@"797215EF-51E3-4DA3-B0F8-39D6EFA7FDA9"];
	}
	return _serviceUUID;
}

static CBUUID *_nowPlayingCharUUID;
extern CBUUID* BCUNowPlayingCharacteristicUUID(void)
{
	if(_nowPlayingCharUUID == nil)
	{
		_nowPlayingCharUUID = [CBUUID UUIDWithString:@"26B53DF1-4B4C-4939-8C3E-DFD05B37FDDC"];
	}
	return _nowPlayingCharUUID;
}

static CBUUID *_notifyNowPlayingChangedCharacteristic;
extern CBUUID* BCUNotifyNowPlayingChangedCharacteristicUUID(void)
{
	if (_notifyNowPlayingChangedCharacteristic == nil)
	{
		_notifyNowPlayingChangedCharacteristic = [CBUUID UUIDWithString:@"C4762F59-D048-4BE2-891E-E3951A7808E2"];
	}
	return _notifyNowPlayingChangedCharacteristic;
}