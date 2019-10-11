//
//  AudioPlayerNotification.h
//  audioplayer
//
//  Created by Chuong Vu Duy on 7/9/19.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioPlayerNotification : NSObject
@property(nonatomic, strong) AVQueuePlayer *avQueuePlayer;
@property(nonatomic, strong) NSURL *currentUrl;
//initialize the audio session
+(void) initSession;
+(void) endSession;
-(void) playSongWithUrl:(NSURL *)url;
-(void) playSongWithItem:(AVPlayerItem *)url;
-(void) playSongWithUrl:(NSURL *)url songTitle:(NSString *)songTitle artist:(NSString *)artist;
-(void) playSongWithItem:(AVPlayerItem *)url songTitle:(NSString *)songTitle artist:(NSString *)artist;
-(void) setMediaItem:(NSDictionary *)arguments;
-(void) pause;
-(void) play;
-(void) stop;
-(void) clear;
-(void) dispose;
- (void)setCommandState:(int)state;
@end

NS_ASSUME_NONNULL_END
