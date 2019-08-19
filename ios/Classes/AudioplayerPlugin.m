#import "AudioplayerPlugin.h"
#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPRemoteCommandCenter.h>
#import <MediaPlayer/MPRemoteCommand.h>
#import <MediaPlayer/MPMediaItem.h>


static NSString *const CHANNEL_NAME = @"bz.rxla.flutter/audio";
static FlutterMethodChannel *channel;
static AVPlayer *player;
static AVPlayerItem *playerItem;
static int  m_mseconds=0;
static int  m_totalmseconds=0;
static NSString *m_Author=@"";
static NSString *m_Name=@"";
static NSString *m_AlbumName=@"";

@interface AudioplayerPlugin()
-(void)pause;
-(void)stop;
-(void)resume;
-(void)mute:(BOOL)muted;
-(void)seek:(CMTime)time;
-(void)onStart;
-(void)onTimeInterval:(CMTime)time;
-(void)interruptionNotificationHandler:(NSNotification*)notification;
@end

@implementation AudioplayerPlugin

CMTime position;
NSString *lastUrl;
BOOL lastMode;
BOOL isLoading = false;
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
    [AudioplayerPlugin remoteControlEventHandler];

}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    typedef void (^CaseBlock)(void);
    // Squint and this looks like a proper switch!
    NSDictionary *methods = @{
                              @"play":
                                  ^{
                                      NSString *url = call.arguments[@"url"];
                                      int isLocal = [call.arguments[@"isLocal"] intValue];
                                      NSString *author = call.arguments[@"author"];
                                      NSString *name = call.arguments[@"bookName"];
                                      NSString *albumName = call.arguments[@"sectionName"];
                                      [self play:url isLocal:isLocal author:author name:name albumName:albumName];
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
                                  },
                              @"changeSpeed":
                                  ^{
                                      [self changeSpeed:[call.arguments doubleValue]];
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

- (void)play:(NSString*)url
     isLocal:(int)isLocal
      author:(NSString*)author
        name:(NSString*)name
   albumName:(NSString*)albumName
{
    m_Author=author;
    m_Name = name;
    m_AlbumName= albumName;
    isLoading=true;
    [AudioplayerPlugin configNowPlayingInfoCenter];

    if (![url isEqualToString:lastUrl]) {
        [playerItem removeObserver:self
                        forKeyPath:@"player.currentItem.status"];

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

        id anobserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                                          object:playerItem
                                                                           queue:nil
                                                                      usingBlock:^(NSNotification* note){
                                                                          [self stop];
                                                                          [_channel invokeMethod:@"audio.onComplete" arguments:nil];
                                                                      }];
        [observers addObject:anobserver];

        // on phone call
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interruptionNotificationHandler:) name:AVAudioSessionInterruptionNotification object:nil];


        if (player) {
            [player replaceCurrentItemWithPlayerItem:playerItem];
        } else {
            player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
            // Stream player position.
            // This call is only active when the player is active so there's no need to
            // remove it when player is paused or stopped.
            CMTime interval = CMTimeMakeWithSeconds(0.2, NSEC_PER_SEC);
            id timeObserver = [player addPeriodicTimeObserverForInterval:interval queue:nil usingBlock:^(CMTime time){
                [self onTimeInterval:time];
            }];
            [timeobservers addObject:timeObserver];
        }

        // is sound ready
        [[player currentItem] addObserver:self
                               forKeyPath:@"player.currentItem.status"
                                  options:0
                                  context:nil];
    }
    [self onLoading];
    [player play];
    isPlaying = true;
}

- (void)onLoading{
    [_channel invokeMethod:@"audio.onLoading" arguments:nil];
}


- (void)onStart {
    CMTime duration = [[player currentItem] duration];
    if (CMTimeGetSeconds(duration) > 0) {
        isLoading = false;
        m_totalmseconds =CMTimeGetSeconds(duration);
        int mseconds=m_totalmseconds *1000;
        [AudioplayerPlugin configNowPlayingInfoCenter];
        [_channel invokeMethod:@"audio.onStart" arguments:@(mseconds)];
    }
}

- (void)changeSpeed:(double)speed {
    player.rate = speed;
    [_channel invokeMethod:@"audio.onSpeed" arguments:@((float) speed)];
}


