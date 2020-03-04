//
//  NSString+Extension.h
//  Runner
//
//  Created by Chuong Vu Duy on 10/2/19.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Extension)

+ (BOOL)isNilOrEmpty:(NSString*)aString;

+ (BOOL)containUnsign: (NSString *)data compareText:(NSString *)text;

+ (BOOL)isNewAppVersion: (NSString *)currentVersion :(NSString *)remoteVersion;

+ (NSString *)getShortName:(NSString *)fullName;
@end

NS_ASSUME_NONNULL_END
