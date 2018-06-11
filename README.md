# AudioPlayer

A Flutter audio plugin (ObjC/Java) to play remote or local audio files 

## Features

- [x] Android & iOS
  - [x] play (remote file)
  - [x] stop
  - [x] pause
  - [x] onComplete
  - [x] onDuration / onCurrentPosition
  - [x] seek
  - [x] mute

![screenshot](https://www.evernote.com/shard/s1/sh/c9e2e0dc-4e1b-4797-b23f-2bdf0f6f3387/d1138680d3b4bdcd/res/1afa2507-2df2-42ef-a840-d7f3519f5cb3/skitch.png?resizeSmall&width=320)

## Usage

[Example](https://github.com/rxlabz/audioplayer/blob/master/example/lib/main.dart)

To use this plugin :

- Add the dependency to your [pubspec.yaml](https://github.com/rxlabz/audioplayer/blob/master/example/pubspec.yaml) file.

```yaml
  dependencies:
    flutter:
      sdk: flutter
    audioplayer:
```

- Instantiate an AudioPlayer instance

```dart
//...
AudioPlayer audioPlugin = new AudioPlayer();
//...
```

### Player Controls

```dart
Future<void> play() async {
  await audioPlayer.play(kUrl);
  setState(() => playerState = PlayerState.playing);
}

Future<void> pause() async {
  await audioPlayer.pause();
  setState(() => playerState = PlayerState.paused);
}

Future<void> stop() async {
  await audioPlayer.stop();
  setState(() {
    playerState = PlayerState.stopped;
    position = new Duration();
  });
}

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

## :warning: iOS App Transport Security

By default iOS forbids loading from non-https url. To cancel this restriction edit your .plist and add :

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```
## Troubleshooting

- If you get a MissingPluginException, try to `flutter build apk` on Android, or `flutter build ios`
- to use the plugin in a ObjC iOS project, add 'use_frameworks!' to your podfile cf. [example](https://github.com/rxlabz/audioplayer/blob/master/example/ios/Podfile)

## Getting Started

For help getting started with Flutter, view our online
[documentation](http://flutter.io/).

For help on editing plugin code, view the [documentation](https://flutter.io/platform-plugins/#edit-code).
