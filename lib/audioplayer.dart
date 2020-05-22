import 'dart:async';

import 'package:flutter/services.dart';

/// Communicates the current state of the audio player.
enum AudioPlayerState {
  /// Player is stopped. No file is loaded to the player. Calling [resume] or
  /// [pause] will result in exception.
  STOPPED,
  /// Currently playing a file. The user can [pause], [resume] or [stop] the
  /// playback.
  PLAYING,
  /// Paused. The user can [resume] the playback without providing the URL.
  PAUSED,
  /// The playback has been completed. This state is the same as [STOPPED],
  /// however we differentiate it because some clients might want to know when
  /// the playback is done versus when the user has stopped the playback.
  COMPLETED,
}


enum PlayBackKeys {

  PAUSE_KEY,

  PLAY_KEY,

  NEXT_KEY,

  PREV_KEY,

  REWIND_KEY,

  STOP_KEY,

  SEEK_KEY,

  FAST_FORWARD_KEY,
}

enum AudioFocus {
  AUDIO_FOCUS_GAINED,

  AUDIO_FOCUS_LOST,

  NO_AUDIO_FOCUS
}


const MethodChannel _channel =
    const MethodChannel('bz.rxla.flutter/audio');

/// A plugin for controlling the on device audio player.
///
/// Due to the async nature of the native APIs, this plugin delegates all control
/// methods to native without informing the caller of the state changes that happen
/// as a result of these calls. The state changes are communicated via the
/// [onPlayerStateChanged] stream instead so clients are expected to subscribe
/// to this.
class AudioPlayer {
  final StreamController<AudioPlayerState> _playerStateController =
      new StreamController.broadcast();
  final StreamController<PlayBackKeys> _playerPlaybackKeys =
      new StreamController.broadcast();

  final StreamController<Duration> _positionController =
      new StreamController.broadcast();

  final StreamController<AudioFocus> _audioFocusController =
      new StreamController.broadcast();



  AudioPlayerState _state = AudioPlayerState.STOPPED;
  Duration _duration = const Duration();

  AudioPlayer() {
    _channel.setMethodCallHandler(_audioPlayerStateChange);
    //Seeding the audioFocus with a noAudioFocus state
    _audioFocusController.add(AudioFocus.NO_AUDIO_FOCUS);
  }

  /// Play a given url.
  Future<void> play(String url, {bool isLocal: false}) async =>
      await _channel.invokeMethod('play', {'url': url, 'isLocal': isLocal});

  /// Pause the currently playing stream.
  Future<void> pause() async => await _channel.invokeMethod('pause');

  /// Stop the currently playing stream.
  Future<void> stop() async => await _channel.invokeMethod('stop');

  /// Mute sound.
  Future<void> mute(bool muted) async => await _channel.invokeMethod('mute', muted);

  /// Seek to a specific position in the audio stream.
  Future<void> seek(double seconds) async => await _channel.invokeMethod('seek', seconds);

  /// Stream for subscribing to player state change events.
  Stream<AudioPlayerState> get onPlayerStateChanged => _playerStateController.stream;

  Stream<PlayBackKeys> get onPlaybackKeyEvent => _playerPlaybackKeys.stream;

  /// Stream for AudioFocus
  Stream<AudioFocus> get onAudioFocusChange => _audioFocusController.stream;


  /// Reports what the player is currently doing.
  AudioPlayerState get state => _state;

  /// Reports the duration of the current media being played. It might return
  /// 0 if we have not determined the length of the media yet. It is best to
  /// call this from a state listener when the state has become
  /// [AudioPlayerState.PLAYING].
  Duration get duration => _duration;

  /// Stream for subscribing to audio position change events. Roughly fires
  /// every 200 milliseconds. Will continously update the position of the
  /// playback if the status is [AudioPlayerState.PLAYING].
  Stream<Duration> get onAudioPositionChanged => _positionController.stream;

