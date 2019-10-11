//
//  NSString+Extension.m
//  Runner
//
//  Created by Chuong Vu Duy on 10/2/19.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

#import "NSString+Extension.h"

@implementation NSString (Extension)

+ (BOOL)isNilOrEmpty:(NSString*)aString {
    if ([aString isKindOfClass:NSNull.class]) return YES;
    return !(aString && [NSString stringWithFormat:@"%@", aString].length);
}

+ (BOOL)containUnsign: (NSString *)data compareText:(NSString *)text {
    if ([self isNilOrEmpty:data] || [self isNilOrEmpty:text]) return NO;
    return [[data toLowerAndUnsign:data] containsString:[text toLowerAndUnsign:text]];
}

- (NSString *)toLowerAndUnsign: (NSString *) data{
    NSError *error = nil;
    data = [data lowercaseString];
    NSRegularExpression *regexA = [NSRegularExpression regularExpressionWithPattern:@"/à|á|ạ|ả|ã|â|ầ|ấ|ậ|ẩ|ẫ|ă|ằ|ắ|ặ|ẳ|ẵ/g" options:NSRegularExpressionCaseInsensitive error:&error];
    data = [regexA stringByReplacingMatchesInString:data options:0 range:NSMakeRange(0, [data length]) withTemplate:@"a"];
    NSRegularExpression *regexE = [NSRegularExpression regularExpressionWithPattern:@"/è|é|ẹ|ẻ|ẽ|ê|ề|ế|ệ|ể|ễ/g" options:NSRegularExpressionCaseInsensitive error:&error];
    data = [regexE stringByReplacingMatchesInString:data options:0 range:NSMakeRange(0, [data length]) withTemplate:@"e"];
    NSRegularExpression *regexI = [NSRegularExpression regularExpressionWithPattern:@"/ì|í|ị|ỉ|ĩ/g" options:NSRegularExpressionCaseInsensitive error:&error];
    data = [regexI stringByReplacingMatchesInString:data options:0 range:NSMakeRange(0, [data length]) withTemplate:@"i"];
    NSRegularExpression *regexO = [NSRegularExpression regularExpressionWithPattern:@"/ò|ó|ọ|ỏ|õ|ô|ồ|ố|ộ|ổ|ỗ|ơ|ờ|ớ|ợ|ở|ỡ/g" options:NSRegularExpressionCaseInsensitive error:&error];
    data = [regexO stringByReplacingMatchesInString:data options:0 range:NSMakeRange(0, [data length]) withTemplate:@"o"];
    NSRegularExpression *regexU = [NSRegularExpression regularExpressionWithPattern:@"/ù|ú|ụ|ủ|ũ|ư|ừ|ứ|ự|ử|ữ/g" options:NSRegularExpressionCaseInsensitive error:&error];
    data = [regexU stringByReplacingMatchesInString:data options:0 range:NSMakeRange(0, [data length]) withTemplate:@"u"];
    NSRegularExpression *regexY = [NSRegularExpression regularExpressionWithPattern:@"/ỳ|ý|ỵ|ỷ|ỹ/g" options:NSRegularExpressionCaseInsensitive error:&error];
    data = [regexY stringByReplacingMatchesInString:data options:0 range:NSMakeRange(0, [data length]) withTemplate:@"y"];
    NSRegularExpression *regexD = [NSRegularExpression regularExpressionWithPattern:@"/đ/g" options:NSRegularExpressionCaseInsensitive error:&error];
    data = [regexD stringByReplacingMatchesInString:data options:0 range:NSMakeRange(0, [data length]) withTemplate:@"d"];
    return data;
}

+ (NSString *)getShortName:(NSString *)fullName {
    if (!fullName) return nil;
    NSString *trimmedFullName = [fullName stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedFullName.length < 1) return nil;
    NSRange range = [trimmedFullName rangeOfString:@" " options:NSBackwardsSearch];
    if (range.location == NSNotFound || range.location >= trimmedFullName.length) return [trimmedFullName substringWithRange:NSMakeRange(0, 1)];
    return [trimmedFullName substringWithRange:NSMakeRange(range.location + 1, 1)];
}

+ (BOOL)isNewAppVersion: (NSString *)currentVersion :(NSString *)remoteVersion {
    if (![NSString isNilOrEmpty:currentVersion] || ![NSString isNilOrEmpty:remoteVersion]) return NO;
    if (![currentVersion containsString:@"."]) currentVersion = [currentVersion stringByAppendingString:@"."];
    if (![remoteVersion containsString:@"."]) remoteVersion = [remoteVersion stringByAppendingString:@"."];
    currentVersion = [NSString stringWithFormat:@"%@",currentVersion];
    remoteVersion = [NSString stringWithFormat:@"%@",remoteVersion];
    NSArray *arrayCurrent = [currentVersion componentsSeparatedByString:@"."];
    NSArray *arrayRemote = [remoteVersion componentsSeparatedByString:@"."];
    NSInteger sizeCurrent = arrayCurrent.count;
    NSInteger sizeRemote = arrayRemote.count;
    int minsize = (int) (sizeCurrent < sizeRemote ? sizeCurrent : sizeRemote);
    for (int i = 0; i < minsize; i++) {
        if ([arrayRemote[i] intValue] > [arrayCurrent[i] intValue]) return YES;
    }
    return sizeRemote > sizeCurrent;
}

@end