- (void)onTimeInterval:(CMTime)time {
    m_mseconds=CMTimeGetSeconds(time);
    int mseconds = m_mseconds *1000;
    if (( isLoading ) && (mseconds > 0 )) {
        [self onStart];
    }
    [_channel invokeMethod:@"audio.onCurrentPosition" arguments:@(mseconds)];
}

- (void)pause {
    [player pause];
    isPlaying = false;
    [_channel invokeMethod:@"audio.onPause" arguments:nil];
}

- (void)resume {
    if (player == NULL)
        return;
    [player play];
    isPlaying = true;
    [_channel invokeMethod:@"audio.onResume" arguments:nil];
}

- (void)stop {
    if (isPlaying) {
        [player pause];
        isPlaying = false;
    }
    [playerItem seekToTime:CMTimeMake(0, 1)];
    [_channel invokeMethod:@"audio.onStop" arguments:nil];
}

- (void)mute:(BOOL)muted {
    player.muted = muted;
    [_channel invokeMethod:@"audio.onMute" arguments:@(muted)];
}

- (void)seek:(CMTime)time {
    m_mseconds=CMTimeGetSeconds(time);
    [playerItem seekToTime:time];
    [AudioplayerPlugin configNowPlayingInfoCenter];
}

- (void)interruptionNotificationHandler:(NSNotification*)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    NSString *type = [NSString stringWithFormat:@"%@", [interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey]];
    NSUInteger interuptionType = [type integerValue];

    if (interuptionType == AVAudioSessionInterruptionTypeBegan) {
        if(isPlaying)
        {
            [self pause];
        }
    }else if (interuptionType == AVAudioSessionInterruptionTypeEnded) {
        if(!isPlaying){
            [self resume];
        }

    }
}


+ (void)configNowPlayingInfoCenter
{
    Class playingInfoCenter = NSClassFromString(@"MPNowPlayingInfoCenter");
    if (playingInfoCenter) {
        NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
        [songInfo setObject:m_Name forKey:MPMediaItemPropertyTitle];
        [songInfo setObject:m_Author forKey:MPMediaItemPropertyArtist];
        [songInfo setObject:m_AlbumName forKey:MPMediaItemPropertyAlbumTitle];
        NSInteger currentTime = m_mseconds;
        [songInfo setObject:[NSNumber numberWithInteger:currentTime] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
        [songInfo setObject:[NSNumber numberWithFloat:1.0] forKey:MPNowPlayingInfoPropertyPlaybackRate];
        NSInteger duration = m_totalmseconds;
        [songInfo setObject:[NSNumber numberWithInteger:duration] forKey:MPMediaItemPropertyPlaybackDuration];
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
    }
}


+ (void)nextTrackCommand {
    [_channel invokeMethod:@"audio.nextTrackCommand" arguments:nil];
}

+ (void)previousTrackCommand {
    [_channel invokeMethod:@"audio.previousTrackCommand" arguments:nil];
}

+ (void)playCommand {
    [_channel invokeMethod:@"audio.playCommand" arguments:nil];
}

+ (void)pauseCommand {
    [_channel invokeMethod:@"audio.pauseCommand" arguments:nil];
}

+ (void)togglePlayPauseCommand {
    [_channel invokeMethod:@"audio.togglePlayPauseCommand" arguments:nil];
}

+ (void)remoteControlEventHandler
{
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    commandCenter.playCommand.enabled = YES;
    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [AudioplayerPlugin playCommand];
        [self configNowPlayingInfoCenter];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [AudioplayerPlugin pauseCommand];
        [self configNowPlayingInfoCenter];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [AudioplayerPlugin previousTrackCommand];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [AudioplayerPlugin nextTrackCommand];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    commandCenter.togglePlayPauseCommand.enabled = YES;
    [commandCenter.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [AudioplayerPlugin togglePlayPauseCommand];
        [self configNowPlayingInfoCenter];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}



- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"player.currentItem.status"]) {
        if ([[player currentItem] status] == AVPlayerItemStatusReadyToPlay) {
            [self onStart];
        } else if ([[player currentItem] status] == AVPlayerItemStatusFailed) {
            [_channel invokeMethod:@"audio.onError" arguments:@[(player.currentItem.error.localizedDescription)]];
        }
    } else {
        // Any unrecognized context must belong to super
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

- (void)dealloc {
    for (id ob in timeobservers) {
        [player removeTimeObserver:ob];
    }
    timeobservers = nil;

    for (id ob in observers) {
        [[NSNotificationCenter defaultCenter] removeObserver:ob];
    }
    observers = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
}

@end
