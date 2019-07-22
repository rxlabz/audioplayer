//
//  AudioPlayerNotification.m
//  audioplayer
//
//  Created by Chuong Vu Duy on 7/9/19.
//

#import "AudioPlayerNotification.h"
#import <MediaPlayer/MediaPlayer.h>
#import "NSString+Extension.h"

@implementation AudioPlayerNotification


+ (void)initSession {
    NSLog(@"AudioPlayerNotification initSession");
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector:    @selector(audioSessionInterrupted:)
                                                 name:        AVAudioSessionInterruptionNotification
                                               object:      [AVAudioSession sharedInstance]];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [[UIApplication sharedApplication] becomeFirstResponder];
    //set audio category with options - for this demo we'll do playback only
    NSError *categoryError = nil;
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:&categoryError];

    if (categoryError) {
        NSLog(@"Error setting category! %@", [categoryError description]);
    }

    //activation of audio session
    NSError *activationError = nil;
    BOOL success = [[AVAudioSession sharedInstance] setActive: YES error: &activationError];
    if (!success) {
        if (activationError) {
            NSLog(@"Could not activate audio session. %@", [activationError localizedDescription]);
        } else {
            NSLog(@"audio session could not be activated!");
        }
    }
}

+ (void)endSession {
    NSLog(@"AudioPlayerNotification endSession");
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name:        AVAudioSessionInterruptionNotification
                                                  object:      [AVAudioSession sharedInstance]];
    //set audio category with options - for this demo we'll do playback only
    NSError *categoryError = nil;
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:&categoryError];

    if (categoryError) {
        NSLog(@"Error setting category! %@", [categoryError description]);
    }

    //activation of audio session
    NSError *activationError = nil;
    BOOL success = [[AVAudioSession sharedInstance] setActive:NO error: &activationError];
    if (!success) {
        if (activationError) {
            NSLog(@"Could not activate audio session. %@", [activationError localizedDescription]);
        } else {
            NSLog(@"audio session could not be activated!");
        }
    }
}

- (void)playSongWithUrl:(NSURL *)url {
    if (url) {
        AVPlayerItem *avSongItem = [[AVPlayerItem alloc] initWithURL:url];
        [self playSongWithItem:avSongItem];
    } else {
        NSLog(@"ERROR: url not found: %@", url);
    }
}

- (void)playSongWithItem:(AVPlayerItem *)avSongItem {
    if (avSongItem) {
        self.currentUrl = [avSongItem.asset isKindOfClass:AVURLAsset.class] ? [(AVURLAsset *)avSongItem.asset URL] : [[NSURL alloc] init];
        if (![[self avQueuePlayer] canInsertItem:avSongItem afterItem:nil]) return;
        [[self avQueuePlayer] insertItem:avSongItem afterItem:nil];
        [self play];
        // Set command center
        [self setCommandState:3];
        MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
        [[commandCenter playCommand] addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
            if (self.avQueuePlayer && !self.avQueuePlayer.currentItem) {
                [self playSongWithUrl:self.currentUrl];
            } else {
                [self setCommandState:3];
                [self play];
            }
            return MPRemoteCommandHandlerStatusSuccess;
        }];
        [[commandCenter pauseCommand] addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
            [self setCommandState:1];
            [self pause];
            return MPRemoteCommandHandlerStatusSuccess;
        }];
        [[commandCenter stopCommand] addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
            [self setCommandState:1];
            [self stop];
            [self clear];
            return MPRemoteCommandHandlerStatusSuccess;
        }];
    }
}

-(void) playSongWithUrl:(NSURL*)url songTitle:(NSString*)songTitle artist:(NSString*)artist
{
    if (url) {
        AVPlayerItem *avSongItem = [[AVPlayerItem alloc] initWithURL:url];
        [self playSongWithItem:avSongItem songTitle:songTitle artist:artist];
    } else {
        NSLog(@"ERROR: url not found: %@", url);
    }
}

