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
                                      NSString *name = call.arguments[@"name"];
                                      NSString *albumName = call.arguments[@"albumName"];
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
    [playerItem seekToTime:time];
}

//on phone call
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
        //NSLog(@"AVAudioSessionInterruptionTypeBegan");
    }else if (interuptionType == AVAudioSessionInterruptionTypeEnded) {
        //NSLog(@"AVAudioSessionInterruptionTypeEnded");
        if(!isPlaying){
            [self resume];
        }
        
    }
}


+ (void)configNowPlayingInfoCenter
{
    //NSLog(@"configNowPlayingInfoCenter");
    Class playingInfoCenter = NSClassFromString(@"MPNowPlayingInfoCenter");
    if (playingInfoCenter) {
        NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
        [songInfo setObject:m_Name forKey:MPMediaItemPropertyTitle];
        //演唱者
        [songInfo setObject:m_Author forKey:MPMediaItemPropertyArtist];
        //专辑名
        [songInfo setObject:m_AlbumName forKey:MPMediaItemPropertyAlbumTitle];
        //音乐当前已经播放时间
        NSInteger currentTime = m_mseconds;
        [songInfo setObject:[NSNumber numberWithInteger:currentTime] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
        //进度光标的速度 （这个随 自己的播放速率调整，我默认是原速播放）
        [songInfo setObject:[NSNumber numberWithFloat:1.0] forKey:MPNowPlayingInfoPropertyPlaybackRate];
        //歌曲总时间设置
        NSInteger duration = m_totalmseconds;
        [songInfo setObject:[NSNumber numberWithInteger:duration] forKey:MPMediaItemPropertyPlaybackDuration];
        //设置锁屏状态下屏幕显示音乐信息
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



// 在需要处理远程控制事件的具体控制器或其它类中实现
+ (void)remoteControlEventHandler
{
   // NSLog(@"remoteControlEventHandler");
    // 直接使用sharedCommandCenter来获取MPRemoteCommandCenter的shared实例
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    // 启用播放命令 (锁屏界面和上拉快捷功能菜单处的播放按钮触发的命令)
    commandCenter.playCommand.enabled = YES;
    // 为播放命令添加响应事件, 在点击后触发
    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [AudioplayerPlugin playCommand];
        [self configNowPlayingInfoCenter];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    // 播放, 暂停, 上下曲的命令默认都是启用状态, 即enabled默认为YES
    [commandCenter.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        //点击了暂停
        [AudioplayerPlugin pauseCommand];
        [self configNowPlayingInfoCenter];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        //点击了上一首
        [AudioplayerPlugin previousTrackCommand];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        //点击了下一首
        [AudioplayerPlugin nextTrackCommand];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    // 启用耳机的播放/暂停命令 (耳机上的播放按钮触发的命令)
    commandCenter.togglePlayPauseCommand.enabled = YES;
    // 为耳机的按钮操作添加相关的响应事件
    [commandCenter.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        // 进行播放/暂停的相关操作 (耳机的播放/暂停按钮)
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
