#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPRemoteCommandCenter.h>
#import <MediaPlayer/MPRemoteCommand.h>
#import <MediaPlayer/MPMediaItem.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  // Override point for customization after application launch.
    
    //静音状态下播放
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
 
    //后台播放
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    // 在App启动后开启远程控制事件, 接收来自锁屏界面和上拉菜单的控制
    [application beginReceivingRemoteControlEvents];
 
    
   
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