- (void)playSongWithItem:(AVPlayerItem *)avSongItem songTitle:(NSString *)songTitle artist:(NSString *)artist {
    if (avSongItem) {
        self.currentUrl = [avSongItem.asset isKindOfClass:AVURLAsset.class] ? [(AVURLAsset *)avSongItem.asset URL] : [[NSURL alloc] init];
        if (![[self avQueuePlayer] canInsertItem:avSongItem afterItem:nil]) return;
        [[self avQueuePlayer] insertItem:avSongItem afterItem:nil];
        [self play];
        
        // Set Song Info
        NSDictionary *songInfo = @{MPMediaItemPropertyTitle: songTitle,
                                   MPMediaItemPropertyArtist: artist
        };
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = songInfo;
        
        // Set command center
         [self setCommandState:3];
        MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
        [[commandCenter pauseCommand] addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
            [self pause];
            return MPRemoteCommandHandlerStatusSuccess;
        }];
        [[commandCenter playCommand] addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
            if (self.avQueuePlayer && CMTimeGetSeconds(self.avQueuePlayer.currentTime) == 0) {
                [self playSongWithUrl:self.currentUrl songTitle:songTitle artist:artist];
            }
            [self play];
            return MPRemoteCommandHandlerStatusSuccess;
        }];
    }
}

- (void)setMediaItem:(NSDictionary *)arguments {
    NSString *title = [arguments objectForKey:@"title"];
    NSString *artist = [arguments objectForKey:@"artist"];
    // Set Song Info
    NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
    if (![NSString isNilOrEmpty:title]) [songInfo setValue:title forKey:MPMediaItemPropertyTitle];
    if (![NSString isNilOrEmpty:artist]) [songInfo setValue:artist forKey:MPMediaItemPropertyArtist];
    if (@available(iOS 10.0, *)) {
        [songInfo setValue:[NSNumber numberWithBool:YES] forKey:MPNowPlayingInfoPropertyIsLiveStream];
    } else {
        // Fallback on earlier versions
    }
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = songInfo;
}

#pragma mark - notifications
+ (void) audioSessionInterrupted:(NSNotification*)interruptionNotification
{
    NSLog(@"interruption received: %@", interruptionNotification);
}

#pragma mark - player actions
- (void) pause {
    [[self avQueuePlayer] pause];
}

- (void) play {
    [[self avQueuePlayer] play];
}

- (void)stop {
    [self.avQueuePlayer pause];
    [self.avQueuePlayer seekToTime:CMTimeMake(0, 1)];
    [self.avQueuePlayer setRate:0];
}

- (void) clear {
    [[self avQueuePlayer] removeAllItems];
}

- (void)setCommandState:(int)state {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    switch (state) {
        case 1:
        {
        [[commandCenter previousTrackCommand] setEnabled:NO];
        [[commandCenter nextTrackCommand] setEnabled:NO];
        [[commandCenter togglePlayPauseCommand] setEnabled:NO];
        [[commandCenter seekForwardCommand] setEnabled:NO];
        [[commandCenter seekBackwardCommand] setEnabled:NO];
        [[commandCenter playCommand] setEnabled:YES];
        [[commandCenter pauseCommand] setEnabled:NO];
        [[commandCenter stopCommand] setEnabled:NO];
        }
            break;
        case 2:
        {
        [[commandCenter previousTrackCommand] setEnabled:NO];
        [[commandCenter nextTrackCommand] setEnabled:NO];
        [[commandCenter togglePlayPauseCommand] setEnabled:NO];
        [[commandCenter seekForwardCommand] setEnabled:NO];
        [[commandCenter seekBackwardCommand] setEnabled:NO];
        [[commandCenter playCommand] setEnabled:YES];
        [[commandCenter pauseCommand] setEnabled:NO];
        [[commandCenter stopCommand] setEnabled:NO];
        }
            break;
        case 3:
        {
        [[commandCenter previousTrackCommand] setEnabled:NO];
        [[commandCenter nextTrackCommand] setEnabled:NO];
        [[commandCenter togglePlayPauseCommand] setEnabled:NO];
        [[commandCenter seekForwardCommand] setEnabled:NO];
        [[commandCenter seekBackwardCommand] setEnabled:NO];
        [[commandCenter playCommand] setEnabled:NO];
        [[commandCenter pauseCommand] setEnabled:NO];
        [[commandCenter stopCommand] setEnabled:YES];
        }
            break;
        default:
            break;
    }
}

- (void) dispose {
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [[UIApplication sharedApplication] resignFirstResponder];
}

- (AVPlayer *)avQueuePlayer {
    if (!_avQueuePlayer) {
        _avQueuePlayer = [[AVQueuePlayer alloc]init];
    }

    return _avQueuePlayer;
}


@end
