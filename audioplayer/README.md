# AudioPlayer

A Flutter audio plugin (Swift/Java) to play remote or local audio files on iOS / Android / MacOS / Web.

[Online demo](https://rxlabz.github.io/audioplayer/)

## Features

- [x] Android / iOS / MacOS / Web
  - [x] play remote file 
  - [x] play local file ( not for the web)  
  - [x] stop
  - [x] pause
  - [x] onComplete
  - [x] onDuration / onCurrentPosition
  - [x] seek
  - [x] mute

![screenshot](https://rxlabz.github.io/audioplayer/audioplayer.png)

## Usage

[Example](https://github.com/rxlabz/audioplayer/blob/master/example/lib/main.dart)

To use this plugin :

- Add the dependency to your [pubspec.yaml](https://github.com/rxlabz/audioplayer/blob/master/example/pubspec.yaml) file.

```yaml
  dependencies:
    flutter:
      sdk: flutter
    audioplayer: 0.8.1
    audioplayer_web: 0.7.1
```

- Instantiate an AudioPlayer instance

```dart
//...
AudioPlayer audioPlugin = AudioPlayer();
//...
```

### Player Controls

```dart
audioPlayer.play(url);

audioPlayer.pause();

audioPlayer.stop();
```

### Status and current position

The dart part of the plugin listen for platform calls :

```dart
//...
_positionSubscription = audioPlayer.onAudioPositionChanged.listen(
  (p) => setState(() => position = p)
);

_audioPlayerStateSubscription = audioPlayer.onPlayerStateChanged.listen((s) {
  if (s == AudioPlayerState.PLAYING) {
    setState(() => duration = audioPlayer.duration);
  } else if (s == AudioPlayerState.STOPPED) {
    onComplete();
    setState(() {
      position = duration;
    });
  }
}, onError: (msg) {
  setState(() {
    playerState = PlayerState.stopped;
    duration = new Duration(seconds: 0);
    position = new Duration(seconds: 0);
  });
});
```

Do not forget to cancel all the subscriptions when the widget is disposed.


## iOS

### :warning: iOS App Transport Security

By default iOS forbids loading from non-https url. To cancel this restriction edit your .plist and add :

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Background mode

cf. [enable background audio](https://developer.apple.com/documentation/avfoundation/media_assets_playback_and_editing/creating_a_basic_video_player_ios_and_tvos/enabling_background_audio)

## MacOS

Add this to entitlements files ( cf. [DebugProfile.entitlements](example/macos/Runner/DebugProfile.entitlements) )
```xml
    <key>com.apple.security.network.client</key>
    <true/>
```

cf. [Flutter MacOS security](https://github.com/google/flutter-desktop-embedding/blob/master/macOS-Security.md)

## Troubleshooting

- If you get a MissingPluginException, try to `flutter build apk` on Android, or `flutter build ios`

## Getting Started with Flutter

For help getting started with Flutter, view our online
[documentation](http://flutter.io/).

For help on editing plugin code, view the [documentation](https://flutter.io/platform-plugins/#edit-code).
