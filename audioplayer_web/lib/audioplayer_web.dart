import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class AudioplayerPlugin {
  html.AudioElement player;

  double lastPosition = 0;
  String currentUrl;
  static MethodChannel channel;

  StreamSubscription durationWatcher;
  StreamSubscription progressWatcher;
  StreamSubscription endWatcher;

  static void registerWith(Registrar registrar) {
    channel = MethodChannel(
      'bz.rxla.flutter/audio',
      const StandardMethodCodec(),
      registrar.messenger,
    );
    final AudioplayerPlugin instance = AudioplayerPlugin();
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'play':
        final String url = call.arguments['url'];

        if (url == null || url.isEmpty)
          throw Exception('Invalid audio url : $url');

        if ((player?.paused ?? false) && url == currentUrl) {
          try {
            player.play();
          } catch (err) {
            print('Audioplayer error : $err');
            return 0;
          }
          return;
        } else if (player != null && !player.paused) {
          player.pause();
          player.src = null;
          player = null;
          _clearWatchers();
        }
        currentUrl = url;
        try {
          _play(currentUrl);
        } catch (err) {
          print('Audioplayer error : $err');
          return 0;
        }
        break;
      case 'pause':
        player?.pause();
        break;
      case 'stop':
        player?.pause();
        lastPosition = 0;
        player?.currentTime = 0;
        break;
      case 'seek':
        final time = num.tryParse('${call.arguments}');
        if (time == null) return 0;
        _seek(time);
        break;
      case 'mute':
        final muted = call.arguments == true;
        player.muted = muted;
        break;
      default:
        throw PlatformException(
            code: 'Unimplemented',
            details: "The audioplayer plugin for web doesn't implement "
                "the method '${call.method}'");
    }
    return 1;
  }

  void _play(String url) {
    player = html.AudioElement(url);

    endWatcher = player.onEnded.listen((event) {
      channel.invokeMethod("audio.onComplete");
    });
    durationWatcher = player.onDurationChange.listen((event) {
      channel.invokeMethod("audio.onStart", (player.duration * 1000).toInt());
    });
    progressWatcher = player.onTimeUpdate.listen((event) {
      channel.invokeMethod(
          "audio.onCurrentPosition", (player.currentTime * 1000).toInt());
    });
    player.play();
  }

  void _seek(int seconds) {
    player.currentTime = seconds;
  }

  void _clearWatchers() {
    durationWatcher.cancel();
    progressWatcher.cancel();
    endWatcher.cancel();
  }
}
