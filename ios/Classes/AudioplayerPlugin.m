#import "AudioplayerPlugin.h"
#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

//#import <audioplayer/audioplayer-Swift.h>
static NSString *const CHANNEL_NAME = @"bz.rxla.flutter/audio";
static FlutterMethodChannel *channel;
static AVPlayer *player;
static AVPlayerItem *playerItem;


@interface AudioplayerPlugin()
-(void) play;
-(void) pause;
-(void) stop;
-(void) seek: (CMTime) time;
-(void) onSoundComplete:(NSNotification* )note;
-(void) updateDuration;
-(void) onTimeInterval: (CMTime) time;


@end


@implementation AudioplayerPlugin {
  FlutterResult _result;
  
}
CMTime duration;
CMTime position;
NSString *lastUrl;
BOOL isPlaying = false;
NSMutableSet *observers;


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  //  [SwiftAudioplayerPlugin registerWithRegistrar:registrar];
  FlutterMethodChannel* channel = [FlutterMethodChannel
                                   methodChannelWithName:CHANNEL_NAME
                                   binaryMessenger:[registrar messenger]];
  AudioplayerPlugin* instance = [[AudioplayerPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}


- (id)init {
  self = [super init];
  if (self) {
    player = [[AVPlayer alloc] init];
  }
  return self;
}


- (void)dealloc {
  for (id ob in observers)
    [[NSNotificationCenter defaultCenter] removeObserver:ob];
  observers = nil;
}


- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"iOS => call %@",call.method);
  
  typedef void (^CaseBlock)();
  NSDictionary *info = [[NSDictionary alloc] initWithDictionary:[call arguments]];
  
  // Squint and this looks like a proper switch!
  NSDictionary *methods = @{
                            @"play":
                              ^{
                                NSLog(@"play!");
                                NSString *url = call.arguments[@"url"];
                                if (url == nil)
                                  result(0);
                                int isLocal = [call.arguments[@"isLocal"]intValue] ;
                                NSLog(@"isLocal: %d %@",isLocal, call.arguments[@"isLocal"] );
                                [self togglePlay:url isLocal:isLocal];
                              },
                            @"pause":
                              ^{
                                NSLog(@"pause");
                                [self pause];
                              },
                            @"stop":
                              ^{
                                NSLog(@"stop");
                                [self stop];
                              },
                            @"seek":
                              ^{
                                NSLog(@"seek");
                                if(info==nil){
                                  result(0);
                                }
                                if(!info[@"seconds"]){
                                  result(0);
                                } else {
                                  double seconds = [info[@"seconds"] doubleValue];
                                  [self seek: CMTimeMakeWithSeconds(seconds,1)];
                                }
                              }
                            };
  
  CaseBlock c = methods[call.method];
  if (c) c(); else {
    NSLog(@"not implemented");
    result(FlutterMethodNotImplemented);
  }
}


-(void) play {
  
}


-(void) pause {
  [ player pause ];
  isPlaying = false;
}


-(void) stop {
  if(isPlaying){
    [ self pause ];
    [ self seek: CMTimeMake(0, 1) ];
    isPlaying = false;
    NSLog(@"stop");
  }
}


-(void) seek: (CMTime) time {
  [playerItem seekToTime:time];
}


-(void) onSoundComplete: (NSNotification*) note {
  
}


-(void) togglePlay: (NSString*) url isLocal: (int) isLocal
{
  NSLog(@"togglePlay %@",url );
  if (url != lastUrl) {
    [playerItem removeObserver:self
                    forKeyPath:@"player.currentItem.status"];
    
    // removeOnSoundComplete
    // [[ NSNotificationCenter defaultCenter] removeObserver:self];
    if( isLocal ){
      playerItem = [[ AVPlayerItem alloc]initWithURL:[NSURL fileURLWithPath:url]];
    } else {
      playerItem = [[ AVPlayerItem alloc] initWithURL:[NSURL URLWithString:url ]];
    }
    lastUrl = url;
    
    id anobserver = [[ NSNotificationCenter defaultCenter ] addObserverForName: AVPlayerItemDidPlayToEndTimeNotification
                                                                        object: playerItem
                                                                         queue: nil
                                                                    usingBlock:^(NSNotification* note){
                                                                      NSLog(@"ios -> onSoundComplete...");
                                                                      isPlaying = false;
                                                                      [ self pause ];
                                                                      [ self seek: CMTimeMakeWithSeconds(0,1)];
                                                                      [ channel invokeMethod:@"audio.onComplete" arguments: nil];
                                                                    }];
    [observers addObject:anobserver];
    
    if (player){
      [ player replaceCurrentItemWithPlayerItem: playerItem ];
    } else {
      player = [[ AVPlayer alloc ] initWithPlayerItem: playerItem ];
      
      // stream player position
      CMTime interval = CMTimeMakeWithSeconds(0.2, NSEC_PER_SEC);
      [ player  addPeriodicTimeObserverForInterval: interval queue: nil usingBlock:^(CMTime time){
        NSLog(@"time interval: %f",CMTimeGetSeconds(time));
      }];
    }
    
    // is sound ready
    //NSKeyValueObservingOptions options = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
    [[player currentItem] addObserver:self
                           forKeyPath:@"player.currentItem.status"
                              options:0
                              context:nil];
  }
  
  if (isPlaying == true ){
    pause();
  } else {
    [self updateDuration];
    [ player play];
    isPlaying = true;
  }
}


-(void) updateDuration
{
  CMTime d = [[player currentItem] duration ];
  NSLog(@"ios -> updateDuration...%f", CMTimeGetSeconds(d));
  duration = d;
  if(CMTimeGetSeconds(duration)>0){
    NSLog(@"ios -> invokechannel");
    NSNumber* mseconds = [NSNumber numberWithDouble: CMTimeGetSeconds(duration)*1000];
    [channel invokeMethod:@"audio.onDuration" arguments:[mseconds stringValue]];
  }
}


-(void) updatePosition{
  position = CMTimeMakeWithSeconds(0, 1);
}


-(void) onTimeInterval: (CMTime) time {
  NSLog(@"ios -> onTimeInterval...");
  NSNumber* mseconds = [NSNumber numberWithDouble: CMTimeGetSeconds(time)*1000];
  [channel invokeMethod:@"audio.onCurrentPosition" arguments:[mseconds stringValue]];
}

-(void)observeValueForKeyPath:(NSString *)keyPath
ofObject:(id)object
change:(NSDictionary *)change
context:(void *)context {
  
  if ([keyPath isEqualToString: @"player.currentItem.status"]) {
    // Do something with the status…
    if ([[player currentItem] status ] == AVPlayerItemStatusReadyToPlay) {
      [self updateDuration];
    } else if ([[player currentItem] status ] == AVPlayerItemStatusFailed) {
       [channel invokeMethod:@"audio.onError" arguments:@"AVPlayerItemStatus.failed" ];
    }
  } else {
    // Any unrecognized context must belong to super
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
  }
}


@end
