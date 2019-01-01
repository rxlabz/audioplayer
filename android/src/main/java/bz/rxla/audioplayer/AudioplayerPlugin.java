package bz.rxla.audioplayer;

import android.app.Activity;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Handler;
import android.util.Log;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry;
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
  private static AudioManager am;

  private final Handler handler = new Handler();

  private MediaPlayer mediaPlayer;
  private PluginRegistry.Registrar registrar;

  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "bz.rxla.flutter/audio");
    channel.setMethodCallHandler(new AudioplayerPlugin(registrar.activity(), channel, registrar));
  }

  private AudioplayerPlugin(Activity activity, MethodChannel channel, PluginRegistry.Registrar registrar) {
    this.registrar = registrar;
    this.channel = channel;
    this.channel.setMethodCallHandler(this);
    if(AudioplayerPlugin.am == null) {
      AudioplayerPlugin.am = (AudioManager)activity.getApplicationContext().getSystemService(Context.AUDIO_SERVICE);
    }
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result response) {
    switch (call.method) {
      case "playAsset":
        String path = ((HashMap) call.arguments()).get("path").toString();
        AssetManager assetManager = registrar.context().getAssets();
        String key = registrar.lookupKeyForAsset(path);
        try {
          AssetFileDescriptor afd = assetManager.openFd(key);
          playAssetFileDescriptor(afd);
          response.success(1);
        } catch (IOException e) {
          response.error("AudioPlayerError", "unable to read audio file from asset path", null);
        }
        break;
      case "play":
        String url = ((HashMap) call.arguments()).get("url").toString();
        Boolean resPlay = playUrl(url);
        response.success(1);
        break;
      case "pause":
        pause();
        response.success(1);
        break;
      case "stop":
        stop();
        response.success(1);
        break;
      case "seek":
        double position = call.arguments();
        seek(position);
        response.success(1);
        break;
      case "mute":
        Boolean muted = call.arguments();
        mute(muted);
        response.success(1);
        break;
      default:
        response.notImplemented();
        break;
    }
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
      mediaPlayer.reset();
      mediaPlayer.release();
      mediaPlayer = null;
    }
  }

  private void pause() {
    mediaPlayer.pause();
    handler.removeCallbacks(sendData);
  }

  private Boolean playUrl(String url) {
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
    return attachToMediaPlayerEvents();
  }

  private Boolean playAssetFileDescriptor(AssetFileDescriptor afd) {
    if (mediaPlayer == null) {
      mediaPlayer = new MediaPlayer();
      mediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);

      try {
        mediaPlayer.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
        afd.close();
//        mediaPlayer.prepare();
      } catch (IOException e) {
        e.printStackTrace();
        Log.d("AUDIO", "invalid DataSource");
      }
//      mediaPlayer.start();
      mediaPlayer.prepareAsync();
    } else {
      channel.invokeMethod("audio.onDuration", mediaPlayer.getDuration());

      mediaPlayer.start();
      channel.invokeMethod("audio.onStart", true);
    }
    return attachToMediaPlayerEvents();
  }

  private Boolean attachToMediaPlayerEvents() {

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
