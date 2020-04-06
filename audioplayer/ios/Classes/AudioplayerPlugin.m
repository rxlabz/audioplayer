#import "AudioplayerPlugin.h"
#if __has_include(<audioplayer/audioplayer-Swift.h>)
#import <audioplayer/audioplayer-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "audioplayer-Swift.h"
#endif

@implementation AudioplayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAudioplayerPlugin registerWithRegistrar:registrar];
}
@end