  Future<void> _audioPlayerStateChange(MethodCall call) async {
//    print('callback method: ${call.method}');
    switch (call.method) {
      case "audio.onCurrentPosition":
//        print('audio.onCurrentPosition: ${call.arguments}');
        if(_state == AudioPlayerState.PLAYING){
          _positionController.add(new Duration(milliseconds: call.arguments));
        }
        break;
      case "audio.onStart":
        _state = AudioPlayerState.PLAYING;
        _playerStateController.add(AudioPlayerState.PLAYING);
        _duration = new Duration(milliseconds: call.arguments);
        break;
      case "audio.onPause":
        _state = AudioPlayerState.PAUSED;
        _playerStateController.add(AudioPlayerState.PAUSED);
        break;
      case "audio.onStop":
        _state = AudioPlayerState.STOPPED;
        _playerStateController.add(AudioPlayerState.STOPPED);
        break;
      case "audio.onComplete":
        _state = AudioPlayerState.COMPLETED;
        _playerStateController.add(AudioPlayerState.COMPLETED);
        break;
      case "audio.onError":
        // If there's an error, we assume the player has stopped.
        _state = AudioPlayerState.STOPPED;
        _playerStateController.addError(call.arguments);
        // TODO: Handle error arguments here. It is not useful to pass this
        // to the client since each platform creates different error string
        // formats so we can't expect client to parse these.
        break;
      case "audio.onKeyPause":
//        print('audio.onCurrentPosition: ${call.arguments}');
        _playerPlaybackKeys.add(PlayBackKeys.PAUSE_KEY);
        break;
      case "audio.onPlayPauseKey":
//        print('audio.onCurrentPosition: ${call.arguments}');
        if(call.arguments==true){
          _playerPlaybackKeys.add(PlayBackKeys.PLAY_KEY);
        }else{
          _playerPlaybackKeys.add(PlayBackKeys.PAUSE_KEY);
        }

        break;
      case "audio.onKeySkipToNext":
        _playerPlaybackKeys.add(PlayBackKeys.NEXT_KEY);
        break;
      case "audio.onKeySkipToPrevious":
        _playerPlaybackKeys.add(PlayBackKeys.PREV_KEY);
        break;
      case "audio.onKeyFastForward":
        _playerPlaybackKeys.add(PlayBackKeys.FAST_FORWARD_KEY);
        break;
      case "audio.onKeyRewind":
        _playerPlaybackKeys.add(PlayBackKeys.REWIND_KEY);
        break;
      case "audio.onKeySeekTo":
        _playerPlaybackKeys.add(PlayBackKeys.SEEK_KEY);
        break;
      case "audio.onKeyStop":
        _playerPlaybackKeys.add(PlayBackKeys.STOP_KEY);
        break;
      case "audio.onAudioFocusGained":
        _audioFocusController.add(AudioFocus.AUDIO_FOCUS_GAINED);
        break;
      case "audio.onAudioFocusLost":
        _audioFocusController.add(AudioFocus.AUDIO_FOCUS_LOST);
        break;
      default:
        throw new ArgumentError('Unknown method ${call.method} ');
    }
  }

  ///Stream for subscribing to the playback keys callbacks
  ///
  /// DEPRECATED, CAN4T USE MULTIPLE HANDLERS FOR CALLBACKS

  Future<void> _audioKeysEvents(MethodCall call) async {
//    print('callback method: ${call.method}');
    switch (call.method) {
      case "audio.onKeyPause":
//        print('audio.onCurrentPosition: ${call.arguments}');
        _playerPlaybackKeys.add(PlayBackKeys.PAUSE_KEY);
        break;
      case "audio.onKeySkipToNext":
        _playerPlaybackKeys.add(PlayBackKeys.NEXT_KEY);
        break;
      case "audio.onKeySkipToPrevious":
        _playerPlaybackKeys.add(PlayBackKeys.PREV_KEY);
        break;
      case "audio.onKeyFastForward":
        _playerPlaybackKeys.add(PlayBackKeys.FAST_FORWARD_KEY);
        break;
      case "audio.onKeyRewind":
        _playerPlaybackKeys.add(PlayBackKeys.REWIND_KEY);
        break;
      case "audio.onKeySeekTo":
        _playerPlaybackKeys.add(PlayBackKeys.SEEK_KEY);
        break;
      case "audio.onKeyStop":
        _playerPlaybackKeys.add(PlayBackKeys.STOP_KEY);
        break;
      default:
        throw new ArgumentError('Unknown method ${call.method} ');
    }
  }
}
