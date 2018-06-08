package bz.rxla.audioplayer;

import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Handler;
import android.util.Log;
import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import java.io.IOException;
import java.util.HashMap;

import android.content.Context;
import android.os.Build;

/**
 * AudioplayerPlugin
 */
public class AudioplayerPlugin implements MethodCallHandler {
  private final MethodChannel channel;
  private Registrar registrar;
  private static AudioManager am;

  final Handler handler = new Handler();

  MediaPlayer mediaPlayer;

  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "bz.rxla.flutter/audio");
    channel.setMethodCallHandler(new AudioplayerPlugin(registrar, channel));
  }

  private AudioplayerPlugin(Registrar registrar, MethodChannel channel) {
    this.registrar = registrar;
    this.channel = channel;
    this.channel.setMethodCallHandler(this);
    if(AudioplayerPlugin.am == null) {
      AudioplayerPlugin.am = (AudioManager)registrar.context().getApplicationContext().getSystemService(Context.AUDIO_SERVICE);
    }
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result response) {
    if (call.method.equals("play")) {
      String url = ((HashMap) call.arguments()).get("url").toString();
      Boolean resPlay = play(url);
      response.success(1);
    } else if (call.method.equals("pause")) {
      pause();
      response.success(1);
    } else if (call.method.equals("stop")) {
      stop();
      response.success(1);
    } else if (call.method.equals("seek")) {
      double position = call.arguments();
      seek(position);
      response.success(1);
    } else if (call.method.equals("mute")) {
      Boolean muted = call.arguments();
      mute(muted);
      response.success(1);
    } else if (call.method.equals("setVolume")) {
      int volume = call.arguments();
      setVolume(volume);
    } else {
      response.notImplemented();
    }
  }

  private void setVolume(int volume) {
    if (AudioplayerPlugin.am == null) return;

    AudioplayerPlugin.am.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0);
}

 private void mute(Boolean muted) {
  if(AudioplayerPlugin.am == null) return;
  if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
    AudioplayerPlugin.am.adjustStreamVolume(AudioManager.STREAM_MUSIC, muted ? AudioManager.ADJUST_MUTE : AudioManager.ADJUST_UNMUTE, 0);
  } else {
    AudioplayerPlugin.am.setStreamMute(AudioManager.STREAM_MUSIC, muted);
  }
 }

  private void seek(double position) {
    mediaPlayer.seekTo((int) (position * 1000));
  }

  private void stop() {
    handler.removeCallbacks(sendData);
    if (mediaPlayer != null) {
      mediaPlayer.stop();
      mediaPlayer.release();
      mediaPlayer = null;
    }
  }

  private void pause() {
    mediaPlayer.pause();
    handler.removeCallbacks(sendData);
  }

  private Boolean play(String url) {
    if (mediaPlayer == null) {
      mediaPlayer = new MediaPlayer();
      mediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);

      try {
        mediaPlayer.setDataSource(url);
      } catch (IOException e) {
        e.printStackTrace();
        Log.d("AUDIO", "invalid DataSource");
      }

      mediaPlayer.prepareAsync();
    } else {
      channel.invokeMethod("audio.onDuration", mediaPlayer.getDuration());

      mediaPlayer.start();
      channel.invokeMethod("audio.onStart", true);
    }

    mediaPlayer.setOnPreparedListener(new MediaPlayer.OnPreparedListener(){
      @Override
      public void onPrepared(MediaPlayer mp) {
        channel.invokeMethod("audio.onDuration", mediaPlayer.getDuration());

        mediaPlayer.start();
        channel.invokeMethod("audio.onStart", true);
      }
    });

    mediaPlayer.setOnCompletionListener(new MediaPlayer.OnCompletionListener(){
      @Override
      public void onCompletion(MediaPlayer mp) {
        stop();
        channel.invokeMethod("audio.onComplete", true);
      }
    });

    mediaPlayer.setOnErrorListener(new MediaPlayer.OnErrorListener(){
      @Override
      public boolean onError(MediaPlayer mp, int what, int extra) {
        channel.invokeMethod("audio.onError", String.format("{\"what\":%d,\"extra\":%d}", what, extra));
        return true;
      }
    });


    handler.post(sendData);

    return true;
  }

  private final Runnable sendData = new Runnable(){
    public void run(){
      try {
        if( ! mediaPlayer.isPlaying() ){
          handler.removeCallbacks(sendData);
        }
        int time = mediaPlayer.getCurrentPosition();
        channel.invokeMethod("audio.onCurrentPosition", time);

        handler.postDelayed(this, 200);
      }
      catch (Exception e) {
        e.printStackTrace();
      }
    }
  };
}
