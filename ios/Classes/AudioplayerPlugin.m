#import "AudioplayerPlugin.h"
#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import "AudioPlayerNotification.h"
#import "Constants.h"

static NSString *const CHANNEL_NAME = @"bz.rxla.flutter/audio";
static FlutterMethodChannel *channel;
//static AVPlayer *player;
static AVPlayerItem *playerItem;

@interface AudioplayerPlugin()
@property(nonatomic,strong) AudioPlayerNotification *musicPlayer;

-(void)pause;
-(void)stop;
-(void)mute:(BOOL)muted;
-(void)seek:(CMTime)time;
-(void)onStart;
-(void)onTimeInterval:(CMTime)time;
@end

@implementation AudioplayerPlugin

CMTime position;
NSString *lastUrl;
BOOL isPlaying = false;
NSMutableSet *observers;
NSMutableSet *timeobservers;
FlutterMethodChannel *_channel;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:CHANNEL_NAME
                                     binaryMessenger:[registrar messenger]];
    AudioplayerPlugin* instance = [[AudioplayerPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    _channel = channel;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pause) name:MEDIA_ACTION_PAUSE object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(play) name:MEDIA_ACTION_PLAY object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stop) name:MEDIA_ACTION_STOP object:nil];
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    typedef void (^CaseBlock)(void);
    // Squint and this looks like a proper switch!
    NSDictionary *methods = @{
                              @"play":
                                  ^{
                                      NSString *url = call.arguments[@"url"];
                                      int isLocal = [call.arguments[@"isLocal"] intValue];
                                      [self play:url isLocal:isLocal];
                                      result(nil);
                                  },
                              @"pause":
                                  ^{
                                      [self pause];
                                      result(nil);
                                  },
                              @"stop":
                                  ^{
                                      [self stop];
                                      result(nil);
                                  },
                              @"mute":
                                  ^{
                                      [self mute:[call.arguments boolValue]];
                                      result(nil);
                                  },
                              @"seek":
                                  ^{
                                      [self seek:CMTimeMakeWithSeconds([call.arguments doubleValue], 1)];
                                      result(nil);
                                  }
                              };
    
    CaseBlock c = methods[call.method];
    if (c) {
        c();
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)play:(NSString*)url isLocal:(int)isLocal {
    if (![url isEqualToString:lastUrl]) {
        
        [playerItem removeObserver:self
                        forKeyPath:@"status"];
        
        for (id ob in observers) {
            [[NSNotificationCenter defaultCenter] removeObserver:ob];
        }
        observers = nil;
        
        if (isLocal) {
            playerItem = [[AVPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:url]];
        } else {
            playerItem = [[AVPlayerItem alloc] initWithURL:[NSURL URLWithString:url]];
        }
        lastUrl = url;
        
        id anobserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:playerItem queue:nil usingBlock:^(NSNotification* note){
            [self stop];
            [_channel invokeMethod:@"audio.onComplete" arguments:nil];
        }];
        [observers addObject:anobserver];
        
        [AudioPlayerNotification initSession];
        if (self.musicPlayer.avQueuePlayer) {
            [self.musicPlayer.avQueuePlayer replaceCurrentItemWithPlayerItem:playerItem];
        } else {
            if (!self.musicPlayer) {
                self.musicPlayer = [[AudioPlayerNotification alloc] init];
            }
            // Stream player position.
            // This call is only active when the player is active so there's no need to
            // remove it when player is paused or stopped.
            __weak typeof(self) weakSelf = self;
            CMTime interval = CMTimeMakeWithSeconds(0.2, NSEC_PER_SEC);
            id timeObserver = [self.musicPlayer.avQueuePlayer addPeriodicTimeObserverForInterval:interval queue:nil usingBlock:^(CMTime time){
                [weakSelf onTimeInterval:time];
            }];
            [timeobservers addObject:timeObserver];
        }
        
        // is sound ready
        [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        [playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        [playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        [playerItem addObserver:self forKeyPath:@"playbackBufferFull" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];

        [self.musicPlayer.avQueuePlayer addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        [self.musicPlayer.avQueuePlayer addObserver:self forKeyPath:@"timeControlStatus" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    }
    [self onStart];
    [self.musicPlayer playSongWithItem:playerItem];
    //    [player play];
    isPlaying = true;
}

- (void)onStart {
    CMTime duration = [[self.musicPlayer.avQueuePlayer currentItem] duration];
    if (CMTimeGetSeconds(duration) > 0) {
        int mseconds= CMTimeGetSeconds(duration)*1000;
        [_channel invokeMethod:@"audio.onStart" arguments:@(mseconds)];
    }
}

- (void)onTimeInterval:(CMTime)time {
    int mseconds =  CMTimeGetSeconds(time)*1000;
    [_channel invokeMethod:@"audio.onCurrentPosition" arguments:@(mseconds)];
}

- (void)play {
    [self.musicPlayer play];
    isPlaying = true;
    [_channel invokeMethod:@"audio.onPlay" arguments:nil];
}

- (void)pause {
    [self.musicPlayer pause];
    isPlaying = false;
    [_channel invokeMethod:@"audio.onPause" arguments:nil];
}

- (void)stop {
    isPlaying = false;
    [self.musicPlayer stop];
    [self.musicPlayer clear];
    [AudioPlayerNotification endSession];
    [[NSNotificationCenter defaultCenter] postNotificationName:MEDIA_ACTION_CHANGE_STATE object:nil userInfo:@{@"data": @[@1, @547, @0, @1.0, [self getCurrentTimeInMilis]]}];
    [_channel invokeMethod:@"audio.onStop" arguments:nil];
}

- (void)mute:(BOOL)muted {
    self.musicPlayer.avQueuePlayer.muted = muted;
}

- (void)seek:(CMTime)time {
    [playerItem seekToTime:time];
}

- (NSNumber *)getCurrentPosition {
    if (!self.musicPlayer || !self.musicPlayer.avQueuePlayer || !self.musicPlayer.avQueuePlayer.currentItem) return [NSNumber numberWithLong:0];
    long currentPosition = (long) 1000 * CMTimeGetSeconds([self.musicPlayer.avQueuePlayer.currentItem currentTime]);
    return [NSNumber numberWithLong: currentPosition];
}

- (NSNumber *)getCurrentTimeInMilis {
    long currentTimeInMilis = (long) 1000 * [[NSDate date] timeIntervalSince1970];
    return [NSNumber numberWithLong: currentTimeInMilis];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (!self.musicPlayer.avQueuePlayer) return;
    if (object == self.musicPlayer.avQueuePlayer.currentItem && [@"status" isEqualToString:keyPath]) {
        if ([[self.musicPlayer.avQueuePlayer currentItem] status] == AVPlayerItemStatusReadyToPlay) {
            [self.musicPlayer setMediaItem:@{@"title": @"Test title new", @"artist": @"Chuongvd"}];
            [self onStart];
        } else if ([[self.musicPlayer.avQueuePlayer currentItem] status] == AVPlayerItemStatusFailed) {
            [_channel invokeMethod:@"audio.onError" arguments:@[(self.musicPlayer.avQueuePlayer.currentItem.error.localizedDescription)]];
        }
    }

    if (object == self.musicPlayer.avQueuePlayer.currentItem && [@"playbackBufferEmpty" isEqualToString:keyPath]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:MEDIA_ACTION_CHANGE_STATE object:nil userInfo:@{@"data": @[@6, @547, [self getCurrentPosition], @1.0, [self getCurrentTimeInMilis]]}];
        NSLog(@"buffering...");
    }

    if (object == self.musicPlayer.avQueuePlayer.currentItem && [@"playbackLikelyToKeepUp" isEqualToString:keyPath]) {
        NSLog(@"buffering ends...");
    }

    if (object == self.musicPlayer.avQueuePlayer.currentItem && [@"playbackBufferFull" isEqualToString:keyPath]) {
        NSLog(@"buffering is hidden...");
    }

    if (object == self.musicPlayer.avQueuePlayer && [@"timeControlStatus" isEqualToString:keyPath]) {
        if (@available(iOS 10.0, *)) {
            switch (self.musicPlayer.avQueuePlayer.timeControlStatus) {
                case AVPlayerTimeControlStatusPlaying:
                {
                NSLog(@"Playing...");
                [[NSNotificationCenter defaultCenter] postNotificationName:MEDIA_ACTION_CHANGE_STATE object:nil userInfo:@{@"data": @[@3, @547, [self getCurrentPosition], @1.0, [self getCurrentTimeInMilis]]}];
                break;
                }
                case AVPlayerTimeControlStatusPaused:
                {
                NSLog(@"Paused");
                [[NSNotificationCenter defaultCenter] postNotificationName:MEDIA_ACTION_CHANGE_STATE object:nil userInfo:@{@"data": @[@2, @547, [self getCurrentPosition], @1.0, [self getCurrentTimeInMilis]]}];
                break;
                }
                case AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate:
                    NSLog(@"AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate");
                    break;
                default:
                    break;
            }
        } else {
            // Fallback on earlier versions
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    for (id ob in timeobservers) {
        [self.musicPlayer.avQueuePlayer removeTimeObserver:ob];
    }
    timeobservers = nil;
    
    for (id ob in observers) {
        [[NSNotificationCenter defaultCenter] removeObserver:ob];
    }
    observers = nil;
}

@end
